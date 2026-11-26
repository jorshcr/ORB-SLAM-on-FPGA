`timescale 1ns / 1ps
module tan_multiply_tb;
    logic clk = 0, reset = 1, in_valid = 0;
    logic [21:0] abs_moment_x = 0;
    logic [14:0][34:0] products;
    logic out_valid;
    real theta;
    longint unsigned coefficient, expected;
    int checked = 0;
    tan_multiply dut (.*);
    always #5 clk = ~clk;

    always @(posedge clk) begin
        #1;
        if (out_valid !== (in_valid && !reset)) $fatal(1, "Valid mismatch");
        if (out_valid) begin
            for (int k = 0; k < 15; k++) begin
                theta = (k + 1) * 3.141592653589793 / 32.0;
                coefficient = $rtoi(($sin(theta)/$cos(theta)) * 256.0 + 0.5);
                expected = longint'(abs_moment_x) * coefficient;
                if (products[k] !== expected[34:0]) $fatal(1, "Product mismatch at %0d", k);
                checked++;
            end
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        reset = 0;
        for (int n = 0; n < 200; n++) begin
            @(negedge clk);
            reset = (n == 100);
            in_valid = n < 5 || n % 4 != 0;
            case (n)
                0: abs_moment_x = 0;
                1: abs_moment_x = 1;
                2: abs_moment_x = 22'h200000;
                3: abs_moment_x = '1;
                default: abs_moment_x = 22'(n * 97139);
            endcase
        end
        @(negedge clk);
        in_valid = 0;
        repeat (2) @(negedge clk);
        if (checked < 2000) $fatal(1, "Too few checks");
        $display("PASS: tan_multiply, %0d products; coefficients, widths and valid", checked);
        $finish;
    end
endmodule
