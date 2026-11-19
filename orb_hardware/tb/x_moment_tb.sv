`timescale 1ns / 1ps
module x_moment_tb;
    logic clk = 0, reset = 1, in_valid = 0;
    logic [13:0] c_in = 0, c_out = 0;
    logic signed [21:0] m10, m00;
    logic out_valid;
    int columns [0:36];
    int expected_m00 [0:1], expected_m10 [0:1];
    logic [1:0] valid = 0;
    int checked = 0;
    x_moment dut (.*);
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 37; i++) columns[i] = 0;
            valid = 0;
        end else begin
            expected_m00[1] = expected_m00[0];
            expected_m10[1] = expected_m10[0];
            valid = {valid[0], in_valid};
            if (in_valid) begin
                if (c_out != columns[0]) $fatal(1, "Bad outgoing stimulus");
                for (int i = 0; i < 36; i++) columns[i] = columns[i+1];
                columns[36] = c_in;
                expected_m00[0] = 0;
                expected_m10[0] = 0;
                for (int i = 0; i < 37; i++) begin
                    expected_m00[0] += columns[i];
                    expected_m10[0] += (i-18)*columns[i];
                end
            end
        end
        #1;
        if (out_valid !== valid[1]) $fatal(1, "Valid mismatch");
        if (reset && (m00 !== 0 || m10 !== 0)) $fatal(1, "Reset mismatch");
        if (out_valid) begin
            if (m00 !== expected_m00[1] || m10 !== expected_m10[1])
                $fatal(1, "Moment mismatch: %0d/%0d expected %0d/%0d", m00,m10,expected_m00[1],expected_m10[1]);
            checked++;
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        reset = 0;
        for (int n = 0; n < 1000; n++) begin
            @(negedge clk);
            reset = (n == 500);
            in_valid = (n < 150) || (n % 4 != 0);
            c_out = 14'(columns[0]);
            if (n < 50) c_in = 9435;
            else if (n < 100) c_in = 0;
            else c_in = 14'((n*7919) % 9436);
        end
        @(negedge clk);
        in_valid = 0;
        repeat (4) @(negedge clk);
        if (checked < 750) $fatal(1, "Too few results");
        $display("PASS: x_moment, %0d direct-window comparisons; gaps, reset and two-stage latency", checked);
        $finish;
    end
endmodule
