`timescale 1ns / 1ps

module x_moment (
    input logic clk,
    input logic reset,
    input logic [13:0] c_in,
    input logic [13:0] c_out,
    input logic in_valid,

    output logic signed [21:0] m10,
    output logic signed [21:0] m00,
    output logic out_valid
);
    logic signed [21:0] cin, cout;
    logic signed [21:0] delta, weighted;
    logic valid_delayed;

    assign cin = $signed({8'b0, c_in});
    assign cout = $signed({8'b0, c_out});

    always_ff @(posedge clk) begin
        if (reset) begin
            delta <= '0;
            weighted <= '0;
            valid_delayed <= 1'b0;
            m00 <= '0;
            m10 <= '0;
            out_valid <= 1'b0;
        end else begin
            valid_delayed <= in_valid;
            out_valid <= valid_delayed;

            if (in_valid) begin
                delta <= cin - cout;
                weighted <= 22'sd18 * cin + 22'sd19 * cout;
            end

            if (valid_delayed) begin
                m00 <= m00 + delta;
                m10 <= m10 - m00 + weighted;
            end
        end
    end

endmodule
