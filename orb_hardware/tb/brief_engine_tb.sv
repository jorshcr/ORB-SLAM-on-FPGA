`timescale 1ns / 1ps
module brief_engine_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic reset = 1, in_valid = 0, keypoint_match = 0;
    logic [36:0][5:0] in_col = '0;
    logic signed [7:0] sine = 0, cosine = 127;
    wire busy, out_valid;
    wire in_ready = !busy && !reset;
    wire [255:0] out_descriptor;
    logic [7:0] ref_index;
    wire signed [5:0] xa, ya, xb, yb;
    logic [255:0] expected;
    int patch [0:36][0:36];
    int ax, ay, bx, by, cycles;

    brief_engine dut (
        .clk(clk), .reset(reset), .in_col(in_col), .in_angle(4'd0),
        .in_quadrant(2'd0), .sine(sine), .cosine(cosine), .in_score(8'd20),
        .in_valid(in_valid), .keypoint_match(keypoint_match), .busy(busy),
        .out_descriptor(out_descriptor), .out_valid(out_valid)
    );
    brief_pattern reference_pattern (.pair_index(ref_index),
        .x_a(xa), .y_a(ya), .x_b(xb), .y_b(yb));

    task automatic tick;
        @(posedge clk); #1;
        @(negedge clk);
    endtask

    initial begin
        tick(); reset = 0;
        for (int test_id = 0; test_id < 5; test_id++) begin
            for (int col = 0; col < 37; col++) begin
                if (in_ready) $fatal(1, "Ready before refill completed");
                in_valid = 0; tick();
                in_valid = 1;
                for (int row = 0; row < 37; row++) begin
                    patch[row][col] = test_id == 4 ? 23 : (row*17 + col*11 + row*col + test_id) % 64;
                    in_col[row] = 6'(patch[row][col]);
                end
                tick();
            end
            if (!in_ready) $fatal(1, "Not ready after 37 columns");
            in_valid = 0;
            case (test_id)
                0: begin sine = 0; cosine = 127; end
                1: begin sine = 90; cosine = -90; end
                2: begin sine = -90; cosine = -90; end
                3: begin sine = -128; cosine = 0; end
                4: begin sine = 90; cosine = 90; end
            endcase
            for (int pair_id = 0; pair_id < 256; pair_id++) begin
                ref_index = 8'(pair_id); #1;
                ax = (int'(xa)*int'(cosine) - int'(ya)*int'(sine)) >>> 7;
                ay = (int'(xa)*int'(sine) + int'(ya)*int'(cosine)) >>> 7;
                bx = (int'(xb)*int'(cosine) - int'(yb)*int'(sine)) >>> 7;
                by = (int'(xb)*int'(sine) + int'(yb)*int'(cosine)) >>> 7;
                if (ax < -18 || ax > 18 || ay < -18 || ay > 18 ||
                    bx < -18 || bx > 18 || by < -18 || by > 18)
                    $fatal(1, "Rotated coordinate outside patch");
                expected[pair_id] = patch[ay+18][ax+18] > patch[by+18][bx+18];
            end
            @(negedge clk);
            keypoint_match = 1; in_valid = 1; in_col = '1;
            tick(); keypoint_match = 0;
            sine = 0; cosine = 0;
            cycles = 0;
            while (!out_valid && cycles < 260) begin
                if (in_ready) $fatal(1, "Ready during descriptor");
                tick(); cycles++;
            end
            if (cycles != 259 || !out_valid) $fatal(1, "Wrong completion cycle %0d", cycles);
            if (out_descriptor !== expected) $fatal(1, "Descriptor mismatch case %0d", test_id);
            in_valid = 0; tick();
            if (out_valid) $fatal(1, "Valid must pulse");
        end
        reset = 1; tick();
        if (in_ready || out_valid) $fatal(1, "Reset failed");
        $display("PASS: brief_engine, 5 descriptors / 1280 bits, latency, freeze and refill");
        $finish;
    end
    initial begin #100000; $fatal(1, "Timeout"); end
endmodule
