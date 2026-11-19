`timescale 1ns / 1ps

module orb_pyramid_level #(
    parameter int unsigned FRAME_WIDTH  = 640,
    parameter int unsigned FRAME_HEIGHT = 480
)(
    input  logic       clk,
    input  logic       reset,
    input  logic [6:0][6:0][7:0] win,
    input  logic win_valid,
    input  logic [18:0] win_pos,
    input  logic [7:0] threshold,

    output logic       out_valid,
    output logic       out_inside,
    output logic [9:0] out_x,
    output logic [8:0] out_y,
    output logic       out_keypoint,
    output logic [7:0] out_score,
    output logic [7:0] out_gray,
    output logic [36:0][36:0][7:0] blur_win,
    output logic blur_win_valid,
    output logic blur_win_inside,
    output logic [18:0] blur_win_pos,
    output logic [1:0] orientation_quadrant,
    output logic [5:0] orientation_sector,
    output logic orientation_valid,
    output logic [18:0] orientation_pos
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

    logic gaussian_valid;
    logic [7:0] gaussian_gray;
    logic [9:0] gaussian_x;
    logic [8:0] gaussian_y;

    // Preserve newest-input coordinates for raster addressing and tags.
    gaussian_blur gaussian (
        .clk(clk), .reset(reset),
        .win(win), .win_valid(win_valid),
        .in_x(win_pos[18:9]), .in_y(win_pos[8:0]),
        .out_valid(gaussian_valid), .out_gray(gaussian_gray),
        .out_x(gaussian_x), .out_y(gaussian_y)
    );

    line_window #(
        .N(37), .LINE_W(FRAME_WIDTH), .DATA_W(8), .TAG_W(19)
    ) descriptor_window (
        .clk(clk), .reset(reset),
        .in_valid(gaussian_valid), .in_data(gaussian_gray),
        .in_col(gaussian_x), .in_tag({gaussian_x, gaussian_y}),
        .out_valid(blur_win_valid), .out_win(blur_win), .out_tag(blur_win_pos)
    );

    // Full support is 43x43; the blurred patch center is tag minus (21,21).
    assign blur_win_inside = (blur_win_pos[18:9] >= 42) && (blur_win_pos[8:0] >= 42);

    logic [36:0][7:0] orientation_col;
    logic orientation_valid_raw;
    logic column_inside;

    // Zero incomplete columns so unknown border pixels cannot poison the accumulators.
    assign column_inside = (blur_win_pos[18:9] >= 6) && (blur_win_pos[8:0] >= 42);
    for (genvar row = 0; row < 37; row++) begin : g_orientation_col
        assign orientation_col[row] = column_inside ? blur_win[row][36] : 8'd0;
    end

    orientation_top #(.TAG_W(19)) orientation (
        .clk(clk), .reset(reset),
        .in_col(orientation_col), .in_valid(blur_win_valid), .in_tag(blur_win_pos),
        .out_quadrant(orientation_quadrant), .out_sector(orientation_sector),
        .out_valid(orientation_valid_raw), .out_tag(orientation_pos)
    );

    // Tags retain newest-input coordinates; patch center is tag minus (21,21).
    assign orientation_valid = orientation_valid_raw &&
                               (orientation_pos[18:9] >= 42) && (orientation_pos[8:0] >= 42);

endmodule
