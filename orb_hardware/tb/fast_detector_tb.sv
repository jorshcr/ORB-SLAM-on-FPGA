`timescale 1ns / 1ps

module fast_detector_tb;

    parameter W       = 640;
    parameter H       = 480;
    parameter THRESH0 = 20;
    parameter THRESH1 = 40;
    parameter GAPS    = 0;
    parameter SEED    = 1;
    parameter PARTIAL = W*3 + W/2 + 3;   // < 4 rows: produces no outputs
    parameter IMAGE   = "image.hex";
    parameter KP_OUT  = "rtl_keypoints.txt";

    reg        clk = 0;
    reg        reset = 1;
    reg  [7:0] pixel_in = 0;
    reg        pixel_valid = 0;
    reg        frame_start = 0;
    reg  [7:0] threshold = THRESH0;

    wire       out_valid, out_inside, out_keypoint;
    wire [9:0] out_x;
    wire [8:0] out_y;
    wire [7:0] out_score, out_gray;

    orb_pyramid_level #(.FRAME_WIDTH(W), .FRAME_HEIGHT(H)) dut (
        .clk(clk), .reset(reset),
        .pixel_in(pixel_in), .pixel_valid(pixel_valid),
        .frame_start(frame_start), .threshold(threshold),
        .out_valid(out_valid), .out_inside(out_inside),
        .out_x(out_x), .out_y(out_y), .out_keypoint(out_keypoint),
        .out_score(out_score), .out_gray(out_gray)
    );

    always #5 clk = ~clk;

    reg [7:0] image [0:W*H-1];
    integer   fd, errors, frame_out, exp_x, exp_y, kp_count, seed, x, y, f, g;

    initial begin
        $readmemh(IMAGE, image);
        fd = $fopen(KP_OUT, "w");
        errors = 0; frame_out = 0; exp_x = 0; exp_y = 0; kp_count = 0;
        seed = SEED;
    end

    // Output monitor: sample after the edge.
    always @(posedge clk) begin
        #1;
        if (out_valid && out_inside && frame_out < 2) begin
            if (out_x !== exp_x || out_y !== exp_y) begin
                if (errors < 10)
                    $display("ERROR: frame %0d output at (%0d,%0d), expected (%0d,%0d)",
                             frame_out, out_x, out_y, exp_x, exp_y);
                errors = errors + 1;
            end
            if (out_gray !== image[out_y*W + out_x]) begin
                if (errors < 10)
                    $display("ERROR: gray at (%0d,%0d) = %0d, expected %0d",
                             out_x, out_y, out_gray, image[out_y*W + out_x]);
                errors = errors + 1;
            end
            if (out_keypoint === 1'b1) begin
                if (out_x < 3 || out_x > W-5 || out_y < 3 || out_y > H-5) begin
                    $display("ERROR: keypoint outside valid region at (%0d,%0d)", out_x, out_y);
                    errors = errors + 1;
                end
                $fwrite(fd, "%0d %0d %0d %0d\n", frame_out, out_x, out_y, out_score);
                kp_count = kp_count + 1;
            end else if (out_keypoint !== 1'b0) begin
                $display("ERROR: out_keypoint is X at (%0d,%0d)", out_x, out_y);
                errors = errors + 1;
            end

            if (exp_x == W-5) begin
                exp_x = 0;
                if (exp_y == H-5) begin
                    exp_y = 0;
                    frame_out = frame_out + 1;
                end else
                    exp_y = exp_y + 1;
            end else
                exp_x = exp_x + 1;
        end
    end

    initial begin
        repeat (4) @(posedge clk);
        reset <= 0;
        @(posedge clk);

        for (x = 0; x < PARTIAL; x = x + 1) begin
            pixel_in    <= $random(seed);
            pixel_valid <= 1;
            frame_start <= (x == 0);
            @(posedge clk);
        end
        pixel_valid <= 0;
        frame_start <= 0;
        repeat (20) @(posedge clk);

        for (f = 0; f < 2; f = f + 1) begin
            for (y = 0; y < H; y = y + 1)
                for (x = 0; x < W; x = x + 1) begin
                    pixel_in    <= image[y*W + x];
                    pixel_valid <= 1;
                    frame_start <= (x == 0 && y == 0);
                    if (x == 0 && y == 0)
                        threshold <= (f == 0) ? THRESH0 : THRESH1;
                    @(posedge clk);
                    if (GAPS) begin
                        pixel_valid <= 0;
                        frame_start <= 0;
                        for (g = $unsigned($random(seed)) % 4; g > 0; g = g - 1)
                            @(posedge clk);
                    end
                end
        end
        pixel_valid <= 0;
        frame_start <= 0;

        // Drain the pipeline.
        repeat (50) @(posedge clk);
        $fclose(fd);

        if (frame_out != 2) begin
            $display("ERROR: %0d complete frames reported, expected 2", frame_out);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("TB PASS: coverage/order/gray checks OK, %0d keypoints written to %s",
                     kp_count, KP_OUT);
        else
            $display("TB FAIL: %0d errors", errors);
        $finish;
    end

endmodule
