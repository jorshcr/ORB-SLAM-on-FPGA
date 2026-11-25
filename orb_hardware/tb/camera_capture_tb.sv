`timescale 1ns / 1ps

module camera_capture_tb;
    parameter bit Y_FIRST = 0;
    parameter bit SWAP_UV = 0;
    logic clk = 0, pclk = 0, reset = 1;
    logic href = 0, vsync = 0;
    logic [7:0] data = 0;
    wire valid, sof, eof, overflow;
    wire [7:0] gray, u, v;
    wire [9:0] x;
    wire [8:0] y;
    wire [2:0] frame_id;
    int received = 0;

    always #5 clk = ~clk;
    always #19 pclk = ~pclk;

    camera_capture_top #(
        .FRAME_WIDTH(8), .FRAME_HEIGHT(3), .FIFO_DEPTH(16),
        .Y_FIRST(Y_FIRST), .SWAP_UV(SWAP_UV)
    ) dut (
        .clk(clk), .reset(reset), .cam_pclk(pclk), .cam_href(href),
        .cam_vsync(vsync), .cam_data(data), .out_valid(valid),
        .out_gray(gray), .out_u(u), .out_v(v), .out_x(x), .out_y(y),
        .out_frame_id(frame_id), .out_frame_start(sof), .out_frame_end(eof),
        .overflow(overflow)
    );

    task automatic send_byte(input logic [7:0] value);
        @(negedge pclk);
        href = 1;
        data = value;
    endtask

    task automatic send_pair(input int pixel);
        if (Y_FIRST) begin
            send_byte(8'(pixel));
            send_byte(SWAP_UV ? 8'd190 : 8'd70);
            send_byte(8'(pixel+1));
            send_byte(SWAP_UV ? 8'd70 : 8'd190);
        end else begin
            send_byte(SWAP_UV ? 8'd190 : 8'd70);
            send_byte(8'(pixel));
            send_byte(SWAP_UV ? 8'd70 : 8'd190);
            send_byte(8'(pixel+1));
        end
    endtask

    always @(negedge clk) begin
        if (!reset && valid) begin
            if (gray !== 8'(received) || u !== 70 || v !== 190 ||
                x !== 10'(received % 8) || y !== 9'((received % 24)/8) ||
                frame_id !== 3'(received/24) ||
                sof !== (received % 24 == 0) || eof !== (received % 24 == 23))
                $fatal(1, "Pixel %0d: gray=%0d xy=%0d,%0d frame=%0d sof=%b eof=%b",
                       received, gray, x, y, frame_id, sof, eof);
            received++;
        end
    end

    initial begin
        #400;
        @(negedge pclk) reset = 0;
        repeat (40) @(negedge pclk);
        send_pair(200);
        @(negedge pclk) href = 0;
        repeat (20) @(negedge pclk);
        if (received != 0) $fatal(1, "Accepted pixels before first VSYNC");

        for (int frame = 0; frame < 2; frame++) begin
            vsync = 1;
            repeat (4) @(negedge pclk);
            vsync = 0;
            for (int row = 0; row < 3; row++) begin
                for (int col = 0; col < 8; col += 2)
                    send_pair(frame*24 + row*8 + col);
                @(negedge pclk) href = 0;
                repeat (5) @(negedge pclk);
            end
            repeat (20) @(negedge pclk);
        end
        if (received != 48 || overflow) $fatal(1, "Missing pixels or overflow");
        $display("PASS: camera capture Y_FIRST=%0d SWAP_UV=%0d", Y_FIRST, SWAP_UV);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
