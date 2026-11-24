`timescale 1ns / 1ps

module y_moment (
    input logic clk,
    input logic reset,
    input logic signed [21:0] cin,
    input logic signed [21:0] cout,
    input logic in_valid,

    output logic signed [21:0] m01,
    output logic out_valid
);
    logic signed [21:0] delta;
    logic valid_delayed;

    always_ff @(posedge clk) begin
        if (reset) begin
            delta <= '0;
            valid_delayed <= 1'b0;
            m01 <= '0;
            out_valid <= 1'b0;
        end else begin
            valid_delayed <= in_valid;
            out_valid <= valid_delayed;

            if (in_valid)
                delta <= cin - cout;

            if (valid_delayed)
                m01 <= m01 + delta;
        end
    end

endmodule
