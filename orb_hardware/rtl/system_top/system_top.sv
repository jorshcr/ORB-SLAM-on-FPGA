`timescale 1ns / 1ps

module system_top #(
    parameter int ORB_LEVELS = 1,
    parameter int FRAME_WIDTH [0:ORB_LEVELS-1] = '{default:640},
    parameter int FRAME_HEIGHT [0:ORB_LEVELS-1] = '{default:480},
    parameter int BRIEF_ENGINES = 3,
    parameter int LAST_LEVEL_BRIEF_ENGINES = BRIEF_ENGINES,
    parameter int KEYPOINT_FIFO_DEPTH = 512,
    parameter int DESCRIPTOR_FIFO_DEPTH = 256,
    parameter int CAMERA_FIFO_DEPTH = 512,
    parameter bit CAMERA_Y_FIRST = 0,
    parameter bit CAMERA_SWAP_UV = 0
)(
    input logic clk,
    input logic reset,
    input logic cam_pclk,
    input logic cam_href,
    input logic cam_vsync,
    input logic [7:0] cam_data,
    input logic [ORB_LEVELS-1:0][7:0] in_pixel,
    input logic [ORB_LEVELS-1:0] in_valid,
    input logic [ORB_LEVELS-1:0][9:0] in_x,
    input logic [ORB_LEVELS-1:0][8:0] in_y,
    input logic [ORB_LEVELS-1:0][7:0] threshold,

    output logic pixel_valid,
    output logic [7:0] pixel_gray,
    output logic [7:0] pixel_u,
    output logic [7:0] pixel_v,
    output logic [9:0] pixel_x,
    output logic [8:0] pixel_y,
    output logic pixel_frame_start,
    output logic pixel_frame_end,
    output logic camera_overflow,

    output logic out_valid,
    input logic out_ready,
    output logic [255:0] out_descriptor,
    output logic [18:0] out_pos,
    output logic [1:0] out_octave,
    output logic [5:0] out_angle,
    output logic reset_busy,
    output logic frame_done,
    output logic frame_busy,
    output logic [ORB_LEVELS-1:0] kp_overflow,
    output logic [ORB_LEVELS-1:0] brief_dropped
);

    logic [ORB_LEVELS-1:0] descriptor_valid, descriptor_ready;
    logic [ORB_LEVELS-1:0][255:0] descriptor_data;
    logic [ORB_LEVELS-1:0][18:0] descriptor_pos;
    logic [ORB_LEVELS-1:0][1:0] descriptor_octave;
    logic [ORB_LEVELS-1:0][5:0] descriptor_angle;
    logic [ORB_LEVELS-1:0] orb_processing;
    logic descriptor_idle;
    logic capture_enable;
    logic [3:0] idle_count;

    typedef enum logic [1:0] {IDLE, CAPTURE, DRAIN} frame_state_t;
    frame_state_t frame_state;

    assign capture_enable = frame_state == IDLE;
    assign frame_busy = frame_state != IDLE;

    camera_capture_top #(
        .FRAME_WIDTH(FRAME_WIDTH[0]), .FRAME_HEIGHT(FRAME_HEIGHT[0]),
        .FIFO_DEPTH(CAMERA_FIFO_DEPTH),
        .Y_FIRST(CAMERA_Y_FIRST), .SWAP_UV(CAMERA_SWAP_UV)
    ) camera (
        .clk(clk), .reset(reset), .cam_pclk(cam_pclk),
        .cam_href(cam_href), .cam_vsync(cam_vsync), .cam_data(cam_data),
        .capture_enable(capture_enable),
        .out_valid(pixel_valid), .out_gray(pixel_gray), .out_u(pixel_u), .out_v(pixel_v),
        .out_x(pixel_x), .out_y(pixel_y),
        .out_frame_start(pixel_frame_start), .out_frame_end(pixel_frame_end),
        .overflow(camera_overflow)
    );

    for (genvar level = 0; level < ORB_LEVELS; level++) begin : g_orb
        assign descriptor_octave[level] = 2'(level);

        orb_pyramid_level #(
            .FRAME_WIDTH(FRAME_WIDTH[level]), .FRAME_HEIGHT(FRAME_HEIGHT[level]),
            .BRIEF_ENGINES(level == ORB_LEVELS-1 ? LAST_LEVEL_BRIEF_ENGINES : BRIEF_ENGINES),
            .KEYPOINT_FIFO_DEPTH(KEYPOINT_FIFO_DEPTH)
        ) orb (
            .clk(clk), .reset(reset),
            .in_pixel(level == 0 ? pixel_gray : in_pixel[level]),
            .in_valid(level == 0 ? pixel_valid : in_valid[level]),
            .in_x(level == 0 ? pixel_x : in_x[level]),
            .in_y(level == 0 ? pixel_y : in_y[level]), .threshold(threshold[level]),
            .kp_overflow(kp_overflow[level]), .brief_dropped(brief_dropped[level]),
            .descriptor_valid(descriptor_valid[level]), .descriptor_ready(descriptor_ready[level]),
            .descriptor_data(descriptor_data[level]), .descriptor_pos(descriptor_pos[level]),
            .descriptor_angle(descriptor_angle[level]), .descriptor_score(),
            .brief_valid(), .brief_descriptor(), .brief_pos(), .brief_score(), .brief_angle(),
            .processing(orb_processing[level])
        );
    end

    descriptor_output #(.ORB_STREAMS(ORB_LEVELS), .FIFO_DEPTH(DESCRIPTOR_FIFO_DEPTH)) results (
        .clk(clk), .reset(reset),
        .in_valid(descriptor_valid), .in_ready(descriptor_ready),
        .in_descriptor(descriptor_data), .in_pos(descriptor_pos),
        .in_octave(descriptor_octave),
        .in_angle(descriptor_angle),
        .out_valid(out_valid), .out_ready(out_ready), .out_descriptor(out_descriptor),
        .out_pos(out_pos), .out_octave(out_octave),
        .out_angle(out_angle),
        .reset_busy(reset_busy), .idle(descriptor_idle)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            frame_state <= IDLE;
            frame_done <= 1'b0;
            idle_count <= '0;
        end else begin
            case (frame_state)
                IDLE: begin
                    idle_count <= '0;
                    if (pixel_frame_start) begin
                        frame_state <= CAPTURE;
                        frame_done <= 1'b0;
                    end
                end

                CAPTURE: begin
                    if (pixel_frame_end) begin
                        frame_state <= DRAIN;
                        idle_count <= '0;
                    end
                end

                DRAIN: begin
                    if (!(|orb_processing) && descriptor_idle) begin
                        if (idle_count == 4'd15) begin
                            frame_state <= IDLE;
                            frame_done <= 1'b1;
                        end else begin
                            idle_count <= idle_count + 1'b1;
                        end
                    end else begin
                        idle_count <= '0;
                    end
                end

                default: frame_state <= IDLE;
            endcase
        end
    end

endmodule
