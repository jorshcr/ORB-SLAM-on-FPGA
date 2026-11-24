`timescale 1ns / 1ps
module round_robin_arbiter_tb;
    logic clk = 0, reset = 1;
    always #5 clk = ~clk;
    logic [2:0] in_valid = 0, in_ready;
    logic [2:0][282:0] in_data = '0;
    logic out_valid, out_ready = 0;
    logic [282:0] out_data;
    int pointer = 0, held = -1, winner, transfers = 0;
    int counts [0:2] = '{default:0};
    round_robin_arbiter dut (.*);

    always @(posedge clk) begin
        if (reset) begin
            pointer = 0;
            held = -1;
            if (out_valid || in_ready) $fatal(1, "Transfer during reset");
        end else begin
            winner = held;
            for (int offset = 0; offset < 3; offset++)
                if (winner < 0 && in_valid[(pointer+offset)%3]) winner = (pointer+offset)%3;
            if (out_valid !== (winner >= 0)) $fatal(1, "Valid mismatch");
            if (winner >= 0) begin
                if (out_data !== in_data[winner]) $fatal(1, "Wrong or unstable selection");
                if (in_ready !== (out_ready ? (3'b001 << winner) : 3'b000))
                    $fatal(1, "Ready not one-hot");
                if (out_ready) begin
                    pointer = (winner+1)%3;
                    held = -1;
                    transfers++;
                    counts[winner]++;
                end else held = winner;
            end else if (in_ready) $fatal(1, "Ready without request");
        end
    end

    initial begin
        repeat (2) @(negedge clk);
        reset = 0;
        // A later higher-priority arrival must not replace a stalled winner.
        in_valid = 3'b100; in_data[2] = 283'h123;
        @(negedge clk); in_valid = 3'b111;
        in_data[0] = 283'h456; in_data[1] = 283'h789;
        repeat (4) @(negedge clk);
        out_ready = 1;
        repeat (30) @(negedge clk);
        if (counts[0] != 10 || counts[1] != 10 || counts[2] != 10)
            $fatal(1, "Unfair saturated arbitration");
        for (int cycle = 0; cycle < 500; cycle++) begin
            // Keep pending source records stable until accepted.
            for (int i = 0; i < 3; i++) begin
                if (!in_valid[i] || in_ready[i]) begin
                    in_valid[i] = ($urandom_range(0,3) != 0);
                    in_data[i] = {in_data[i][250:0], $urandom};
                end
            end
            out_ready = ($urandom_range(0,3) != 0);
            @(negedge clk);
        end
        out_ready = 0;
        @(negedge clk); reset = 1;
        @(negedge clk); reset = 0; in_valid = 0;
        @(negedge clk);
        $display("PASS: round robin, %0d transfers, fairness, stalls, late arrivals, reset", transfers);
        $finish;
    end
    initial begin #10000; $fatal(1, "Timeout"); end
endmodule
