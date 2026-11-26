`timescale 1ns / 1ps

module descriptor_output_tb;
    parameter int STREAMS = 3;
    parameter int DEPTH = 16;
    logic clk = 0, reset = 1;
    always #5 clk = ~clk;

    logic [STREAMS-1:0] in_valid = '0, in_ready;
    logic [STREAMS-1:0][255:0] in_descriptor = '0;
    logic [STREAMS-1:0][18:0] in_pos = '0;
    logic [STREAMS-1:0][1:0] in_octave = '0;
    logic [STREAMS-1:0][5:0] in_angle = '0;
    logic out_valid, out_ready = 0, reset_busy, idle;
    logic [255:0] out_descriptor;
    logic [18:0] out_pos;
    logic [1:0] out_octave;
    logic [5:0] out_angle;
    int sent [0:STREAMS-1], received [0:STREAMS-1];
    int epoch = 0, total = 0, blocked = 0;
    logic was_stalled = 0;
    logic [282:0] held_record;
    wire [282:0] output_record = {out_octave, out_pos, out_angle, out_descriptor};

    descriptor_output #(.ORB_STREAMS(STREAMS), .FIFO_DEPTH(DEPTH)) dut (.*);

    function automatic [282:0] record_for(input int stream, number, generation);
        logic [31:0] payload;
        payload = 32'(number) ^ (32'(stream) << 16) ^ (32'(generation) << 24);
        return {2'(stream), 19'(number*3+stream),
                6'(number+stream*17+generation), {8{payload}}};
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            sent = '{default:0};
            received = '{default:0};
            total = 0;
            blocked = 0;
            was_stalled = 0;
        end else begin
            if (reset_busy && (|in_ready || out_valid))
                $fatal(1, "Transfer permitted during FIFO reset recovery");
            if (was_stalled && (!out_valid || output_record !== held_record))
                $fatal(1, "Output changed while stalled");
            was_stalled = out_valid && !out_ready;
            held_record = output_record;
            for (int stream = 0; stream < STREAMS; stream++) begin
                if (in_valid[stream] && in_ready[stream]) sent[stream]++;
                if (in_valid[stream] && !in_ready[stream] && !reset_busy) blocked++;
            end
            if (out_valid && out_ready) begin
                if (int'(out_octave) >= STREAMS) $fatal(1, "Invalid octave");
                if (received[out_octave] >= sent[out_octave]) $fatal(1, "Unexpected/duplicate result");
                if (output_record !== record_for(int'(out_octave), received[out_octave], epoch))
                    $fatal(1, "Data, angle, octave, position or per-stream ordering mismatch");
                if (total < STREAMS*4 && int'(out_octave) != total%STREAMS)
                    $fatal(1, "Round-robin fairness mismatch");
                received[out_octave]++;
                total++;
            end
        end
    end

    task automatic run_batch(input int budget, clocks, consume);
        for (int cycle = 0; cycle < clocks; cycle++) begin
            @(negedge clk);
            out_ready = consume && cycle > DEPTH+50 && cycle%7 != 0 && cycle%11 != 0;
            for (int stream = 0; stream < STREAMS; stream++) begin
                in_valid[stream] = sent[stream] < budget;
                {in_octave[stream], in_pos[stream], in_angle[stream], in_descriptor[stream]} =
                    record_for(stream, sent[stream], epoch);
            end
        end
    endtask

    initial begin
        repeat (6) @(negedge clk);
        reset = 0;
        // Fill and stall, then reset with buffered records still pending.
        run_batch(DEPTH+32, DEPTH+100, 0);
        @(negedge clk);
        if (blocked == 0 || !out_valid) $fatal(1, "FIFO-full scenario not exercised");
        reset = 1;
        in_valid = '0;
        epoch = 1;
        repeat (6) @(negedge clk);
        reset = 0;
        run_batch(DEPTH+32, (DEPTH+32)*STREAMS*3+DEPTH+100, 1);
        @(negedge clk);
        in_valid = '0;
        out_ready = 1;
        repeat (30) @(negedge clk);
        for (int stream = 0; stream < STREAMS; stream++)
            if (sent[stream] != DEPTH+32 || received[stream] != DEPTH+32)
                $fatal(1, "Missing records for stream %0d", stream);
        if (out_valid || blocked == 0) $fatal(1, "Drain or backpressure check failed");
        $display("PASS: descriptor_output streams=%0d depth=%0d records=%0d; fairness, full, stalls, metadata and reset", STREAMS, DEPTH, total);
        $finish;
    end

    initial begin #1000000; $fatal(1, "Timeout"); end
endmodule
