`timescale 1ns / 1ps

module orb_board_top #(
    parameter int ORB_LEVELS = 2,
    parameter int LAST_LEVEL_BRIEF_ENGINES = 3
)(
    input logic CLK100MHZ,
    input logic CPU_RESETN,
    input logic CAM_PCLK,
    input logic CAM_HREF,
    input logic CAM_VSYNC,
    input logic [7:0] CAM_DATA,
    output wire CAM_XCLK,
    output wire CAM_RESET,
    output wire [15:0] STATUS
);

    wire reset = !CPU_RESETN;
    logic [1:0] clock_divider;
    wire camera_clock;
    wire descriptor_valid;
    wire [255:0] descriptor;
    wire [5:0] descriptor_angle;
    wire [1:0] descriptor_octave;
    wire [7:0] orientation_byte = {descriptor_octave, descriptor_angle};
    wire camera_overflow;
    wire [ORB_LEVELS-1:0] kp_overflow, brief_dropped;
    localparam int LEVEL_WIDTH [0:3] = '{640, 533, 444, 370};
    localparam int LEVEL_HEIGHT [0:3] = '{480, 400, 333, 277};
    wire [ORB_LEVELS-1:0][7:0] level_pixel;
    wire [ORB_LEVELS-1:0][9:0] level_x;
    wire [ORB_LEVELS-1:0][8:0] level_y;
    wire [ORB_LEVELS-1:0] level_valid;
    logic [7:0] descriptor_count, descriptor_checksum;

    assign CAM_RESET = CPU_RESETN;
    assign STATUS = {descriptor_count, descriptor_checksum};

    BUFG camera_clock_buffer (.I(clock_divider[1]), .O(camera_clock));
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) camera_xclk_output (
        .Q(CAM_XCLK), .C(camera_clock), .CE(1'b1),
        .D1(1'b1), .D2(1'b0), .R(reset), .S(1'b0)
    );

    for (genvar level = 1; level < ORB_LEVELS; level++) begin : g_scaler
        image_scaler #(
            .FRAME_WIDTH(LEVEL_WIDTH[level-1]), .FRAME_HEIGHT(LEVEL_HEIGHT[level-1])
        ) scaler (
            .clk(CLK100MHZ), .reset(reset),
            .in_gray(level_pixel[level-1]), .in_x(level_x[level-1]),
            .in_y(level_y[level-1]), .in_valid(level_valid[level-1]),
            .out_gray(level_pixel[level]), .out_x(level_x[level]),
            .out_y(level_y[level]), .out_valid(level_valid[level])
        );
    end

    system_top #(
        .ORB_LEVELS(ORB_LEVELS), .FRAME_WIDTH(LEVEL_WIDTH[0:ORB_LEVELS-1]),
        .FRAME_HEIGHT(LEVEL_HEIGHT[0:ORB_LEVELS-1]),
        .LAST_LEVEL_BRIEF_ENGINES(LAST_LEVEL_BRIEF_ENGINES)
    ) system (
        .clk(CLK100MHZ), .reset(reset),
        .cam_pclk(CAM_PCLK), .cam_href(CAM_HREF), .cam_vsync(CAM_VSYNC),
        .cam_data(CAM_DATA), .in_pixel(level_pixel), .in_valid(level_valid),
        .in_x(level_x), .in_y(level_y), .threshold({ORB_LEVELS{8'd20}}),
        .pixel_valid(level_valid[0]), .pixel_gray(level_pixel[0]), .pixel_u(), .pixel_v(),
        .pixel_x(level_x[0]), .pixel_y(level_y[0]), .pixel_frame_id(), .pixel_frame_start(), .pixel_frame_end(),
        .camera_overflow(camera_overflow), .out_valid(descriptor_valid), .out_ready(1'b1),
        .out_descriptor(descriptor), .out_pos(), .out_octave(descriptor_octave), .out_frame_id(),
        .out_angle(descriptor_angle),
        .reset_busy(), .kp_overflow(kp_overflow), .brief_dropped(brief_dropped)
    );

    always_ff @(posedge CLK100MHZ or posedge reset) begin
        if (reset) begin
            clock_divider <= 0;
            descriptor_count <= 0;
            descriptor_checksum <= 0;
        end else begin
            clock_divider <= clock_divider + 1'b1;
            if (descriptor_valid) begin
                descriptor_count <= descriptor_count + 1'b1;
                for (int bit_index = 0; bit_index < 8; bit_index++)
                    descriptor_checksum[bit_index] <= descriptor_checksum[bit_index] ^
                                                      (^descriptor[bit_index*32 +: 32]) ^
                                                      orientation_byte[bit_index];
            end
        end
    end

endmodule
