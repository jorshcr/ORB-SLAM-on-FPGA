`timescale 1ns / 1ps

module orb_pyramid_level #(
    parameter int unsigned FRAME_WIDTH  = 640,
    parameter int unsigned FRAME_HEIGHT = 480,
    parameter int unsigned KEYPOINT_FIFO_DEPTH = 512,
    parameter int unsigned BRIEF_ENGINES = 3
)(
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] in_pixel,
    input  logic in_valid,
    input  logic [9:0] in_x,
    input  logic [8:0] in_y,
    input  logic [7:0] threshold,

    output logic kp_overflow,
    output logic [BRIEF_ENGINES-1:0] brief_valid,
    output logic [BRIEF_ENGINES-1:0][255:0] brief_descriptor,
    output logic [BRIEF_ENGINES-1:0][18:0] brief_pos,
    output logic [BRIEF_ENGINES-1:0][7:0] brief_score,
    output logic brief_dropped
);

    logic       out_valid;
    logic       out_inside;
    logic [9:0] out_x;
    logic [8:0] out_y;
    logic       out_keypoint;
    logic [7:0] out_score;
    logic [7:0] out_gray;
    logic [36:0][36:0][7:0] blur_win;
    logic blur_win_valid;
    logic blur_win_inside;
    logic [18:0] blur_win_pos;
    logic [1:0] orientation_quadrant;
    logic [3:0] orientation_sector;
    logic orientation_valid;
    logic [18:0] orientation_pos;
    logic signed [7:0] orientation_sin;
    logic signed [7:0] orientation_cos;
    logic       kp_valid;
    logic       kp_ready;
    logic [9:0] kp_x;
    logic [8:0] kp_y;
    logic [7:0] kp_score;
    logic       kp_reset_busy;
    logic [BRIEF_ENGINES-1:0] brief_busy;

    logic [6:0][6:0][7:0] win;
    logic win_valid;
    logic [18:0] win_pos;

    line_window #(
        .N(7), .LINE_W(FRAME_WIDTH), .DATA_W(8), .TAG_W(19)
    ) pixel_window (
        .clk(clk), .reset(reset),
        .in_valid(in_valid), .in_data(in_pixel),
        .in_col(in_x), .in_tag({in_x, in_y}),
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

    logic kp_push, kp_write_ready;
    logic kp_patch_inside;
    logic [26:0] kp_head;

    // The 37x37 blurred patch needs a 21-pixel border including Gaussian support.
    assign kp_patch_inside = (FRAME_WIDTH >= 43) && (FRAME_HEIGHT >= 43) &&
                             (out_x >= 21) && (out_x < FRAME_WIDTH - 21) &&
                             (out_y >= 21) && (out_y < FRAME_HEIGHT - 21);

    assign kp_push = out_valid && out_inside && out_keypoint && kp_patch_inside;
    assign {kp_x, kp_y, kp_score} = kp_head;

    fifo_sync #(
        .DATA_W(27), .DEPTH(KEYPOINT_FIFO_DEPTH), .MEMORY_TYPE("block")
    ) keypoint_fifo (
        .clk(clk), .reset(reset),
        .in_data({out_x, out_y, out_score}),
        .in_valid(kp_push), .in_ready(kp_write_ready),
        .out_data(kp_head), .out_valid(kp_valid), .out_ready(kp_ready),
        .reset_busy(kp_reset_busy)
    );

    // FAST cannot stall: preserve queued records, drop new arrivals when
    // blocked, and report the loss (including arrivals during reset recovery).
    always_ff @(posedge clk) begin
        if (reset)
            kp_overflow <= 1'b0;
        else if (kp_push && !kp_write_ready)
            kp_overflow <= 1'b1;
    end

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
        .out_valid(orientation_valid_raw), .out_tag(orientation_pos),
        .out_sin(orientation_sin), .out_cos(orientation_cos)
    );

    // Tags retain newest-input coordinates; patch center is tag minus (21,21).
    assign orientation_valid = orientation_valid_raw &&
                               (orientation_pos[18:9] >= 42) && (orientation_pos[8:0] >= 42);

    localparam int COLUMN_DELAY = 12; // Orientation takes 13 clocks; window load takes one.
    logic [36:0][5:0] brief_col_delayed [0:COLUMN_DELAY-1];
    logic [COLUMN_DELAY-1:0] brief_col_valid;
    localparam int ENGINE_W = (BRIEF_ENGINES > 1) ? $clog2(BRIEF_ENGINES) : 1;
    logic [BRIEF_ENGINES-1:0] brief_start;
    logic [ENGINE_W-1:0] brief_selected;
    logic brief_available, keypoint_matches, keypoint_stale;
    logic [9:0] orientation_x;
    logic [8:0] orientation_y;

    assign orientation_x = orientation_pos[18:9] - 10'd21;
    assign orientation_y = orientation_pos[8:0] - 9'd21;
    assign keypoint_matches = kp_valid && orientation_valid &&
                              (kp_x == orientation_x) && (kp_y == orientation_y);
    assign keypoint_stale = kp_valid && orientation_valid &&
                           ((kp_y < orientation_y) ||
                            ((kp_y == orientation_y) && (kp_x < orientation_x)));
    assign kp_ready = !reset && (keypoint_matches || keypoint_stale);

    always_comb begin
        brief_available = 1'b0;
        brief_selected = '0;
        for (int engine = BRIEF_ENGINES-1; engine >= 0; engine--) begin
            if (!brief_busy[engine]) begin
                brief_available = 1'b1;
                brief_selected = ENGINE_W'(engine);
            end
        end

        brief_start = '0;
        if (!reset && keypoint_matches && brief_available)
            brief_start[brief_selected] = 1'b1;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            brief_col_valid <= '0;
            brief_pos <= '0;
            brief_score <= '0;
            brief_dropped <= 1'b0;
        end else begin
            brief_col_valid <= {brief_col_valid[COLUMN_DELAY-2:0], blur_win_valid};
            for (int row = 0; row < 37; row++)
                brief_col_delayed[0][row] <= orientation_col[row][7:2];
            for (int stage = 1; stage < COLUMN_DELAY; stage++)
                brief_col_delayed[stage] <= brief_col_delayed[stage-1];

            if (keypoint_stale || (keypoint_matches && !brief_available))
                brief_dropped <= 1'b1;
            if (|brief_start) begin
                brief_pos[brief_selected] <= {kp_x, kp_y};
                brief_score[brief_selected] <= kp_score;
            end
        end
    end

    for (genvar engine = 0; engine < BRIEF_ENGINES; engine++) begin : g_brief
        brief_engine brief (
            .clk(clk), .reset(reset),
            .in_col(brief_col_delayed[COLUMN_DELAY-1]),
            .in_valid(brief_col_valid[COLUMN_DELAY-1]),
            .in_angle(orientation_sector), .in_quadrant(orientation_quadrant),
            .sine(orientation_sin), .cosine(orientation_cos), .in_score(kp_score),
            .keypoint_match(brief_start[engine]), .busy(brief_busy[engine]),
            .out_descriptor(brief_descriptor[engine]), .out_valid(brief_valid[engine])
        );
    end

endmodule
