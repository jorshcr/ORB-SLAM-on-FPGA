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
    logic [2:0] valid_delayed;
    logic [7:0] pair_delayed [0:2];
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
    logic [5:0] pixel_a, pixel_b;

    brief_pattern pattern (
        .pair_index(pair_index),
        .x_a(x_a), .y_a(y_a),
        .x_b(x_b), .y_b(y_b)
    );

    assign in_ready = (state == IDLE) && window_ready && !out_valid && !reset;
    assign busy = (state != IDLE) || out_valid;
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
                    valid_delayed <= {valid_delayed[1:0], !pairs_issued};
                    pair_delayed[0] <= pair_index;
                    for (int stage = 1; stage < 3; stage++)
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
                        x_rotated[0] <= 6'((15'(x_delayed[0]) * cosine_saved - 15'(y_delayed[0]) * sine_saved) >>> 7);
                        y_rotated[0] <= 6'((15'(x_delayed[0]) * sine_saved + 15'(y_delayed[0]) * cosine_saved) >>> 7);
                        x_rotated[1] <= 6'((15'(x_delayed[1]) * cosine_saved - 15'(y_delayed[1]) * sine_saved) >>> 7);
                        y_rotated[1] <= 6'((15'(x_delayed[1]) * sine_saved + 15'(y_delayed[1]) * cosine_saved) >>> 7);
                    end

                    // Stage 3: convert centered offsets to window indices.
                    if (valid_delayed[1]) begin
                        pixel_a <= window[int'(y_rotated[0]) + 18][int'(x_rotated[0]) + 18];
                        pixel_b <= window[int'(y_rotated[1]) + 18][int'(x_rotated[1]) + 18];
                    end

                    // Stage 4: equal pixels produce a zero bit.
                    if (valid_delayed[2])
                        out_descriptor[pair_delayed[2]] <= pixel_a > pixel_b;

                    if (valid_delayed[2] && pair_delayed[2] == 8'd255) begin
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
