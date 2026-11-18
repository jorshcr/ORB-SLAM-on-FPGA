`timescale 1ns / 1ps

// out_win[row][col]; [0][0] is oldest. Border masking belongs to the caller.
// reusable module which includes line buffers AND subsequent N x N sliding window
module line_window #(
    parameter int unsigned N      = 5,
    parameter int unsigned LINE_W = 640,
    parameter int unsigned DATA_W = 8,
    parameter int unsigned TAG_W  = 1
)(
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  in_valid,
    input  logic [DATA_W-1:0]     in_data,
    input  logic [9:0]            in_col,
    input  logic [TAG_W-1:0]      in_tag,

    output logic                   out_valid,
    output logic  [N-1:0][N-1:0][DATA_W-1:0] out_win,
    output logic  [TAG_W-1:0]      out_tag
);

    localparam int unsigned LB_W = (N-1) * DATA_W;

    (* ram_style = "block" *)
    logic [LB_W-1:0] lines [0:LINE_W-1];

    // Align input data with the BRAM read.
    logic [LB_W-1:0]   rd_q;
    logic              valid_delayed;
    logic [DATA_W-1:0] data_delayed;
    logic [9:0]        col_delayed;
    logic [TAG_W-1:0]  tag_delayed;

    // Previous rows plus the incoming pixel.
    logic [N*DATA_W-1:0] column;
    assign column = {rd_q, data_delayed};

    always_ff @(posedge clk) begin
        valid_delayed <= in_valid;
        out_valid     <= valid_delayed;
    
        if (reset) begin
            valid_delayed <= 1'b0;
            out_valid     <= 1'b0;
        end

        if (in_valid) begin
            rd_q         <= lines[in_col];
            data_delayed <= in_data;
            col_delayed  <= in_col;
            tag_delayed  <= in_tag;
        end

        if (valid_delayed) begin
            lines[col_delayed] <= column[LB_W-1:0];
            out_tag <= tag_delayed;

            for (int row = 0; row < N; row++) begin
            // last column of sliding window gets replaced from next line buffer val
                out_win[row][N-1] <= column[(N-1-row)*DATA_W +: DATA_W];
                
                for (int col = 0; col < N-1; col++) begin
                    // all other columns get shifted one to the left
                    out_win[row][col] <= out_win[row][col+1];
                end 
            end
        end
    end

endmodule
