`timescale 1ns / 1ps
module quadrant_angle_compute_tb;
    logic clk = 0, reset = 1, in_valid = 0;
    logic signed [21:0] m10 = 0, m01 = 0;
    logic [18:0] in_tag = 0, out_tag;
    logic [1:0] out_quadrant;
    logic [3:0] out_sector;
    logic out_valid;
    logic [3:0] valid_pipe = 0;
    int quadrant_ref [0:3], sector_ref [0:3], angle_ref [0:3];
    logic defined_ref [0:3];
    logic [18:0] tag_ref [0:3];
    longint unsigned ax, ay, coefficient;
    real theta;
    int checked = 0, seq = 0;
    int unsigned rng = 32'h12345;
    quadrant_angle_compute dut (.*);
    always #5 clk = ~clk;

    function automatic int unsigned random_value();
        rng = rng * 1664525 + 1013904223;
        return rng;
    endfunction

    always @(posedge clk) begin
        for (int stage = 3; stage > 0; stage--) begin
            quadrant_ref[stage] = quadrant_ref[stage-1];
            sector_ref[stage] = sector_ref[stage-1];
            angle_ref[stage] = angle_ref[stage-1];
            defined_ref[stage] = defined_ref[stage-1];
            tag_ref[stage] = tag_ref[stage-1];
        end
        valid_pipe = reset ? '0 : {valid_pipe[2:0], in_valid};
        ax = (m10 < 0) ? -longint'(m10) : longint'(m10);
        ay = (m01 < 0) ? -longint'(m01) : longint'(m01);
        defined_ref[0] = ax != 0 || ay != 0;
        quadrant_ref[0] = m01 < 0 ? (m10 < 0 ? 2 : 3) : (m10 < 0 ? 1 : 0);
        sector_ref[0] = 0;
        for (int k = 0; k < 16; k++) begin
            theta = (k+0.5)*3.141592653589793/32.0;
            coefficient = $rtoi($sin(theta)/$cos(theta)*65536.0+0.5);
            if (defined_ref[0] && ax*coefficient <= ay*65536)
                sector_ref[0] = k;
        end
        angle_ref[0] = quadrant_ref[0]*16 + ((quadrant_ref[0] % 2) ? 15-sector_ref[0] : sector_ref[0]);
        tag_ref[0] = in_tag;
        #1;
        if (out_valid !== valid_pipe[3]) $fatal(1, "Four-stage valid mismatch");
        if (out_valid) begin
            if (out_quadrant !== 2'(quadrant_ref[3]) || out_sector !== 4'(sector_ref[3]) || out_tag !== tag_ref[3])
                $fatal(1, "Output mismatch for tag %0d: q=%0d sector=%0d expected q=%0d sector=%0d",
                       out_tag,out_quadrant,out_sector,quadrant_ref[3],sector_ref[3]);
            checked++;
        end
    end

    task automatic drive(input int x, y, input bit valid = 1);
        @(negedge clk);
        m10 = 22'(x);
        m01 = 22'(y);
        in_valid = valid;
        in_tag = 19'(seq);
        seq++;
    endtask

    initial begin
        int threshold_value, x, y;
        repeat (3) @(negedge clk);
        reset = 0;
        drive(0,0);
        drive(1,0); drive(-1,0); drive(0,1); drive(0,-1);
        drive(-2097152,0); drive(0,-2097152);
        drive(-2097152,-2097152); drive(2097151,2097151);
        for (int k = 0; k < 16; k++) begin
            threshold_value = $rtoi($tan((k+0.5)*3.141592653589793/32.0)*65536.0+0.5);
            for (int offset = -1; offset <= 1; offset++) begin
                for (int q = 0; q < 4; q++) begin
                    x = (q == 1 || q == 2) ? -65536 : 65536;
                    y = (q >= 2) ? -(threshold_value+offset) : threshold_value+offset;
                    drive(x,y);
                end
            end
        end
        for (int n = 0; n < 600; n++) begin
            if (n == 300) begin
                @(negedge clk); reset = 1;
                @(negedge clk); reset = 0;
            end
            x = int'(random_value() & 32'h3fffff)-2097152;
            y = int'(random_value() & 32'h3fffff)-2097152;
            drive(x,y,n % 5 != 0);
        end
        drive(0,0,0);
        repeat (6) @(negedge clk);
        if (checked < 650) $fatal(1, "Insufficient checks");
        $display("PASS: quadrant_angle_compute, %0d outputs; all quadrants, axes, zero, signed limits, threshold ties, gaps and reset", checked);
        $finish;
    end
endmodule
