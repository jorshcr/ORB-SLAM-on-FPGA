`timescale 1ns / 1ps

module column_sum (
    input logic clk,
    input logic reset,
    input logic [36:0][7:0] in_col,
    input logic in_valid,

    output logic [13:0] out_sum,
    output logic out_valid
);

    logic [8:0] s19 [0:18];
    logic [9:0] s10 [0:9];
    logic [10:0] s5 [0:4];
    logic [11:0] s3 [0:2];
    logic [12:0] s2 [0:1];
    logic [13:0] s1;

    logic [5:0] valid_pipe;

    assign out_sum = s1;
    assign out_valid = valid_pipe[5];

    always_ff @(posedge clk) begin
        if (reset)
            valid_pipe <= '0;
        else
            valid_pipe <= {valid_pipe[4:0], in_valid};

        // 37 -> 19 -> 10 -> 5 -> 3 -> 2 -> 1; six clocked stages.
        for (int i = 0; i < 18; i = i + 1) begin
            s19[i] <= in_col[2*i] + in_col[2*i+1];
        end
        s19[18] <= {1'b0, in_col[36]};

        for (int i = 0; i < 9; i = i + 1) begin
            s10[i] <= s19[2*i] + s19[2*i+1];
        end
        s10[9] <= {1'b0, s19[18]};

        for (int i = 0; i < 5; i = i + 1) begin
            s5[i] <= s10[2*i] + s10[2*i+1];
        end

        for (int i = 0; i < 2; i = i + 1) begin
            s3[i] <= s5[2*i] + s5[2*i+1];
        end
        s3[2] <= s5[4];

        s2[0] <= s3[0] + s3[1];
        s2[1] <= s3[2];

        s1 <= s2[0] + s2[1];
    end

endmodule
