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
    parameter BLUR_REF = "";
    parameter ANGLE_REF = "";

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

    logic  [9:0] col_count;
    logic  [8:0] row_count;
    logic [9:0] col;
    assign col = frame_start ? 10'd0 : col_count;
    logic [8:0] row;
    assign row = frame_start ? 9'd0  : row_count;

    always_ff @(posedge clk) begin
        if (reset) begin
            col_count <= 0;
            row_count <= 0;
        end else if (pixel_valid) begin
            if (col == W - 1) begin
                col_count <= 0;
                row_count <= (row == H - 1) ? 9'd0 : row + 1'b1;
            end else begin
                col_count <= col + 1'b1;
                row_count <= row;
            end
        end
    end

    wire [36:0][36:0][7:0] blur_win;
    wire blur_win_valid, blur_win_inside;
    wire [18:0] blur_win_pos;

    wire [1:0] orientation_quadrant;
    wire [3:0] orientation_sector;
    wire orientation_valid;
    wire [18:0] orientation_pos;
    wire signed [7:0] orientation_sin, orientation_cos;
    wire kp_valid, kp_reset_busy, kp_overflow;
    wire [9:0] kp_x;
    wire [8:0] kp_y;
    wire [7:0] kp_score;
    wire kp_ready;
    logic [26:0] expected_keypoints[$];
    logic [26:0] expected_keypoint;
    // Check arbiter-driven FIFO consumption against the post-NMS stream.
    always @(posedge clk) begin
        if (reset) begin
            expected_keypoints.delete();
        end else begin
            if (out_valid && out_inside && out_keypoint &&
                W >= 43 && H >= 43 && out_x >= 21 && out_x < W-21 &&
                out_y >= 21 && out_y < H-21)
                expected_keypoints.push_back({out_x, out_y, out_score});
            if (kp_valid && kp_ready) begin
                if (expected_keypoints.size() == 0)
                    $fatal(1, "Unexpected FIFO keypoint");
                expected_keypoint = expected_keypoints.pop_front();
                if ({kp_x, kp_y, kp_score} !== expected_keypoint)
                    $fatal(1, "FIFO keypoint order/data mismatch");
            end
            if (kp_overflow)
                $fatal(1, "Unexpected keypoint FIFO overflow");
        end
    end

    orb_pyramid_level #(.FRAME_WIDTH(W), .FRAME_HEIGHT(H)) dut (
        .clk(clk), .reset(reset),
        .in_pixel(pixel_in), .in_valid(pixel_valid), .in_x(col), .in_y(row),
        .threshold(threshold),
        .kp_overflow(kp_overflow), .descriptor_ready(1'b1)
    );

    assign out_valid = dut.out_valid;
    assign out_inside = dut.out_inside;
    assign out_x = dut.out_x;
    assign out_y = dut.out_y;
    assign out_keypoint = dut.out_keypoint;
    assign out_score = dut.out_score;
    assign out_gray = dut.out_gray;
    assign blur_win = dut.blur_win;
    assign blur_win_valid = dut.blur_win_valid;
    assign blur_win_inside = dut.blur_win_inside;
    assign blur_win_pos = dut.blur_win_pos;
    assign orientation_quadrant = dut.orientation_quadrant;
    assign orientation_sector = dut.orientation_sector;
    assign orientation_valid = dut.orientation_valid;
    assign orientation_pos = dut.orientation_pos;
    assign orientation_sin = dut.orientation_sin;
    assign orientation_cos = dut.orientation_cos;
    assign kp_valid = dut.kp_valid;
    assign kp_ready = dut.kp_ready;
    assign kp_x = dut.kp_x;
    assign kp_y = dut.kp_y;
    assign kp_score = dut.kp_score;
    assign kp_reset_busy = dut.kp_reset_busy;

    always #5 clk = ~clk;

    reg [7:0] image [0:W*H-1];
    reg [7:0] blur_reference [0:W*H-1];
    reg [5:0] angle_reference [0:W*H-1];
    integer descriptor_fd;
    integer admitted = 0, dispatched = 0, dropped = 0, completed = 0;
    integer   fd, errors, frame_out, exp_x, exp_y, kp_count, seed, x, y, f, g;

    initial begin
        $readmemh(IMAGE, image);
        if (BLUR_REF != "") $readmemh(BLUR_REF, blur_reference);
        if (ANGLE_REF != "") $readmemh(ANGLE_REF, angle_reference);
        descriptor_fd = $fopen("rtl_descriptors.txt", "w");
        fd = $fopen(KP_OUT, "w");
        errors = 0; frame_out = 0; exp_x = 0; exp_y = 0; kp_count = 0;
        seed = SEED;
    end

    localparam int GAUSS_W [0:6] = '{1,6,15,20,15,6,1};
    integer patches_checked = 0;

    function automatic [7:0] reference_blur(input int cx, cy);
        int sum;
        if (BLUR_REF != "") return blur_reference[cy*W+cx];
        sum = 0;
        for (int r = 0; r < 7; r++)
            for (int c = 0; c < 7; c++)
                sum += int'(image[(cy-3+r)*W + cx-3+c]) * GAUSS_W[r] * GAUSS_W[c];
        return 8'(sum >> 12);
    endfunction

    always @(posedge clk) begin
        if (!reset) begin
            if (dut.kp_push && dut.kp_write_ready) admitted++;
            if (|dut.brief_start) dispatched++;
            if (dut.keypoint_stale || (dut.keypoint_matches && !dut.brief_available)) dropped++;
            if (!$onehot0(dut.brief_start)) $fatal(1, "Multiple BRIEF grants");
            for (int engine = 0; engine < 3; engine++) begin
                if (dut.brief_start[engine]) begin
                    if (!kp_valid || !kp_ready || !orientation_valid ||
                        kp_x != orientation_pos[18:9]-21 || kp_y != orientation_pos[8:0]-21)
                        $fatal(1, "BRIEF grant without coordinate match");
                    for (int higher = 0; higher <= engine; higher++)
                        if (dut.brief_busy[higher] != (higher == engine ? 1'b0 : 1'b1))
                            $fatal(1, "BRIEF priority violation");
                end
            end
        end
    end

    for (genvar engine = 0; engine < 3; engine++) begin : g_check_brief
        logic [255:0] expected_descriptor;
        logic pending = 0;
        logic [18:0] expected_pos;
        logic [7:0] expected_score;
        int xa, ya, xb, yb, ax, ay, bx, by;
        int accepted_cycle, cycle = 0;
        always @(posedge clk) begin
            cycle++;
            if (reset) pending = 0;
            else if (dut.brief_start[engine]) begin
                if (pending) $fatal(1, "BRIEF reused before completion");
                pending = 1;
                accepted_cycle = cycle;
                expected_pos = {kp_x, kp_y};
                expected_score = kp_score;
                for (int pair_id = 0; pair_id < 256; pair_id++) begin
                    xa = int'(dut.g_brief[engine].brief.pattern.PAIRS[pair_id][0]);
                    ya = int'(dut.g_brief[engine].brief.pattern.PAIRS[pair_id][1]);
                    xb = int'(dut.g_brief[engine].brief.pattern.PAIRS[pair_id][2]);
                    yb = int'(dut.g_brief[engine].brief.pattern.PAIRS[pair_id][3]);
                    ax = (xa*int'(orientation_cos)-ya*int'(orientation_sin)) >>> 7;
                    ay = (xa*int'(orientation_sin)+ya*int'(orientation_cos)) >>> 7;
                    bx = (xb*int'(orientation_cos)-yb*int'(orientation_sin)) >>> 7;
                    by = (xb*int'(orientation_sin)+yb*int'(orientation_cos)) >>> 7;
                    expected_descriptor[pair_id] =
                        (reference_blur(int'(kp_x)+ax, int'(kp_y)+ay) >> 2) >
                        (reference_blur(int'(kp_x)+bx, int'(kp_y)+by) >> 2);
                end
            end
            #1;
            if (!reset && dut.brief_valid[engine] && dut.brief_ready[engine]) begin
                if (!pending || cycle-accepted_cycle != 259)
                    $fatal(1, "BRIEF completion timing mismatch");
                if (dut.brief_descriptor[engine] !== expected_descriptor ||
                    dut.brief_pos[engine] !== expected_pos || dut.brief_score[engine] !== expected_score)
                    $fatal(1, "BRIEF descriptor/metadata mismatch engine %0d", engine);
                pending = 0;
                completed++;
                $fdisplay(descriptor_fd, "%0d %0d %0d %0d %064h", engine,
                          expected_pos[18:9], expected_pos[8:0], expected_score,
                          dut.brief_descriptor[engine]);
            end
        end
    end

    always @(posedge clk) begin
        #2;
        if (blur_win_valid && blur_win_pos == {10'd42, 9'd42}) begin
            if (!blur_win_inside) $fatal(1, "Blur patch unexpectedly outside");
            for (int r = 0; r < 37; r++)
                for (int c = 0; c < 37; c++)
                    if (blur_win[r][c] !== reference_blur(c+3, r+3))
                        $fatal(1, "Blur patch mismatch at (%0d,%0d)", c, r);
            patches_checked++;
        end
    end

    logic [12:0] angle_valid_pipe = 0;
    logic [18:0] angle_tags [0:12];
    int angle_codes [0:12], angle_quadrants [0:12];
    longint signed mx, my;
    longint unsigned ax, ay, tangent [0:15];
    int local_sector, quadrant, orientations_checked = 0;
    int expected_sin, expected_cos;
    real reference_angle;

    initial begin
        for (int k = 0; k < 16; k++)
            tangent[k] = $rtoi($tan((k+0.5)*3.141592653589793/32.0)*65536.0+0.5);
    end

    always @(posedge clk) begin
        for (int i = 12; i > 0; i--) begin
            angle_tags[i] = angle_tags[i-1];
            angle_codes[i] = angle_codes[i-1];
            angle_quadrants[i] = angle_quadrants[i-1];
        end
        angle_valid_pipe = reset ? '0 : {angle_valid_pipe[11:0], blur_win_valid && blur_win_inside};
        if (blur_win_valid && blur_win_inside) begin
            if (ANGLE_REF != "") begin
                local_sector = int'(angle_reference[(int'(blur_win_pos[8:0])-21)*W +
                                                    int'(blur_win_pos[18:9])-21] & 6'h0f);
                quadrant = int'(angle_reference[(int'(blur_win_pos[8:0])-21)*W +
                                                int'(blur_win_pos[18:9])-21] >> 4);
            end else begin
            mx = 0;
            my = 0;
            for (int r = 0; r < 37; r++) begin
                for (int c = 0; c < 37; c++) begin
                    mx += (c-18)*int'(blur_win[r][c]);
                    my += (r-18)*int'(blur_win[r][c]);
                end
            end
            ax = mx < 0 ? -mx : mx;
            ay = my < 0 ? -my : my;
            quadrant = my < 0 ? (mx < 0 ? 2 : 3) : (mx < 0 ? 1 : 0);
            local_sector = 0;
            for (int k = 0; k < 16; k++)
                if (ay != 0 && ax*tangent[k] <= ay*65536) local_sector = k;
            end
            angle_tags[0] = blur_win_pos;
            angle_quadrants[0] = quadrant;
            angle_codes[0] = local_sector;
        end
        #1;
        if (orientation_valid !== angle_valid_pipe[12]) $fatal(1, "Orientation valid/border mismatch");
        if (orientation_valid) begin
            if (orientation_pos !== angle_tags[12] || orientation_sector !== 4'(angle_codes[12]) ||
                orientation_quadrant !== 2'(angle_quadrants[12]))
                $fatal(1, "Orientation mismatch at tag %0d: sector %0d expected %0d", orientation_pos,orientation_sector,angle_codes[12]);
            orientations_checked++;
            reference_angle = (angle_codes[12]+0.5)*3.141592653589793/32.0;
            expected_sin = $rtoi($sin(reference_angle)*128.0+0.5);
            expected_cos = $rtoi($cos(reference_angle)*128.0+0.5);
            if (expected_sin > 127) expected_sin = 127;
            if (expected_cos > 127) expected_cos = 127;
            if (angle_quadrants[12] >= 2) expected_sin = -expected_sin;
            if (angle_quadrants[12] == 1 || angle_quadrants[12] == 2)
                expected_cos = -expected_cos;
            if (orientation_sin !== 8'(expected_sin) || orientation_cos !== 8'(expected_cos))
                $fatal(1, "Orientation sine/cosine mismatch at tag %0d", orientation_pos);
        end
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
        repeat (320) @(posedge clk);
        $fclose(fd);
        $fclose(descriptor_fd);
        if (completed != dispatched || admitted != dispatched + dropped)
            $fatal(1, "BRIEF accounting mismatch");
        $display("BRIEF COUNTS: admitted=%0d dispatched=%0d completed=%0d dropped=%0d",
                 admitted, dispatched, completed, dropped);

        if (expected_keypoints.size() != 0 || kp_valid)
            $fatal(1, "Keypoint FIFO did not drain");

        if (frame_out != 2) begin
            $display("ERROR: %0d complete frames reported, expected 2", frame_out);
            errors = errors + 1;
        end

        if (W >= 43 && H >= 43 && patches_checked != 2)
            $fatal(1, "Expected two complete blur patches, got %0d", patches_checked);

        if (orientations_checked != 2*(W-42)*(H-42))
            $fatal(1, "Orientation coverage mismatch: %0d", orientations_checked);
        $display("Orientation PASS: %0d complete patch angles checked", orientations_checked);

        if (errors == 0)
            $display("TB PASS: coverage/order/gray checks OK, %0d keypoints written to %s",
                     kp_count, KP_OUT);
        else
            $display("TB FAIL: %0d errors", errors);
        $finish;
    end

endmodule
