`timescale 1ns / 1ps
module frame_udp_tb;
    logic clk = 0, reset_n = 0, pclk = 0, href = 0, vsync = 0;
    logic [7:0] camera_data = 0;
    wire ref_clk, tx_en;
    wire [1:0] txd;
    wire [15:0] status;
    tri mdio;
    logic [7:0] image [0:640*480-1];
    logic [415:0] expected_packet [0:8191];
    logic [415:0] packet;
    int descriptors = 0, packets = 0, packet_bytes = 0, captured = 0;
    int per_level [0:2] = '{default:0};
    int payload_file, wire_file, descriptor_file;
    int dibit = 0;
    logic [7:0] wire_byte = 0;
    bit transmitting = 0, marker = 0;
    always #5 clk = ~clk;
    always #20 pclk = ~pclk;

    orb_udp_board_top #(.DEST_IP(32'hffffffff)) dut (
        .CLK100MHZ(clk), .CPU_RESETN(reset_n), .CAM_PCLK(pclk),
        .CAM_HREF(href), .CAM_VSYNC(vsync), .CAM_DATA(camera_data),
        .CAM_XCLK(), .CAM_RESET(), .STATUS(status),
        .ETH_REF_CLK(ref_clk), .ETH_CRS_DV(1'b0), .ETH_RX_ER(1'b0),
        .ETH_RXD(2'b0), .ETH_TXD(txd), .ETH_TX_EN(tx_en),
        .ETH_RST_N(), .ETH_MDC(), .ETH_MDIO(mdio)
    );

    always @(posedge clk) if (!dut.network_reset) begin
        if (dut.level_valid[0]) captured++;
        if (dut.descriptor_valid && dut.descriptor_ready) begin
            if (descriptors >= 8192) $fatal(1,"Scoreboard full");
            expected_packet[descriptors] = {
                32'h4f524231, 8'd0, dut.packetizer.error_flags, 16'd1, 32'd0, 32'(descriptors),
                5'd0, dut.descriptor_octave, dut.descriptor_pos,
                dut.descriptor_angle, dut.descriptor};
            $fdisplay(descriptor_file,"%0d %0d %0d %0d %064h", dut.descriptor_octave,
                dut.descriptor_pos[18:9], dut.descriptor_pos[8:0],
                dut.descriptor_angle, dut.descriptor);
            per_level[dut.descriptor_octave]++;
            descriptors++;
        end
        if (dut.udp_valid && dut.udp_ready) begin
            packet = {packet[407:0],dut.udp_data};
            $fwrite(payload_file,"%02h",dut.udp_data);
            packet_bytes++;
            if (dut.udp_last) begin
                $fwrite(payload_file,"\n");
                if (packet_bytes == 52) begin
                    if (packets >= descriptors || packet !== expected_packet[packets])
                        $fatal(1,"Descriptor packet mismatch %0d",packets);
                    packets++;
                end else if (packet_bytes == 16) begin
                    if (packet[127:96] != 32'h4f524231 || packet[95:88] != 1 ||
                        packet[31:0] != descriptors || packets != descriptors)
                        $fatal(1,"Frame end mismatch");
                    marker = 1;
                end else $fatal(1,"Bad packet length");
                packet_bytes = 0;
                packet = 0;
            end
        end
    end

    always @(posedge ref_clk) begin
        if (tx_en) begin
            transmitting = 1;
            wire_byte[dibit*2 +: 2] = txd;
            if (dibit == 3) begin
                $fwrite(wire_file,"%02h",wire_byte);
                dibit = 0;
            end else dibit++;
        end else if (transmitting) begin
            if (dibit != 0) $fatal(1,"Incomplete RMII byte");
            $fwrite(wire_file,"\n");
            transmitting = 0;
        end
    end

    task automatic send_byte(input logic [7:0] value);
        @(negedge pclk);
        href = 1;
        camera_data = value;
    endtask

    initial begin
        $readmemh("image.hex",image);
        payload_file = $fopen("udp_payloads.hex","w");
        wire_file = $fopen("ethernet_frames.hex","w");
        descriptor_file = $fopen("descriptors.txt","w");
        repeat (20) @(negedge clk);
        reset_n = 1;
        wait(dut.eth_locked);
        force dut.startup_count = 23'h400000;
        repeat (100) @(negedge pclk);
        vsync = 1;
        repeat (10) @(negedge pclk);
        vsync = 0;
        for (int row = 0; row < 480; row++) begin
            for (int col = 0; col < 640; col += 2) begin
                send_byte(128); send_byte(image[row*640+col]);
                send_byte(128); send_byte(image[row*640+col+1]);
            end
            @(negedge pclk); href = 0;
            repeat (20) @(negedge pclk);
        end
        wait(marker);
        repeat (200000) @(negedge clk);
        if (captured != 640*480 || descriptors == 0 || dut.camera_overflow ||
            (|dut.kp_overflow) || dut.marker_overflow || dut.network_error_sticky)
            $fatal(1,"Capture/overflow failure pixels=%0d",captured);
        $display("PASS: frame pixels=%0d descriptors=%0d per_level=%0d,%0d,%0d brief_drop=%b",
            captured,descriptors,per_level[0],per_level[1],per_level[2],dut.brief_dropped);
        $fclose(payload_file); $fclose(wire_file); $fclose(descriptor_file);
        $finish;
    end
    initial begin
        #100000000;
        $fatal(1,"Single-frame timeout");
    end
endmodule
