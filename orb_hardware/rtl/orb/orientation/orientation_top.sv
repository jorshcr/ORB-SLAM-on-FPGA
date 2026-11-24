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
    output logic [3:0] out_sector,
    output logic out_valid,
    output logic [TAG_W-1:0] out_tag,
    output logic signed [7:0] out_sin,
    output logic signed [7:0] out_cos
);
    logic signed [21:0] m10, m01;
    logic moment_valid;
    logic [TAG_W-1:0] moment_tag;
    logic [1:0] angle_quadrant;
    logic [3:0] angle_sector;
    logic angle_valid;
    logic [TAG_W-1:0] angle_tag;

    // Sector k represents alpha=(k+0.5)*90/16 degrees in the first quadrant.
    // Signed fixed point: value = integer/128 (7 fractional bits).
    // Round magnitudes to nearest and saturate at 127; +1 is not representable.
    // cos(alpha[k]) = sin(alpha[15-k]). Quadrant encodes moment signs,
    // not an additional 90-degree rotation of this magnitude-based index.
    localparam logic signed [7:0] SIN_MAG [0:15] = '{
        8'sd6, 8'sd19, 8'sd31, 8'sd43,
        8'sd55, 8'sd66, 8'sd76, 8'sd86,
        8'sd95, 8'sd103, 8'sd110, 8'sd116,
        8'sd121, 8'sd124, 8'sd127, 8'sd127
    };

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
        .out_quadrant(angle_quadrant), .out_sector(angle_sector),
        .out_valid(angle_valid), .out_tag(angle_tag)
    );

    // One final registered stage; metadata and trig values share the latency.
    always_ff @(posedge clk) begin
        if (reset) begin
            out_quadrant <= '0;
            out_sector <= '0;
            out_tag <= '0;
            out_valid <= 1'b0;
            out_sin <= '0;
            out_cos <= '0;
        end else begin
            out_valid <= angle_valid;
            if (angle_valid) begin
                out_quadrant <= angle_quadrant;
                out_sector <= angle_sector;
                out_tag <= angle_tag;
                out_sin <= angle_quadrant[1] ? -SIN_MAG[angle_sector]
                                                    : SIN_MAG[angle_sector];
                out_cos <= (angle_quadrant[1] ^ angle_quadrant[0])
                           ? -SIN_MAG[15-angle_sector] : SIN_MAG[15-angle_sector];
            end
        end
    end

endmodule
