`timescale 1ns / 1ps

module y_moment_sum (
    input logic clk,
    input logic reset,
    input logic [18:-18][7:0] in_col,
    input logic in_valid,

    output logic signed [21:0] out_sum,
    output logic out_valid
);

    logic signed [16:0] s18 [0:17];
    logic signed [17:0] s9 [0:8];
    logic signed [18:0] s5 [0:4];
    logic signed [19:0] s3 [0:2];
    logic signed [20:0] s2 [0:1];
    logic signed [21:0] s1;

    logic signed [8:0] cin [18:-18];

    for (genvar row = -18; row <= 18; row++) begin : g_extend
        assign cin[row] = $signed({1'b0, in_col[row]});
    end

    logic [5:0] valid_pipe;

    assign out_sum = s1;
    assign out_valid = valid_pipe[5];


    always_ff @(posedge clk) begin
        if (reset)
            valid_pipe <= '0;
        else
            valid_pipe <= {valid_pipe[4:0], in_valid};

        // 36 -> 18 -> 9 -> 5 -> 3 -> 2 -> 1; six clocked stages.
        for (int i = 1; i <= 18; i = i + 1) begin
            // Initial weight with Y value in column
            s18[i-1] <= i * (cin[i] - cin[-i]);
        end

        for (int i = 0; i < 9; i = i + 1) begin
            s9[i] <= s18[2*i] + s18[2*i+1];
        end

        for (int i = 0; i < 4; i = i + 1) begin
            s5[i] <= s9[2*i] + s9[2*i+1];
        end
        s5[4] <= s9[8];

        for (int i = 0; i < 2; i = i + 1) begin
            s3[i] <= s5[2*i] + s5[2*i+1];
        end
        s3[2] <= s5[4];

        s2[0] <= s3[0] + s3[1];
        s2[1] <= s3[2];

        s1 <= s2[0] + s2[1];
    end

endmodule
