`timescale 1ns / 1ps

module moment_compute_tb;
    logic clk = 0, reset = 1, in_valid = 0;
    logic [36:0][7:0] in_col = '0;
    logic [18:0] in_tag = 0, out_tag;
    logic signed [21:0] m00, m10, m01;
    logic out_valid;
    int pixels [0:36][0:36];
    int sums00 [0:7], sums10 [0:7], sums01 [0:7];
    logic [18:0] tags [0:7];
    logic [7:0] expected_valid = 0;
    int seen = 0, checked = 0;
    int unsigned rng = 32'h98765432;

    moment_compute dut (.*);
    always #5 clk = ~clk;

    function automatic int unsigned random_value();
        rng = rng * 1664525 + 1013904223;
        return rng;
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            expected_valid = 0;
            seen = 0;
            for (int r = 0; r < 37; r++)
                for (int c = 0; c < 37; c++) pixels[r][c] = 0;
        end else begin
            for (int i = 7; i > 0; i--) begin
                sums00[i] = sums00[i-1];
                sums10[i] = sums10[i-1];
                sums01[i] = sums01[i-1];
                tags[i] = tags[i-1];
            end
            tags[0] = in_tag;
            expected_valid = {expected_valid[6:0], in_valid && (seen >= 36)};
            if (in_valid) begin
                seen++;
                for (int r = 0; r < 37; r++) begin
                    for (int c = 0; c < 36; c++) pixels[r][c] = pixels[r][c+1];
                    pixels[r][36] = int'(in_col[r]);
                end
                sums00[0] = 0;
                sums10[0] = 0;
                sums01[0] = 0;
                for (int r = 0; r < 37; r++) begin
                    for (int c = 0; c < 37; c++) begin
                        sums00[0] += pixels[r][c];
                        sums10[0] += (c-18)*pixels[r][c];
                        sums01[0] += (r-18)*pixels[r][c];
                    end
                end
            end
        end
        #1;
        if (out_valid !== expected_valid[7]) $fatal(1, "Valid/latency mismatch");
        if (out_valid) begin
            if (m00 !== sums00[7] || m10 !== sums10[7] || m01 !== sums01[7] || out_tag !== tags[7])
                $fatal(1, "Moment/tag mismatch: got %0d,%0d,%0d tag %0d expected %0d,%0d,%0d tag %0d",
                       m00,m10,m01,out_tag,sums00[7],sums10[7],sums01[7],tags[7]);
            checked++;
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        reset = 0;
        for (int n = 0; n < 1100; n++) begin
            @(negedge clk);
            reset = (n == 600);
            in_valid = (n < 300) || ((n % 5 != 0) && !(n >= 800 && n < 820));
            in_tag = 19'(n*311);
            for (int r = 0; r < 37; r++) begin
                if (n < 50) in_col[r] = 255;
                else if (n < 100) in_col[r] = 0;
                else if (n < 150) in_col[r] = r < 18 ? 255 : 0;
                else if (n < 200) in_col[r] = r > 18 ? 255 : 0;
                else if (n < 250) in_col[r] = 8'(n);
                else in_col[r] = 8'(random_value() >> 16);
            end
        end
        @(negedge clk);
        in_valid = 0;
        repeat (10) @(negedge clk);
        if (checked < 800) $fatal(1, "Too few full windows checked: %0d", checked);
        $display("PASS: moment_compute, %0d full 37x37 moment/tag comparisons, eight-stage latency, gaps and reset", checked);
        $finish;
    end
endmodule
