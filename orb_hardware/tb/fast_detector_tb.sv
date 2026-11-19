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

    logic             win_valid;
    logic [6:0][6:0][7:0] win;
    logic [18:0]      win_pos;

    line_window #(
        .N(7), .LINE_W(W), .DATA_W(8), .TAG_W(19)
    ) pixel_window (
        .clk(clk), .reset(reset),
        .in_valid(pixel_valid), .in_data(pixel_in),
        .in_col(col), .in_tag({col, row}),
        .out_valid(win_valid), .out_win(win), .out_tag(win_pos)
    );

    wire [36:0][36:0][7:0] blur_win;
    wire blur_win_valid, blur_win_inside;
    wire [18:0] blur_win_pos;

    wire [1:0] orientation_quadrant;
    wire [5:0] orientation_sector;
    wire orientation_valid;
    wire [18:0] orientation_pos;

    orb_pyramid_level #(.FRAME_WIDTH(W), .FRAME_HEIGHT(H)) dut (
        .clk(clk), .reset(reset),
        .win(win), .win_valid(win_valid), .win_pos(win_pos),
        .threshold(threshold),
        .out_valid(out_valid), .out_inside(out_inside),
        .out_x(out_x), .out_y(out_y), .out_keypoint(out_keypoint),
        .out_score(out_score), .out_gray(out_gray),
        .blur_win(blur_win), .blur_win_valid(blur_win_valid),
        .blur_win_inside(blur_win_inside), .blur_win_pos(blur_win_pos),
        .orientation_quadrant(orientation_quadrant), .orientation_sector(orientation_sector),
        .orientation_valid(orientation_valid), .orientation_pos(orientation_pos)
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

    localparam int GAUSS_W [0:6] = '{1,6,15,20,15,6,1};
    integer patches_checked = 0;

    function automatic [7:0] reference_blur(input int cx, cy);
        int sum;
        sum = 0;
        for (int r = 0; r < 7; r++)
            for (int c = 0; c < 7; c++)
                sum += int'(image[(cy-3+r)*W + cx-3+c]) * GAUSS_W[r] * GAUSS_W[c];
        return 8'(sum >> 12);
    endfunction

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

    logic [11:0] angle_valid_pipe = 0;
    logic [18:0] angle_tags [0:11];
    int angle_codes [0:11], angle_quadrants [0:11];
    longint signed mx, my;
    longint unsigned ax, ay, tangent [0:15];
    int local_sector, quadrant, orientations_checked = 0;

    initial begin
        for (int k = 0; k < 16; k++)
            tangent[k] = $rtoi($tan((k+0.5)*3.141592653589793/32.0)*65536.0+0.5);
    end

    always @(posedge clk) begin
        for (int i = 11; i > 0; i--) begin
            angle_tags[i] = angle_tags[i-1];
            angle_codes[i] = angle_codes[i-1];
            angle_quadrants[i] = angle_quadrants[i-1];
        end
        angle_valid_pipe = reset ? '0 : {angle_valid_pipe[10:0], blur_win_valid && blur_win_inside};
        if (blur_win_valid && blur_win_inside) begin
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
            angle_tags[0] = blur_win_pos;
            angle_quadrants[0] = quadrant;
            angle_codes[0] = quadrant*16 + ((quadrant % 2) ? 15-local_sector : local_sector);
        end
        #1;
        if (orientation_valid !== angle_valid_pipe[11]) $fatal(1, "Orientation valid/border mismatch");
        if (orientation_valid) begin
            if (orientation_pos !== angle_tags[11] || orientation_sector !== 6'(angle_codes[11]) ||
                orientation_quadrant !== 2'(angle_quadrants[11]))
                $fatal(1, "Orientation mismatch at tag %0d: sector %0d expected %0d", orientation_pos,orientation_sector,angle_codes[11]);
            orientations_checked++;
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
        repeat (50) @(posedge clk);
        $fclose(fd);

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
