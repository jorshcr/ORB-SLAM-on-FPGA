`timescale 1ns / 1ps

module camera_capture_top #(
    parameter int FRAME_WIDTH = 640,
    parameter int FRAME_HEIGHT = 480,
    parameter int FIFO_DEPTH = 512,
    parameter bit Y_FIRST = 0,
    parameter bit SWAP_UV = 0
)(
    input logic clk,
    input logic reset,
    input logic cam_pclk,
    input logic cam_href,
    input logic cam_vsync,
    input logic [7:0] cam_data,
    output logic out_valid,
    output logic [7:0] out_gray,
    output logic [7:0] out_u,
    output logic [7:0] out_v,
    output logic [9:0] out_x,
    output logic [8:0] out_y,
    output logic [2:0] out_frame_id,
    output logic out_frame_start,
    output logic out_frame_end,
    output logic overflow
);

    (* ASYNC_REG = "TRUE" *) logic [2:0] reset_camera = '1;
    (* ASYNC_REG = "TRUE" *) logic [1:0] overflow_sync;
    (* IOB = "TRUE" *) logic [7:0] cam_data_delayed;
    (* IOB = "TRUE" *) logic cam_href_delayed, cam_vsync_delayed;
    logic [1:0] byte_phase;
    logic [23:0] bytes_saved;
    logic frame_pending, line_pending, href_delayed, capture_active;
    logic overflow_camera;
    logic [33:0] fifo_in, fifo_out;
    logic fifo_full, fifo_empty, wr_busy, rd_busy, fifo_write, fifo_read;
    logic second_pixel, frame_active, seen_frame;
    logic [7:0] second_gray;
    logic [9:0] next_x;
    logic [8:0] next_y;
    logic [31:0] pair_data;
    logic [7:0] first_y, second_y, first_chroma, second_chroma;

    // Default byte order is U,Y0,V,Y1; U/V are shared by both pixels.
    assign fifo_in = {frame_pending, line_pending, bytes_saved, cam_data_delayed};
    assign fifo_write = capture_active && cam_href_delayed && !cam_vsync_delayed &&
                        byte_phase == 3 && !fifo_full && !wr_busy && !reset_camera[2];
    assign fifo_read = !fifo_empty && !rd_busy && !reset && !second_pixel;
    assign pair_data = fifo_out[31:0];
    assign first_y = Y_FIRST ? pair_data[31:24] : pair_data[23:16];
    assign second_y = Y_FIRST ? pair_data[15:8] : pair_data[7:0];
    assign first_chroma = Y_FIRST ? pair_data[23:16] : pair_data[31:24];
    assign second_chroma = Y_FIRST ? pair_data[7:0] : pair_data[15:8];
    assign overflow = overflow_sync[1];

    always_ff @(posedge cam_pclk or posedge reset) begin
        if (reset)
            reset_camera <= '1;
        else
            reset_camera <= {reset_camera[1:0], 1'b0};
    end

    always_ff @(posedge cam_pclk) begin
        cam_data_delayed <= cam_data;
        cam_href_delayed <= cam_href;
        cam_vsync_delayed <= cam_vsync;

        if (reset_camera[2]) begin
            byte_phase <= 0;
            bytes_saved <= 0;
            frame_pending <= 0;
            line_pending <= 0;
            href_delayed <= 0;
            capture_active <= 0;
            overflow_camera <= 0;
        end else begin
            href_delayed <= cam_href_delayed;

            if (cam_vsync_delayed) begin
                byte_phase <= 0;
                frame_pending <= 1;
                line_pending <= 1;
                capture_active <= 1;
            end else if (!cam_href_delayed) begin
                byte_phase <= 0;
                line_pending <= 1;
            end else begin
                byte_phase <= byte_phase + 1'b1;
                bytes_saved <= {bytes_saved[15:0], cam_data_delayed};
                if (!href_delayed)
                    line_pending <= 1;

                if (fifo_write) begin
                    frame_pending <= 0;
                    line_pending <= 0;
                end

                // Drop the rest of an overflowing frame; restart at the next VSYNC.
                if (capture_active && byte_phase == 3 && (fifo_full || wr_busy)) begin
                    capture_active <= 0;
                    overflow_camera <= 1;
                end
            end
        end
    end

    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE("block"), .FIFO_WRITE_DEPTH(FIFO_DEPTH),
        .WRITE_DATA_WIDTH(34), .READ_DATA_WIDTH(34),
        .READ_MODE("fwft"), .FIFO_READ_LATENCY(0), .CDC_SYNC_STAGES(2),
        .ECC_MODE("no_ecc"), .USE_ADV_FEATURES("0000"), .SIM_ASSERT_CHK(1)
    ) camera_fifo (
        .rst(reset_camera[2]), .wr_clk(cam_pclk), .rd_clk(clk),
        .din(fifo_in), .wr_en(fifo_write), .full(fifo_full), .wr_rst_busy(wr_busy),
        .dout(fifo_out), .rd_en(fifo_read), .empty(fifo_empty), .rd_rst_busy(rd_busy),
        .sleep(1'b0), .injectsbiterr(1'b0), .injectdbiterr(1'b0),
        .prog_full(), .wr_data_count(), .overflow(), .almost_full(), .wr_ack(),
        .prog_empty(), .rd_data_count(), .underflow(), .almost_empty(),
        .data_valid(), .sbiterr(), .dbiterr()
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            overflow_sync <= 0;
            second_pixel <= 0;
            second_gray <= 0;
            frame_active <= 0;
            seen_frame <= 0;
            next_x <= 0;
            next_y <= 0;
            out_valid <= 0;
            out_gray <= 0;
            out_u <= 0;
            out_v <= 0;
            out_x <= 0;
            out_y <= 0;
            out_frame_id <= 0;
            out_frame_start <= 0;
            out_frame_end <= 0;
        end else begin
            overflow_sync <= {overflow_sync[0], overflow_camera};
            out_valid <= 0;
            out_frame_start <= 0;
            out_frame_end <= 0;

            if (second_pixel) begin
                second_pixel <= 0;
                out_valid <= 1;
                out_gray <= second_gray;
                out_x <= next_x;
                out_y <= next_y;
                out_frame_end <= next_x == FRAME_WIDTH-1 && next_y == FRAME_HEIGHT-1;
                if (next_x == FRAME_WIDTH-1) begin
                    next_x <= 0;
                    next_y <= next_y + 1'b1;
                    if (next_y == FRAME_HEIGHT-1)
                        frame_active <= 0;
                end else begin
                    next_x <= next_x + 1'b1;
                end
            end else if (fifo_read && (frame_active || fifo_out[33])) begin
                out_valid <= 1;
                out_gray <= first_y;
                out_u <= SWAP_UV ? second_chroma : first_chroma;
                out_v <= SWAP_UV ? first_chroma : second_chroma;
                second_gray <= second_y;
                second_pixel <= 1;
                out_x <= fifo_out[32] ? 10'd0 : next_x;
                out_y <= fifo_out[33] ? 9'd0 : next_y;
                next_x <= fifo_out[32] ? 10'd1 : next_x + 1'b1;
                if (fifo_out[33]) begin
                    next_y <= 0;
                    frame_active <= 1;
                    seen_frame <= 1;
                    out_frame_id <= seen_frame ? out_frame_id + 1'b1 : 3'd0;
                    out_frame_start <= 1;
                end
            end
        end
    end

endmodule
