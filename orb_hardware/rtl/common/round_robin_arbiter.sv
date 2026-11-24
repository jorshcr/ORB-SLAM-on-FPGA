`timescale 1ns / 1ps

module round_robin_arbiter #(
    parameter int INPUTS = 3,
    parameter int DATA_W = 283,
    parameter int INDEX_W = (INPUTS > 1) ? $clog2(INPUTS) : 1
)(
    input logic clk,
    input logic reset,
    input logic [INPUTS-1:0] in_valid,
    input logic [INPUTS-1:0][DATA_W-1:0] in_data,
    output logic [INPUTS-1:0] in_ready,
    output logic out_valid,
    output logic [DATA_W-1:0] out_data,
    input logic out_ready
);
    logic [INDEX_W-1:0] priority_index, held_index, selected;
    logic locked, found;

    always_comb begin
        int candidate;

        candidate = 0;
        selected = held_index;
        found = locked;
        if (!locked) begin
            for (int offset = 0; offset < INPUTS; offset++) begin
                candidate = int'(priority_index) + offset;
                if (candidate >= INPUTS) candidate = candidate - INPUTS;
                if (!found && in_valid[candidate]) begin
                    selected = INDEX_W'(candidate);
                    found = 1'b1;
                end
            end
        end

        out_valid = found && in_valid[selected] && !reset;
        out_data = out_valid ? in_data[selected] : '0;
        in_ready = '0;
        if (out_valid)
            in_ready[selected] = out_ready;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            priority_index <= '0;
            held_index <= '0;
            locked <= 1'b0;
        end else if (out_valid) begin
            if (out_ready) begin
                priority_index <= (selected == INPUTS-1) ? '0 : selected + 1'b1;
                locked <= 1'b0;
            end else begin
                // Preserve the selected result while downstream is stalled.
                held_index <= selected;
                locked <= 1'b1;
            end
        end
    end
endmodule
