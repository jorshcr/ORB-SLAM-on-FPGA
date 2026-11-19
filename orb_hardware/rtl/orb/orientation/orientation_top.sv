`timescale 1ns / 1ps

module orientation_top #(
    parameter int unsigned TAG_W = 19
)(
    input logic clk,
    input logic reset,
    input logic [36:0][7:0] in_col,
    input logic in_valid,
    input logic [TAG_W-1:0] in_tag,

    output logic [1:0] out_quadrant,
    output logic [5:0] out_sector,
    output logic out_valid,
    output logic [TAG_W-1:0] out_tag
);
    logic signed [21:0] m10, m01;
    logic moment_valid;
    logic [TAG_W-1:0] moment_tag;

    moment_compute #(.TAG_W(TAG_W)) moments (
        .clk(clk), .reset(reset),
        .in_col(in_col), .in_valid(in_valid), .in_tag(in_tag),
        .m00(), .m10(m10), .m01(m01),
        .out_valid(moment_valid), .out_tag(moment_tag)
    );

    quadrant_angle_compute #(.TAG_W(TAG_W)) angle (
        .clk(clk), .reset(reset),
        .m10(m10), .m01(m01),
        .in_valid(moment_valid), .in_tag(moment_tag),
        .out_quadrant(out_quadrant), .out_sector(out_sector),
        .out_valid(out_valid), .out_tag(out_tag)
    );

endmodule
