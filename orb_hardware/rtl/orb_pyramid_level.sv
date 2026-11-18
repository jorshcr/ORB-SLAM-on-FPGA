`timescale 1ns / 1ps

module orb_pyramid_level #(
    parameter int unsigned FRAME_WIDTH  = 640,
    parameter int unsigned FRAME_HEIGHT = 480
)(
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] pixel_in,
    input  logic       pixel_valid,
    input  logic       frame_start,
    input  logic [7:0] threshold,

    output logic       out_valid,
    output logic       out_inside,
    output logic [9:0] out_x,
    output logic [8:0] out_y,
    output logic       out_keypoint,
    output logic [7:0] out_score,
    output logic [7:0] out_gray
);

    logic  [9:0] col_count;
    logic  [8:0] row_count;
    logic [9:0] col;
    assign col = frame_start ? 10'd0 : col_count;
    logic [8:0] row;
    assign row = frame_start ? 9'd0  : row_count;

    always_ff @(posedge clk) begin
        if (reset) begin
            col_count <= 0;
            row_count <= 0;
        end else if (pixel_valid) begin
            if (col == FRAME_WIDTH - 1) begin
                col_count <= 0;
                row_count <= (row == FRAME_HEIGHT - 1) ? 9'd0 : row + 1'b1;
            end else begin
                col_count <= col + 1'b1;
                row_count <= row;
            end
        end
    end

    logic             win_valid;
    logic [6:0][6:0][7:0] win;
    logic [18:0]      win_pos;

    line_window #(
        .N(7), .LINE_W(FRAME_WIDTH), .DATA_W(8), .TAG_W(19)
    ) pixel_window (
        .clk(clk), .reset(reset),
        .in_valid(pixel_valid), .in_data(pixel_in),
        .in_col(col), .in_tag({col, row}),
        .out_valid(win_valid), .out_win(win), .out_tag(win_pos)
    );

    fast_top #(
        .FRAME_WIDTH(FRAME_WIDTH), .FRAME_HEIGHT(FRAME_HEIGHT)
    ) fast (
        .clk(clk), .reset(reset),
        .win(win), .win_valid(win_valid), .win_pos(win_pos),
        .threshold(threshold),
        .out_valid(out_valid), .out_inside(out_inside),
        .out_x(out_x), .out_y(out_y), .out_keypoint(out_keypoint),
        .out_score(out_score), .out_gray(out_gray)
    );

endmodule
