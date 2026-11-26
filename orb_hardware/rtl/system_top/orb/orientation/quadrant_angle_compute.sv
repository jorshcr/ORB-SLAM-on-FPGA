`timescale 1ns / 1ps

module quadrant_angle_compute #(
    parameter int unsigned TAG_W = 19
)(
    input logic clk,
    input logic reset,
    input logic signed [21:0] m10,
    input logic signed [21:0] m01,
    input logic in_valid,
    input logic [TAG_W-1:0] in_tag,

    output logic [1:0] out_quadrant,
    output logic [3:0] out_sector,  // Index from abs(m01)/abs(m10); quadrant supplies signs.
    output logic out_valid,
    output logic [TAG_W-1:0] out_tag
);
    logic [21:0] abs_moment_x, abs_moment_y;
    logic abs_valid, tan_valid, comparison_valid;
    logic [14:0][34:0] tan_products;
    logic [34:0] scaled_y;
    logic [14:0] comparisons;
    logic [1:0] quadrant_pipe [0:2];
    logic [TAG_W-1:0] tag_pipe [0:2];

    // Stage 2: fifteen parallel products with eight fractional bits.
    tan_multiply tangent_products (
        .clk(clk), .reset(reset),
        .abs_moment_x(abs_moment_x), .in_valid(abs_valid),
        .products(tan_products), .out_valid(tan_valid)
    );

    always_ff @(posedge clk) begin
        logic [3:0] selected_sector;

        if (reset) begin
            abs_moment_x <= '0;
            abs_moment_y <= '0;
            abs_valid <= 1'b0;
            scaled_y <= '0;
            comparisons <= '0;
            comparison_valid <= 1'b0;
            quadrant_pipe <= '{default:'0};
            tag_pipe <= '{default:'0};
            out_quadrant <= '0;
            out_sector <= '0;
            out_valid <= 1'b0;
            out_tag <= '0;
        end else begin
            abs_valid <= in_valid;
            comparison_valid <= tan_valid;
            out_valid <= comparison_valid;

            // Stage 1: magnitudes and quadrant (0=++, 1=-+, 2=--, 3=+-).
            if (in_valid) begin
                abs_moment_x <= m10[21] ? (~$unsigned(m10) + 22'd1) : $unsigned(m10);
                abs_moment_y <= m01[21] ? (~$unsigned(m01) + 22'd1) : $unsigned(m01);
                if (m01 < 0)
                    quadrant_pipe[0] <= (m10 < 0) ? 2'd2 : 2'd3;
                else
                    quadrant_pipe[0] <= (m10 < 0) ? 2'd1 : 2'd0;
                tag_pipe[0] <= in_tag;
            end

            // Stage 2 metadata follows the multiplier.
            if (abs_valid) begin
                scaled_y <= {5'b0, abs_moment_y, 8'b0};
                quadrant_pipe[1] <= quadrant_pipe[0];
                tag_pipe[1] <= tag_pipe[0];
            end

            // Stage 3: equality selects the higher threshold; zero moments fall back to zero.
            if (tan_valid) begin
                for (int k = 0; k < 15; k++)
                    comparisons[k] <= (scaled_y != 0) && (tan_products[k] <= scaled_y);
                quadrant_pipe[2] <= quadrant_pipe[1];
                tag_pipe[2] <= tag_pipe[1];
            end

            // Stage 4: ascending overwrite gives the highest set bit priority.
            if (comparison_valid) begin
                selected_sector = '0;
                for (int k = 0; k < 15; k++)
                    if (comparisons[k]) selected_sector = 4'(k + 1);

                out_quadrant <= quadrant_pipe[2];
                out_sector <= selected_sector;
                out_tag <= tag_pipe[2];
            end
        end
    end

endmodule
