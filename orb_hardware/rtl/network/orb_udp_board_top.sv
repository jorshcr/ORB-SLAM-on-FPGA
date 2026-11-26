`timescale 1ns / 1ps

module orb_udp_board_top #(
    parameter int ORB_LEVELS = 3,
    parameter int BRIEF_ENGINES = 2,
    parameter int LAST_LEVEL_BRIEF_ENGINES = 1,
    parameter logic [31:0] LOCAL_IP = 32'hc0a80180,
    parameter logic [31:0] DEST_IP = 32'hc0a80164,
    parameter logic [47:0] LOCAL_MAC = 48'h020000000001
)(
    input logic CLK100MHZ,
    input logic CPU_RESETN,
    input logic CAM_PCLK,
    input logic CAM_HREF,
    input logic CAM_VSYNC,
    input logic [7:0] CAM_DATA,
    output wire CAM_XCLK,
    output wire CAM_RESET,
    output wire [15:0] STATUS,
    output wire ETH_REF_CLK,
    input wire ETH_CRS_DV, ETH_RX_ER,
    input wire [1:0] ETH_RXD,
    output logic [1:0] ETH_TXD,
    output logic ETH_TX_EN,
    output wire ETH_RST_N,
    output wire ETH_MDC,
    inout wire ETH_MDIO
);

    wire eth_clock;
    wire eth_clock_raw, eth_forward_raw, eth_forward_clock;
    wire eth_feedback_raw, eth_feedback, eth_locked;
    logic [22:0] startup_count;
    wire [1:0] txd;
    wire tx_en;
    wire hdr_valid, hdr_ready, udp_valid, udp_ready, udp_last;
    wire [15:0] udp_length;
    wire [7:0] udp_data;
    wire network_error, marker_overflow;
    logic network_error_sticky;
    wire reset = !CPU_RESETN;
    wire network_reset;
    logic [1:0] clock_divider;
    wire camera_clock;
    wire descriptor_valid, descriptor_ready;
    wire [18:0] descriptor_pos;
    wire [255:0] descriptor;
    wire [5:0] descriptor_angle;
    wire [1:0] descriptor_octave;
    wire [7:0] orientation_byte = {descriptor_octave, descriptor_angle};
    wire camera_overflow;
    wire frame_done, frame_busy;
    wire [ORB_LEVELS-1:0] kp_overflow, brief_dropped;
    localparam int LEVEL_WIDTH [0:3] = '{640, 533, 444, 370};
    localparam int LEVEL_HEIGHT [0:3] = '{480, 400, 333, 277};
    wire [ORB_LEVELS-1:0][7:0] level_pixel;
    wire [ORB_LEVELS-1:0][9:0] level_x;
    wire [ORB_LEVELS-1:0][8:0] level_y;
    wire [ORB_LEVELS-1:0] level_valid;
    logic [7:0] descriptor_count, descriptor_checksum;

    assign CAM_RESET = !network_reset;
    always_ff @(posedge CLK100MHZ or posedge reset) begin
        if (reset) clock_divider <= '0;
        else clock_divider <= clock_divider + 1'b1;
    end
    assign STATUS = {network_error_sticky, marker_overflow, frame_busy, camera_overflow, descriptor_count, descriptor_checksum[3:0]};

    BUFG camera_clock_buffer (.I(clock_divider[1]), .O(camera_clock));
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) camera_xclk_output (
        .Q(CAM_XCLK), .C(camera_clock), .CE(1'b1),
        .D1(1'b1), .D2(1'b0), .R(reset), .S(1'b0)
    );

    for (genvar level = 1; level < ORB_LEVELS; level++) begin : g_scaler
        image_scaler #(
            .FRAME_WIDTH(LEVEL_WIDTH[level-1]), .FRAME_HEIGHT(LEVEL_HEIGHT[level-1])
        ) scaler (
            .clk(CLK100MHZ), .reset(network_reset),
            .in_gray(level_pixel[level-1]), .in_x(level_x[level-1]),
            .in_y(level_y[level-1]), .in_valid(level_valid[level-1]),
            .out_gray(level_pixel[level]), .out_x(level_x[level]),
            .out_y(level_y[level]), .out_valid(level_valid[level])
        );
    end

    system_top #(
        .ORB_LEVELS(ORB_LEVELS), .FRAME_WIDTH(LEVEL_WIDTH[0:ORB_LEVELS-1]),
        .FRAME_HEIGHT(LEVEL_HEIGHT[0:ORB_LEVELS-1]),
        .BRIEF_ENGINES(BRIEF_ENGINES), .LAST_LEVEL_BRIEF_ENGINES(LAST_LEVEL_BRIEF_ENGINES)
    ) system (
        .clk(CLK100MHZ), .reset(network_reset),
        .cam_pclk(CAM_PCLK), .cam_href(CAM_HREF), .cam_vsync(CAM_VSYNC),
        .cam_data(CAM_DATA), .in_pixel(level_pixel), .in_valid(level_valid),
        .in_x(level_x), .in_y(level_y), .threshold({ORB_LEVELS{8'd20}}),
        .pixel_valid(level_valid[0]), .pixel_gray(level_pixel[0]), .pixel_u(), .pixel_v(),
        .pixel_x(level_x[0]), .pixel_y(level_y[0]), .pixel_frame_start(), .pixel_frame_end(),
        .camera_overflow(camera_overflow), .out_valid(descriptor_valid), .out_ready(descriptor_ready),
        .out_descriptor(descriptor), .out_pos(descriptor_pos), .out_octave(descriptor_octave),
        .out_angle(descriptor_angle),
        .reset_busy(), .frame_done(frame_done), .frame_busy(frame_busy),
        .kp_overflow(kp_overflow), .brief_dropped(brief_dropped)
    );

    always_ff @(posedge CLK100MHZ) begin
        if (network_reset) begin
            descriptor_count <= 0;
            descriptor_checksum <= 0;
        end else begin
            if (descriptor_valid && descriptor_ready) begin
                descriptor_count <= descriptor_count + 1'b1;
                for (int bit_index = 0; bit_index < 8; bit_index++)
                    descriptor_checksum[bit_index] <= descriptor_checksum[bit_index] ^
                                                      (^descriptor[bit_index*32 +: 32]) ^
                                                      orientation_byte[bit_index];
            end
        end
    end

    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0), .CLKFBOUT_MULT_F(10.0),
        .CLKOUT0_DIVIDE_F(20.0), .CLKOUT1_DIVIDE(20), .CLKOUT1_PHASE(-18.0)
    ) eth_clock_mmcm (
        .CLKIN1(CLK100MHZ), .CLKFBIN(eth_feedback), .RST(reset), .PWRDWN(1'b0),
        .CLKFBOUT(eth_feedback_raw), .CLKFBOUTB(), .LOCKED(eth_locked),
        .CLKOUT0(eth_clock_raw), .CLKOUT0B(), .CLKOUT1(eth_forward_raw), .CLKOUT1B(),
        .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(),
        .CLKOUT4(), .CLKOUT5(), .CLKOUT6()
    );
    BUFG eth_feedback_buffer (.I(eth_feedback_raw), .O(eth_feedback));
    BUFG eth_clock_buffer (.I(eth_clock_raw), .O(eth_clock));
    BUFG eth_forward_buffer (.I(eth_forward_raw), .O(eth_forward_clock));
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) eth_clock_output (
        .Q(ETH_REF_CLK), .C(eth_forward_clock), .CE(1'b1),
        .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0)
    );
    assign network_reset = reset || !eth_locked || !startup_count[22];
    always_ff @(posedge CLK100MHZ or posedge reset) begin
        if (reset) startup_count <= '0;
        else if (!startup_count[22]) startup_count <= startup_count + 1'b1;
    end
    assign ETH_MDC = 1'b0;
    assign ETH_MDIO = 1'bz;
    always_ff @(negedge eth_clock) begin
        ETH_TXD <= txd;
        ETH_TX_EN <= tx_en;
    end
    always_ff @(posedge CLK100MHZ) begin
        if (network_reset) network_error_sticky <= 1'b0;
        else if (network_error) network_error_sticky <= 1'b1;
    end
    descriptor_udp_packetizer packetizer (
        .clk(CLK100MHZ), .reset(network_reset),
        .in_valid(descriptor_valid), .in_ready(descriptor_ready),
        .in_descriptor(descriptor), .in_pos(descriptor_pos),
        .in_octave(descriptor_octave), .in_angle(descriptor_angle),
        .frame_done(frame_done),
        .error_flags({3'd0, marker_overflow, network_error_sticky,
                      |brief_dropped, |kp_overflow, camera_overflow}),
        .hdr_valid(hdr_valid), .hdr_ready(hdr_ready), .udp_length(udp_length),
        .data(udp_data), .valid(udp_valid), .ready(udp_ready), .last(udp_last),
        .marker_overflow(marker_overflow)
    );
    orb_udp_stack #(.LOCAL_IP(LOCAL_IP), .DEST_IP(DEST_IP), .LOCAL_MAC(LOCAL_MAC)) ethernet (
        .clk(CLK100MHZ), .rst(network_reset), .ref_clk(eth_clock),
        .udp_hdr_valid(hdr_valid), .udp_hdr_ready(hdr_ready), .udp_length(udp_length),
        .udp_data(udp_data), .udp_valid(udp_valid), .udp_ready(udp_ready), .udp_last(udp_last),
        .network_error(network_error), .phy_crs_dv(ETH_CRS_DV), .phy_rxd(ETH_RXD),
        .phy_rx_er(ETH_RX_ER), .phy_txd(txd), .phy_tx_en(tx_en), .phy_reset_n(ETH_RST_N)
    );
endmodule
