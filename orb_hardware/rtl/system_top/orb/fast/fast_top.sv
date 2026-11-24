`timescale 1ns / 1ps

module fast_top #(
    parameter int unsigned FRAME_WIDTH  = 640,
    parameter int unsigned FRAME_HEIGHT = 480
)(
    input  logic       clk,
    input  logic       reset,
    input  logic [6:0][6:0][7:0] win,
    input  logic       win_valid,
    input  logic [18:0] win_pos,
    input  logic [7:0] threshold,

    output logic       out_valid,
    output logic       out_inside,
    output logic [9:0] out_x,
    output logic [8:0] out_y,
    output logic       out_keypoint,
    output logic [7:0] out_score,
    output logic [7:0] out_gray
);

    logic        score_intermediate_valid;
    logic [7:0]  score_intermediate_raw;
    logic [26:0] score_intermediate_tag;

    fast_score #(.TAG_W(27)) score (
        .clk(clk), .reset(reset),
        .in_valid(win_valid), .in_win(win), .threshold(threshold),
        .in_tag({win_pos, win[3][3]}),
        .out_valid(score_intermediate_valid), .out_score(score_intermediate_raw), 
        .out_tag(score_intermediate_tag)
    );

    logic [9:0] score_intermediate_col;
    logic [8:0] score_intermediate_row;
    logic [7:0] score_intermediate_gray;
    
    assign score_intermediate_col = score_intermediate_tag[26:17];
    assign score_intermediate_row = score_intermediate_tag[16:8];
    assign score_intermediate_gray = score_intermediate_tag[7:0];

    logic [7:0] score_intermediate_score;
    assign score_intermediate_score = ((score_intermediate_col >= 6) && (score_intermediate_row >= 6)) ? score_intermediate_raw : 8'd0;

    logic [18:0] nms_pos;

    fast_nms #(
        .LINE_W(FRAME_WIDTH), .AUX_W(8), .TAG_W(19)
    ) nms (
        .clk(clk), .reset(reset),
        .in_valid(score_intermediate_valid), .in_score(score_intermediate_score),
       .in_aux(score_intermediate_gray),
        .in_col(score_intermediate_col), 
        .in_tag({score_intermediate_col, score_intermediate_row}),
        .out_valid(out_valid), .out_keypoint(out_keypoint),
        .out_score(out_score), .out_aux(out_gray), .out_tag(nms_pos)
    );

    logic [9:0] nms_col;
    assign nms_col = nms_pos[18:9];
    logic [8:0] nms_row;
    assign nms_row = nms_pos[8:0];

    assign out_inside = (nms_col >= 4) && (nms_row >= 4);
    assign out_x      = nms_col - 10'd4;
    assign out_y      = nms_row - 9'd4;

endmodule
