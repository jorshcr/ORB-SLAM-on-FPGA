`timescale 1ns / 1ps

module descriptor_output #(
    parameter int ORB_STREAMS = 3,
    parameter int FIFO_DEPTH = 256
)(
    input logic clk,
    input logic reset,
    input logic [ORB_STREAMS-1:0] in_valid,
    output logic [ORB_STREAMS-1:0] in_ready,
    input logic [ORB_STREAMS-1:0][255:0] in_descriptor,
    input logic [ORB_STREAMS-1:0][18:0] in_pos,
    input logic [ORB_STREAMS-1:0][1:0] in_octave,
    input logic [ORB_STREAMS-1:0][5:0] in_angle,

    output logic out_valid,
    input logic out_ready,
    output logic [255:0] out_descriptor,
    output logic [18:0] out_pos,
    output logic [1:0] out_octave,
    output logic [5:0] out_angle,
    output logic reset_busy,
    output logic idle
);

    localparam int RECORD_W = 283;
    logic [ORB_STREAMS-1:0] pending_valid, pending_ready;
    logic [ORB_STREAMS-1:0][RECORD_W-1:0] pending_data;
    logic selected_valid, selected_ready;
    logic [RECORD_W-1:0] selected_data, fifo_data;

    // Producers hold valid and all metadata until in_ready accepts the record.
    assign in_ready = (~pending_valid | pending_ready) & {ORB_STREAMS{!reset_busy}};
    assign {out_octave, out_pos, out_angle, out_descriptor} = fifo_data;
    assign idle = !reset_busy && !(|pending_valid) && !selected_valid && !out_valid;

    always_ff @(posedge clk) begin
        if (reset) begin
            pending_valid <= '0;
        end else begin
            for (int stream = 0; stream < ORB_STREAMS; stream++) begin
                if (in_ready[stream]) begin
                    pending_valid[stream] <= in_valid[stream];
                    if (in_valid[stream])
                        pending_data[stream] <= {in_octave[stream],
                                                 in_pos[stream], in_angle[stream], in_descriptor[stream]};
                end
            end
        end
    end

    round_robin_arbiter #(.INPUTS(ORB_STREAMS), .DATA_W(RECORD_W)) arbiter (
        .clk(clk), .reset(reset),
        .in_valid(pending_valid), .in_data(pending_data), .in_ready(pending_ready),
        .out_valid(selected_valid), .out_data(selected_data), .out_ready(selected_ready)
    );

    fifo_sync #(.DATA_W(RECORD_W), .DEPTH(FIFO_DEPTH), .MEMORY_TYPE("block")) descriptor_fifo (
        .clk(clk), .reset(reset),
        .in_valid(selected_valid), .in_data(selected_data), .in_ready(selected_ready),
        .out_valid(out_valid), .out_data(fifo_data), .out_ready(out_ready),
        .reset_busy(reset_busy)
    );

endmodule
