`timescale 1ns / 1ps
module descriptor_udp_packetizer_tb;
    logic clk = 0, reset = 1;
    always #5 clk = ~clk;
    logic in_valid = 0, in_ready, frame_done = 0;
    logic [255:0] in_descriptor = '0;
    logic [18:0] in_pos = '0;
    logic [1:0] in_octave = 0;
    logic [5:0] in_angle = 0;
    logic [7:0] error_flags = 8'h05;
    logic hdr_valid, hdr_ready = 0, valid, ready = 0, last, marker_overflow;
    logic [15:0] udp_length;
    logic [7:0] data;
    logic [415:0] received;
    logic [415:0] expected [0:3];
    int lengths [0:3] = '{52,52,16,16};
    int cycle = 0, byte_count = 0, packets = 0;
    bit header_seen = 0, was_stalled = 0;
    logic [8:0] held;
    descriptor_udp_packetizer dut (.*);

    always @(negedge clk) begin
        cycle++;
        hdr_ready = cycle % 5 == 0;
        ready = cycle % 3 != 0 && cycle % 7 != 0;
    end

    always @(posedge clk) if (!reset) begin
        if (was_stalled && (!valid || {last,data} !== held)) $fatal(1,"Unstable payload under backpressure");
        was_stalled = valid && !ready;
        held = {last,data};
        if (hdr_valid && hdr_ready) begin
            if (header_seen || packets > 3 || udp_length != lengths[packets]+8) $fatal(1,"Bad UDP header");
            header_seen = 1;
            byte_count = 0;
            received = 0;
        end
        if (valid && ready) begin
            if (!header_seen) $fatal(1,"Payload before header");
            received = {received[407:0],data};
            byte_count++;
            if (last) begin
                if (byte_count != lengths[packets]) $fatal(1,"Bad payload length");
                if (received !== expected[packets]) $fatal(1,"Packet %0d data mismatch", packets);
                packets++;
                header_seen = 0;
            end
        end
    end

    task automatic send_descriptor(input int n);
        @(negedge clk);
        in_descriptor = {8{32'(n)}};
        in_pos = 19'(n*31);
        in_octave = 2'(n);
        in_angle = 6'(n*17);
        in_valid = 1;
        do @(posedge clk); while (!in_ready);
        @(negedge clk); in_valid = 0;
    endtask

    initial begin
        expected[0] = {32'h4f524231,8'd0,8'h05,16'd1,32'd0,32'd0,5'd0,2'd1,19'd31,6'd17,{8{32'd1}}};
        expected[1] = {32'h4f524231,8'd0,8'h05,16'd1,32'd0,32'd1,5'd0,2'd2,19'd62,6'd34,{8{32'd2}}};
        expected[2] = {288'd0,32'h4f524231,8'd1,8'h05,16'd0,32'd0,32'd2};
        expected[3] = {288'd0,32'h4f524231,8'd1,8'h05,16'd0,32'd1,32'd0};
        repeat (4) @(negedge clk);
        reset = 0;
        send_descriptor(1);
        send_descriptor(2);
        frame_done = 1;
        wait (packets == 3);
        repeat (10) @(negedge clk);
        if (packets != 3) $fatal(1,"Sticky frame_done generated duplicate marker");
        frame_done = 0;
        repeat (3) @(negedge clk);
        frame_done = 1;
        wait (packets == 4);
        if (marker_overflow) $fatal(1,"Unexpected marker overflow");
        $display("PASS: UDP packet format, metadata, stalls, ordering, sticky completion and empty frame");
        $finish;
    end
    initial begin #100000; $fatal(1,"Timeout"); end
endmodule
