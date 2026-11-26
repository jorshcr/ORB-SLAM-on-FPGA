`timescale 1ns / 1ps

module descriptor_udp_packetizer (
    input logic clk, reset,
    input logic in_valid,
    output logic in_ready,
    input logic [255:0] in_descriptor,
    input logic [18:0] in_pos,
    input logic [1:0] in_octave,
    input logic [5:0] in_angle,
    input logic frame_done,
    input logic [7:0] error_flags,
    output logic hdr_valid,
    input logic hdr_ready,
    output logic [15:0] udp_length,
    output logic [7:0] data,
    output logic valid,
    input logic ready,
    output logic last,
    output logic marker_overflow
);
    typedef enum logic [1:0] {IDLE, HEADER, PAYLOAD} state_t;
    state_t state;
    logic [415:0] packet;
    logic [5:0] bytes_left;
    logic [31:0] frame_number, descriptor_count;
    logic done_delayed, marker_pending;
    logic [31:0] marker_frame, marker_count;
    logic [7:0] marker_flags;
    wire done_event = frame_done && !done_delayed;

    assign in_ready = !reset && state == IDLE && !marker_pending && !done_event;
    assign hdr_valid = !reset && state == HEADER;
    assign valid = !reset && state == PAYLOAD;
    assign data = packet[415:408];
    assign last = bytes_left == 1;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            packet <= '0;
            bytes_left <= '0;
            udp_length <= '0;
            frame_number <= '0;
            descriptor_count <= '0;
            done_delayed <= 1'b0;
            marker_pending <= 1'b0;
            marker_frame <= '0;
            marker_count <= '0;
            marker_flags <= '0;
            marker_overflow <= 1'b0;
        end else begin
            done_delayed <= frame_done;
            if (done_event) begin
                if (marker_pending && state != IDLE) marker_overflow <= 1'b1;
                else begin
                    marker_pending <= 1'b1;
                    marker_frame <= frame_number;
                    marker_count <= descriptor_count;
                    marker_flags <= error_flags;
                end
                frame_number <= frame_number + 1'b1;
                descriptor_count <= '0;
            end

            case (state)
                IDLE: begin
                    if (marker_pending) begin
                        // ORB1, type, flags, record count, frame number, descriptor index/count.
                        packet <= {32'h4f524231, 8'd1, marker_flags, 16'd0,
                                   marker_frame, marker_count, 288'd0};
                        bytes_left <= 6'd16;
                        udp_length <= 16'd24;
                        marker_pending <= done_event;
                        state <= HEADER;
                    end else if (in_valid && in_ready) begin
                        packet <= {32'h4f524231, 8'd0, error_flags, 16'd1,
                                   frame_number, descriptor_count,
                                   5'd0, in_octave, in_pos, in_angle, in_descriptor};
                        descriptor_count <= descriptor_count + 1'b1;
                        bytes_left <= 6'd52;
                        udp_length <= 16'd60;
                        state <= HEADER;
                    end
                end
                HEADER: if (hdr_valid && hdr_ready) state <= PAYLOAD;
                PAYLOAD: if (valid && ready) begin
                    packet <= {packet[407:0], 8'd0};
                    bytes_left <= bytes_left - 1'b1;
                    if (last) state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
