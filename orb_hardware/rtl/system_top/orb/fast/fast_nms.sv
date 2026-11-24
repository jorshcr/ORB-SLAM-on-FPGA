`timescale 1ns / 1ps

module fast_nms #(
    parameter int unsigned LINE_W = 640,
    parameter int unsigned AUX_W  = 8, // holds grayscale val through nms
    parameter int unsigned TAG_W  = 1
)(
    input  logic             clk,
    input  logic             reset,
    input  logic             in_valid,
    input  logic [7:0]       in_score,
    input  logic [AUX_W-1:0] in_aux,
    input  logic [9:0]       in_col,
    input  logic [TAG_W-1:0] in_tag,

    output logic              out_valid,
    output logic              out_keypoint,
    output logic  [7:0]       out_score,
    output logic  [AUX_W-1:0] out_aux,
    output logic  [TAG_W-1:0] out_tag
);
    // Line buffer holds fast score and grayscale pix value
    localparam int unsigned DW = 8 + AUX_W; 

    logic              win_valid;
    logic [2:0][2:0][DW-1:0] win;
    logic [TAG_W-1:0]  win_tag;

    line_window #(
        .N(3), .LINE_W(LINE_W), .DATA_W(DW), .TAG_W(TAG_W)
    ) fast_score_window (
        .clk(clk), .reset(reset),
        .in_valid(in_valid), .in_data({in_aux, in_score}),
        .in_col(in_col), .in_tag(in_tag),
        .out_valid(win_valid), .out_win(win), .out_tag(win_tag)
    );

    logic [7:0] scores [0:8]; // all scores in 3x3 window
    genvar g;
    generate
        for (g = 0; g < 9; g = g + 1) begin : unpack
            assign scores[g] = win[g/3][g%3][7:0];
        end
    endgenerate

    logic [7:0] c;
    assign c = scores[4];
    logic [8:0] greater;
    logic is_max;
    for (genvar i = 0; i < 9; i++) begin : g_compare
        assign greater[i] = (i == 4) ? 1'b1 : (c > scores[i]);
    end
    assign is_max = (c != 0) && (&greater);

    always_ff @(posedge clk) begin
        out_keypoint <= is_max;
        out_score    <= c;
        out_aux      <= win[1][1][8 +: AUX_W];
        out_tag      <= win_tag;

        if (reset)
            out_valid <= 1'b0;
        else
            out_valid <= win_valid;
    end

endmodule
