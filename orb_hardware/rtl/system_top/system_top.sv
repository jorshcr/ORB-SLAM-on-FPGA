`timescale 1ns / 1ps

module system_top #(
    parameter int ORB_LEVELS = 3,
    parameter int FRAME_WIDTH [0:ORB_LEVELS-1] = '{default:640},
    parameter int FRAME_HEIGHT [0:ORB_LEVELS-1] = '{default:480},
    parameter int BRIEF_ENGINES = 3,
    parameter int KEYPOINT_FIFO_DEPTH = 512,
    parameter int DESCRIPTOR_FIFO_DEPTH = 256
)(
    input logic clk,
    input logic reset,
    input logic [ORB_LEVELS-1:0][7:0] in_pixel,
    input logic [ORB_LEVELS-1:0] in_valid,
    input logic [ORB_LEVELS-1:0][9:0] in_x,
    input logic [ORB_LEVELS-1:0][8:0] in_y,
    input logic [ORB_LEVELS-1:0][7:0] threshold,

    output logic out_valid,
    input logic out_ready,
    output logic [255:0] out_descriptor,
    output logic [18:0] out_pos,
    output logic [1:0] out_octave,
    output logic [2:0] out_frame_id,
    output logic reset_busy,
    output logic [ORB_LEVELS-1:0] kp_overflow,
    output logic [ORB_LEVELS-1:0] brief_dropped
);

    logic [ORB_LEVELS-1:0] descriptor_valid, descriptor_ready;
    logic [ORB_LEVELS-1:0][255:0] descriptor_data;
    logic [ORB_LEVELS-1:0][18:0] descriptor_pos;
    logic [ORB_LEVELS-1:0][1:0] descriptor_octave;
    logic [ORB_LEVELS-1:0][2:0] descriptor_frame_id;

    // Initial single-frame wiring; propagate frame tags through ORB before multi-frame use.
    assign descriptor_frame_id = '0;

    for (genvar level = 0; level < ORB_LEVELS; level++) begin : g_orb
        assign descriptor_octave[level] = 2'(level);

        orb_pyramid_level #(
            .FRAME_WIDTH(FRAME_WIDTH[level]), .FRAME_HEIGHT(FRAME_HEIGHT[level]),
            .BRIEF_ENGINES(BRIEF_ENGINES), .KEYPOINT_FIFO_DEPTH(KEYPOINT_FIFO_DEPTH)
        ) orb (
            .clk(clk), .reset(reset),
            .in_pixel(in_pixel[level]), .in_valid(in_valid[level]),
            .in_x(in_x[level]), .in_y(in_y[level]), .threshold(threshold[level]),
            .kp_overflow(kp_overflow[level]), .brief_dropped(brief_dropped[level]),
            .descriptor_valid(descriptor_valid[level]), .descriptor_ready(descriptor_ready[level]),
            .descriptor_data(descriptor_data[level]), .descriptor_pos(descriptor_pos[level]),
            .descriptor_score(), .brief_valid(), .brief_descriptor(), .brief_pos(), .brief_score()
        );
    end

    descriptor_output #(.ORB_STREAMS(ORB_LEVELS), .FIFO_DEPTH(DESCRIPTOR_FIFO_DEPTH)) results (
        .clk(clk), .reset(reset),
        .in_valid(descriptor_valid), .in_ready(descriptor_ready),
        .in_descriptor(descriptor_data), .in_pos(descriptor_pos),
        .in_octave(descriptor_octave), .in_frame_id(descriptor_frame_id),
        .out_valid(out_valid), .out_ready(out_ready), .out_descriptor(out_descriptor),
        .out_pos(out_pos), .out_octave(out_octave), .out_frame_id(out_frame_id),
        .reset_busy(reset_busy)
    );

endmodule
