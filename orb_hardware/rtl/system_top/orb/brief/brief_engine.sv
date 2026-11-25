`timescale 1ns / 1ps

module brief_engine (
    input logic clk,
    input logic reset,
    input logic [36:0][5:0] in_col,
    input logic [3:0] in_angle,  // Quadrant-local sector index, 0-15.
    input logic [1:0] in_quadrant,
    input logic signed [7:0] sine,  // Signed fixed point, 7 fractional bits.
    input logic signed [7:0] cosine,
    input logic [7:0] in_score,
    input logic in_valid,
    input logic keypoint_match,
    output logic busy,

    output logic [255:0] out_descriptor,
    output logic [5:0] out_angle,
    output logic out_valid,
    input logic out_ready
);

    typedef enum logic [1:0] {IDLE, DESCRIPTOR, DRAIN} state_t;
    state_t state;

    logic [7:0] pair_index;
    logic signed [5:0] x_a, y_a, x_b, y_b;
    logic signed [5:0] x_delayed [0:1];
    logic signed [5:0] y_delayed [0:1];
    logic pairs_issued;
    logic [3:0] valid_delayed;
    logic [7:0] pair_delayed [0:3];
    logic [5:0] column_count;
    logic window_ready, window_shift;
    logic in_ready;
    logic [3:0] angle_saved;
    logic [1:0] quadrant_saved;
    logic signed [7:0] sine_saved, cosine_saved;
    logic [7:0] score_saved;
    logic signed [5:0] x_rotated [0:1];
    logic signed [5:0] y_rotated [0:1];
    logic [5:0] window [0:36][0:36];
    logic [5:0] row_pixels [0:1][0:36];
    logic [5:0] row_index_delayed [0:1];
    logic [5:0] pixel_a, pixel_b;
    (* use_dsp = "yes" *) logic signed [13:0] x_cos [0:1], y_sin [0:1];
    (* use_dsp = "yes" *) logic signed [13:0] x_sin [0:1], y_cos [0:1];

    for (genvar point = 0; point < 2; point++) begin : g_rotation
        assign x_cos[point] = x_delayed[point] * cosine_saved;
        assign y_sin[point] = y_delayed[point] * sine_saved;
        assign x_sin[point] = x_delayed[point] * sine_saved;
        assign y_cos[point] = y_delayed[point] * cosine_saved;
    end

    brief_pattern pattern (
        .pair_index(pair_index),
        .x_a(x_a), .y_a(y_a),
        .x_b(x_b), .y_b(y_b)
    );

    assign in_ready = (state == IDLE) && window_ready && !out_valid && !reset;
    assign busy = (state != IDLE) || out_valid;
    // Full-circle bin; odd quadrants reverse the magnitude-based sector index.
    assign out_angle = {quadrant_saved, angle_saved ^ {4{quadrant_saved[0]}}};
    // A match freezes the window already present before the accepting edge.
    assign window_shift = in_valid && (state != DESCRIPTOR) &&
                          !(keypoint_match && in_ready) && !reset;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= DRAIN;
            pair_index <= '0;
            pairs_issued <= 1'b0;
            valid_delayed <= '0;
            pair_delayed <= '{default:'0};
            column_count <= '0;
            window_ready <= 1'b0;
            angle_saved <= '0;
            quadrant_saved <= '0;
            sine_saved <= '0;
            cosine_saved <= '0;
            score_saved <= '0;
            out_descriptor <= '0;
            out_valid <= 1'b0;
        end else begin
            if (out_valid && out_ready)
                out_valid <= 1'b0;
            valid_delayed <= '0;

            if (window_shift) begin
                for (int row = 0; row < 37; row++) begin
                    for (int col = 0; col < 36; col++)
                        window[row][col] <= window[row][col+1];
                    window[row][36] <= in_col[row];
                end
            end

            case (state)
                IDLE: begin
                    if (window_shift && !window_ready) begin
                        if (column_count == 36) begin
                            window_ready <= 1'b1;
                            column_count <= '0;
                        end else
                            column_count <= column_count + 1'b1;
                    end

                    if (keypoint_match && in_ready) begin
                        state <= DESCRIPTOR;
                        pair_index <= '0;
                        pairs_issued <= 1'b0;
                        out_descriptor <= '0;
                        angle_saved <= in_angle;
                        quadrant_saved <= in_quadrant;
                        sine_saved <= sine;
                        cosine_saved <= cosine;
                        score_saved <= in_score;
                    end
                end

                DESCRIPTOR: begin
                    valid_delayed <= {valid_delayed[2:0], !pairs_issued};
                    pair_delayed[0] <= pair_index;
                    for (int stage = 1; stage < 4; stage++)
                        pair_delayed[stage] <= pair_delayed[stage-1];

                    // Stage 1: load the pair coordinates.
                    if (!pairs_issued) begin
                        x_delayed[0] <= x_a;
                        y_delayed[0] <= y_a;
                        x_delayed[1] <= x_b;
                        y_delayed[1] <= y_b;

                        if (pair_index == 8'd255)
                            pairs_issued <= 1'b1;
                        else
                            pair_index <= pair_index + 1'b1;
                    end

                    // Stage 2: rotate both points; remove seven fractional bits.
                    if (valid_delayed[0]) begin
                        for (int point = 0; point < 2; point++) begin
                            x_rotated[point] <= 6'((15'(x_cos[point]) - 15'(y_sin[point])) >>> 7);
                            y_rotated[point] <= 6'((15'(x_sin[point]) + 15'(y_cos[point])) >>> 7);
                        end
                    end

                    // Stage 3: select one column from every row.
                    if (valid_delayed[1]) begin
                        for (int point = 0; point < 2; point++) begin
                            row_index_delayed[point] <= 6'(int'(y_rotated[point]) + 18);
                            for (int row = 0; row < 37; row++)
                                row_pixels[point][row] <= window[row][int'(x_rotated[point]) + 18];
                        end
                    end

                    // Stage 4: select the row from the registered candidates.
                    if (valid_delayed[2]) begin
                        pixel_a <= row_pixels[0][row_index_delayed[0]];
                        pixel_b <= row_pixels[1][row_index_delayed[1]];
                    end

                    // Stage 5: equal pixels produce a zero bit.
                    if (valid_delayed[3])
                        out_descriptor[pair_delayed[3]] <= pixel_a > pixel_b;

                    if (valid_delayed[3] && pair_delayed[3] == 8'd255) begin
                        state <= DRAIN;
                        column_count <= '0;
                        window_ready <= 1'b0;
                        out_valid <= 1'b1;
                    end
                end

                DRAIN: begin
                    if (window_shift) begin
                        if (column_count == 36) begin
                            state <= IDLE;
                            column_count <= '0;
                            window_ready <= 1'b1;
                        end else
                            column_count <= column_count + 1'b1;
                    end
                end

                default: begin
                    state <= DRAIN;
                    window_ready <= 1'b0;
                    column_count <= '0;
                end
            endcase
        end
    end

endmodule
