`timescale 1ns / 1ps

// Vivado XPM synchronous, first-word fall-through FIFO.
// Defaults accommodate {x[9:0], y[8:0], score[7:0]} keypoint records.
// DEPTH is a power of two, >= 16; size it for the maximum producer backlog.
// reset must be synchronous to clk. Wait for reset_busy to clear before use.
// A write transfers on in_valid && in_ready at the rising edge.
// out_data is the front entry whenever out_valid is high; out_ready pops it.
// A producer must hold data/valid while blocked, or explicitly handle drops.
// FWFT does not mean zero-cycle latency from an empty FIFO's first write.
module fifo_sync #(
    parameter int unsigned DATA_W = 27,
    parameter int unsigned DEPTH = 1024,
    parameter MEMORY_TYPE = "block"
)(
    input  logic              clk,
    input  logic              reset,
    input  logic [DATA_W-1:0] in_data,
    input  logic              in_valid,
    output logic              in_ready,
    output logic [DATA_W-1:0] out_data,
    output logic              out_valid,
    input  logic              out_ready,
    output logic              reset_busy
);
    logic full, empty;
    logic wr_rst_busy, rd_rst_busy;

    assign reset_busy = reset || wr_rst_busy || rd_rst_busy;
    assign in_ready  = !reset_busy && !full;
    assign out_valid = !reset_busy && !empty;

    xpm_fifo_sync #(
        .FIFO_MEMORY_TYPE(MEMORY_TYPE),
        .FIFO_WRITE_DEPTH(DEPTH),
        .WRITE_DATA_WIDTH(DATA_W),
        .READ_DATA_WIDTH(DATA_W),
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .ECC_MODE("no_ecc"),
        .USE_ADV_FEATURES("0000"),
        .SIM_ASSERT_CHK(1),
        .DOUT_RESET_VALUE("0"),
        .FULL_RESET_VALUE(0),
        .WAKEUP_TIME(0)
    ) storage (
        .wr_clk(clk),
        .rst(reset),
        .din(in_data),
        .wr_en(in_valid && in_ready),
        .full(full),
        .wr_rst_busy(wr_rst_busy),
        .dout(out_data),
        .rd_en(out_valid && out_ready),
        .empty(empty),
        .rd_rst_busy(rd_rst_busy),
        .sleep(1'b0),
        .injectsbiterr(1'b0),
        .injectdbiterr(1'b0),
        .prog_full(), .wr_data_count(), .overflow(), .almost_full(), .wr_ack(),
        .prog_empty(), .rd_data_count(), .underflow(), .almost_empty(),
        .data_valid(), .sbiterr(), .dbiterr()
    );
endmodule
