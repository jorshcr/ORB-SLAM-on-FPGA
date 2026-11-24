`timescale 1ns / 1ps

module moment_compute #(
    parameter int unsigned TAG_W = 19
)(
    input logic clk,
    input logic reset,
    input logic [36:0][7:0] in_col,
    input logic in_valid,
    input logic [TAG_W-1:0] in_tag,

    output logic signed [21:0] m00,
    output logic signed [21:0] m10,
    output logic signed [21:0] m01,
    output logic out_valid,
    output logic [TAG_W-1:0] out_tag
);
    // Six sum stages plus two moment stages; tags pass through unchanged.
    localparam int LAT = 8;

    logic [13:0] col_sum;
    logic signed [21:0] y_sum;
    logic col_valid, y_sum_valid, x_valid, y_valid;
    logic [13:0] col_delay [0:36];
    logic signed [21:0] y_delay [0:36];
    logic [TAG_W-1:0] tag_pipe [0:LAT-1];
    logic [LAT-1:0] full_pipe;
    logic [5:0] columns_seen;
    logic [18:-18][7:0] y_col;

    // Packed ordering maps in_col[0] to y=-18 and in_col[36] to y=+18.
    assign y_col = in_col;

    column_sum column_adder (
        .clk(clk), .reset(reset), .in_col(in_col), .in_valid(in_valid),
        .out_sum(col_sum), .out_valid(col_valid)
    );

    y_moment_sum y_adder (
        .clk(clk), .reset(reset), .in_col(y_col), .in_valid(in_valid),
        .out_sum(y_sum), .out_valid(y_sum_valid)
    );

    x_moment x_compute (
        .clk(clk), .reset(reset), .c_in(col_sum), .c_out(col_delay[36]),
        .in_valid(col_valid), .m00(m00), .m10(m10), .out_valid(x_valid)
    );

    y_moment y_compute (
        .clk(clk), .reset(reset), .cin(y_sum), .cout(y_delay[36]),
        .in_valid(y_sum_valid), .m01(m01), .out_valid(y_valid)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            col_delay <= '{default:'0};
            y_delay <= '{default:'0};
            columns_seen <= '0;
            full_pipe <= '0;
            tag_pipe <= '{default:'0};
        end else begin
            // Tags advance each clock; history advances only for valid columns.
            tag_pipe[0] <= in_tag;
            for (int i = 1; i < LAT; i++)
                tag_pipe[i] <= tag_pipe[i-1];

            full_pipe <= {full_pipe[LAT-2:0], in_valid && (columns_seen >= 36)};
            if (in_valid && columns_seen < 37)
                columns_seen <= columns_seen + 1'b1;

            if (col_valid) begin
                col_delay[0] <= col_sum;
                for (int i = 1; i < 37; i++)
                    col_delay[i] <= col_delay[i-1];
            end

            if (y_sum_valid) begin
                y_delay[0] <= y_sum;
                for (int i = 1; i < 37; i++)
                    y_delay[i] <= y_delay[i-1];
            end
        end
    end

    // Caller masks row borders; this gate handles initial history fill only.
    assign out_valid = x_valid && y_valid && full_pipe[LAT-1];
    assign out_tag = tag_pipe[LAT-1];

endmodule
