`timescale 1ns / 1ps

module gaussian_blur_tb;
    logic clk = 0, reset = 1, win_valid = 0;
    logic [6:0][6:0][7:0] win = '0;
    logic [9:0] in_x = 0, out_x;
    logic [8:0] in_y = 0, out_y;
    logic out_valid;
    logic [7:0] out_gray;
    localparam int W [0:6] = '{1, 6, 15, 20, 15, 6, 1};
    logic [7:0] expected_gray [0:7];
    logic [9:0] expected_x [0:7];
    logic [8:0] expected_y [0:7];
    logic [7:0] expected_valid = 0;
    int total, checked = 0;
    int unsigned rng = 32'h12345678;

    gaussian_blur dut (.*);
    always #5 clk = ~clk;

    function automatic int unsigned random_value();
        rng = rng * 1664525 + 1013904223;
        return rng;
    endfunction

    always @(posedge clk) begin
        for (int stage = 7; stage > 0; stage--) begin
            expected_gray[stage] = expected_gray[stage-1];
            expected_x[stage] = expected_x[stage-1];
            expected_y[stage] = expected_y[stage-1];
        end

        total = 0;
        for (int row = 0; row < 7; row++)
            for (int col = 0; col < 7; col++)
                total += int'(win[row][col]) * W[row] * W[col];

        expected_gray[0] = 8'(total >> 12);
        expected_x[0] = in_x;
        expected_y[0] = in_y;
        expected_valid = reset ? '0 : {expected_valid[6:0], win_valid};

        #1;
        if (out_valid !== expected_valid[7])
            $fatal(1, "Valid/latency mismatch");
        if (out_valid) begin
            if (out_gray !== expected_gray[7] || out_x !== expected_x[7] || out_y !== expected_y[7])
                $fatal(1, "Pixel or coordinate mismatch: got %0d expected %0d", out_gray, expected_gray[7]);
            checked++;
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        reset = 0;
        for (int test_id = 0; test_id < 1100; test_id++) begin
            @(negedge clk);
            reset = (test_id == 500);
            win_valid = (test_id < 100) || (test_id % 4 != 0);
            in_x = 10'(random_value());
            in_y = 9'(random_value());
            for (int row = 0; row < 7; row++) begin
                for (int col = 0; col < 7; col++) begin
                    if (test_id == 0) win[row][col] = 0;
                    else if (test_id == 1) win[row][col] = 255;
                    else if (test_id < 51) win[row][col] = (row*7+col == test_id-2) ? 255 : 0;
                    else win[row][col] = 8'(random_value() >> 16);
                end
            end
        end
        @(negedge clk);
        win_valid = 0;
        repeat (10) @(negedge clk);
        if (checked < 800) $fatal(1, "Insufficient outputs checked");
        $display("PASS: gaussian_blur, %0d outputs, 8-stage latency, coordinates, gaps and reset", checked);
        $finish;
    end
endmodule
