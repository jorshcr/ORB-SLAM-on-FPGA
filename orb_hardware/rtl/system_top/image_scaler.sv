`timescale 1ns / 1ps

module image_scaler #(
    parameter int unsigned FRAME_WIDTH = 640,
    parameter int unsigned FRAME_HEIGHT = 480,
    parameter DSP_MODE = "yes"
)(
    input logic clk,
    input logic reset,
    input logic [7:0] in_gray,
    input logic [9:0] in_x,
    input logic [8:0] in_y,
    input logic in_valid,

    (* use_dsp = "no" *) output logic [7:0] out_gray,
    output logic [9:0] out_x,
    output logic [8:0] out_y,
    output logic out_valid
);
    localparam int OUT_WIDTH = FRAME_WIDTH * 5 / 6;
    localparam int OUT_HEIGHT = FRAME_HEIGHT * 5 / 6;
    localparam int LAT = 7;

    (* ram_style = "block" *) logic [7:0] line_buffer [0:FRAME_WIDTH-1];
    logic [7:0] row_delayed, data_delayed;
    logic [9:0] x_delayed, window_x;
    logic [8:0] y_delayed, window_y;
    logic [1:0][1:0][7:0] window;
    logic [7:0] pixels [0:3];
    (* use_dsp = "no" *) logic [4:0] weights [0:3];
    logic [3:0][12:0] products, product_next;
    (* use_dsp = "no" *) logic [13:0] pairs [0:1];
    (* use_dsp = "no" *) logic [14:0] total;
    logic [LAT-1:0] valid_pipe;
    logic [9:0] x_pipe [0:4];
    logic [8:0] y_pipe [0:4];
    logic [2:0] phase_x, phase_y, right_weight, bottom_weight;
    (* use_dsp = "no" *) logic [9:0] scaled_x;
    (* use_dsp = "no" *) logic [8:0] scaled_y;
    logic sample_valid;

    // Output (x,y) samples input (6*x/5,6*y/5); phase 1 is skipped.
    assign phase_x = window_x % 6;
    assign phase_y = window_y % 6;
    assign right_weight = (phase_x == 0) ? 3'd5 : phase_x - 3'd1;
    assign bottom_weight = (phase_y == 0) ? 3'd5 : phase_y - 3'd1;
    assign scaled_x = (window_x / 6) * 5 + ((phase_x == 0) ? 0 : phase_x - 1);
    assign scaled_y = (window_y / 6) * 5 + ((phase_y == 0) ? 0 : phase_y - 1);
    assign sample_valid = (phase_x != 1) && (phase_y != 1) &&
                          (scaled_x < OUT_WIDTH) && (scaled_y < OUT_HEIGHT);

    assign out_valid = valid_pipe[LAT-1];
    assign out_x = x_pipe[4];
    assign out_y = y_pipe[4];

    for (genvar i = 0; i < 4; i++) begin : g_product
        if (DSP_MODE == "yes") begin : g_dsp
            (* use_dsp = "yes" *) wire [12:0] value = pixels[i] * weights[i];
            assign product_next[i] = value;
        end else begin : g_lut
            (* use_dsp = "no" *) wire [12:0] value = pixels[i] * weights[i];
            assign product_next[i] = value;
        end
    end

    always_ff @(posedge clk) begin
        if (in_valid) begin
            row_delayed <= line_buffer[in_x];
            line_buffer[in_x] <= in_gray;
            data_delayed <= in_gray;
            x_delayed <= in_x;
            y_delayed <= in_y;
        end

        if (valid_pipe[0]) begin
            window[0][0] <= (x_delayed == 0) ? row_delayed : window[0][1];
            window[0][1] <= row_delayed;
            window[1][0] <= (x_delayed == 0) ? data_delayed : window[1][1];
            window[1][1] <= data_delayed;
            window_x <= x_delayed;
            window_y <= y_delayed;
        end

        // Register operands, multiply, pair sum, total, then normalize.
        pixels[0] <= (window_y == 0) ? window[1][0] : window[0][0];
        pixels[1] <= (window_y == 0) ? window[1][1] : window[0][1];
        pixels[2] <= window[1][0];
        pixels[3] <= window[1][1];
        weights[0] <= (5 - right_weight) * (5 - bottom_weight);
        weights[1] <= right_weight * (5 - bottom_weight);
        weights[2] <= (5 - right_weight) * bottom_weight;
        weights[3] <= right_weight * bottom_weight;

        products <= product_next;

        pairs[0] <= {1'b0, products[0]} + {1'b0, products[1]};
        pairs[1] <= {1'b0, products[2]} + {1'b0, products[3]};
        total <= {1'b0, pairs[0]} + {1'b0, pairs[1]};
        out_gray <= total / 25;

        x_pipe[0] <= scaled_x;
        y_pipe[0] <= scaled_y;
        for (int i = 1; i < 5; i++) begin
            x_pipe[i] <= x_pipe[i-1];
            y_pipe[i] <= y_pipe[i-1];
        end

        if (reset)
            valid_pipe <= '0;
        else begin
            valid_pipe <= {valid_pipe[LAT-2:0], in_valid};
            valid_pipe[2] <= valid_pipe[1] && sample_valid;
        end
    end

endmodule
