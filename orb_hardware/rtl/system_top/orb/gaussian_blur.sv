`timescale 1ns / 1ps

module gaussian_blur (
    input  logic clk,
    input  logic reset,
    input  logic [6:0][6:0][7:0] win,
    input  logic win_valid,
    input  logic [9:0] in_x,
    input  logic [8:0] in_y,

    output logic out_valid,
    output logic [9:0] out_x,
    output logic [8:0] out_y,
    output logic [7:0] out_gray
);

    localparam int LAT = 8;
    localparam int unsigned WEIGHT [0:3] = '{1, 6, 15, 20};

    logic [8:0] row_pair [0:6][0:3];
    logic [13:0] row_weighted [0:6][0:3];
    logic [13:0] row_partial [0:6][0:1];
    logic [13:0] row_sum [0:6];
    logic [14:0] col_pair [0:3];
    logic [19:0] col_weighted [0:3];
    logic [19:0] col_partial [0:1];
    logic [19:0] total;

    logic [LAT-1:0] valid_pipe;
    logic [9:0] x_pipe [0:LAT-1];
    logic [8:0] y_pipe [0:LAT-1];

    always_ff @(posedge clk) begin
        // Stages 1-4: horizontal convolution.
        for (int row = 0; row < 7; row++) begin
            for (int col = 0; col < 3; col++)
                row_pair[row][col] <= {1'b0, win[row][col]} + {1'b0, win[row][6-col]};

            row_pair[row][3] <= {1'b0, win[row][3]};

            for (int col = 0; col < 4; col++)
                row_weighted[row][col] <= 14'(row_pair[row][col] * WEIGHT[col]);

            row_partial[row][0] <= row_weighted[row][0] + row_weighted[row][1];
            row_partial[row][1] <= row_weighted[row][2] + row_weighted[row][3];
            row_sum[row] <= row_partial[row][0] + row_partial[row][1];
        end

        // Stages 5-8: vertical convolution.
        for (int row = 0; row < 3; row++)
            col_pair[row] <= {1'b0, row_sum[row]} + {1'b0, row_sum[6-row]};

        col_pair[3] <= {1'b0, row_sum[3]};

        for (int row = 0; row < 4; row++)
            col_weighted[row] <= 20'(col_pair[row] * WEIGHT[row]);

        col_partial[0] <= col_weighted[0] + col_weighted[1];
        col_partial[1] <= col_weighted[2] + col_weighted[3];
        total <= col_partial[0] + col_partial[1];

        x_pipe[0] <= in_x;
        y_pipe[0] <= in_y;
        for (int stage = 1; stage < LAT; stage++) begin
            x_pipe[stage] <= x_pipe[stage-1];
            y_pipe[stage] <= y_pipe[stage-1];
        end

        if (reset)
            valid_pipe <= '0;
        else
            valid_pipe <= {valid_pipe[LAT-2:0], win_valid};
    end

    // Coordinates pass through unchanged; normalization truncates.
    assign out_valid = valid_pipe[LAT-1];
    assign out_x = x_pipe[LAT-1];
    assign out_y = y_pipe[LAT-1];
    assign out_gray = total[19:12];

endmodule
