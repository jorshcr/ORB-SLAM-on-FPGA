`timescale 1ns / 1ps

module image_scaler_tb #(
    parameter int W = 67,
    parameter int H = 49
);
    localparam int OW = W*5/6, OH = H*5/6;
    logic clk = 0, reset = 1, in_valid = 0;
    logic [7:0] in_gray;
    logic [9:0] in_x;
    logic [8:0] in_y;
    wire [7:0] gray_lut, gray_dsp, gray_next;
    wire [9:0] x_lut, x_dsp, x_next;
    wire [8:0] y_lut, y_dsp, y_next;
    wire valid_lut, valid_dsp, valid_next;
    integer frame [0:H-1][0:W-1];
    integer scaled [0:OH-1][0:OW-1];
    integer count = 0, next_count = 0;
    integer sx, sy, fx, fy, expected;
    logic [6:0] expected_valid = 0;

    always #5 clk = ~clk;

    image_scaler #(.FRAME_WIDTH(W), .FRAME_HEIGHT(H), .DSP_MODE("no")) lut_dut (
        .clk, .reset, .in_gray, .in_x, .in_y, .in_valid,
        .out_gray(gray_lut), .out_x(x_lut), .out_y(y_lut), .out_valid(valid_lut)
    );
    image_scaler #(.FRAME_WIDTH(W), .FRAME_HEIGHT(H), .DSP_MODE("yes")) dsp_dut (
        .clk, .reset, .in_gray, .in_x, .in_y, .in_valid,
        .out_gray(gray_dsp), .out_x(x_dsp), .out_y(y_dsp), .out_valid(valid_dsp)
    );
    image_scaler #(.FRAME_WIDTH(OW), .FRAME_HEIGHT(OH)) next_dut (
        .clk, .reset, .in_gray(gray_lut), .in_x(x_lut), .in_y(y_lut), .in_valid(valid_lut),
        .out_gray(gray_next), .out_x(x_next), .out_y(y_next), .out_valid(valid_next)
    );

    always @(posedge clk) begin
        if (reset)
            expected_valid = 0;
        else
            expected_valid = {expected_valid[5:0], in_valid &&
                (in_x%6 != 1) && (in_y%6 != 1) &&
                (in_x/6*5 + ((in_x%6 == 0) ? 0 : in_x%6-1) < OW) &&
                (in_y/6*5 + ((in_y%6 == 0) ? 0 : in_y%6-1) < OH)};
        #1;
        if (valid_lut !== expected_valid[6]) $fatal(1, "Latency/valid mismatch");
        if (valid_lut !== valid_dsp) $fatal(1, "DSP/LUT valid mismatch");
        if (valid_lut) begin
            if ({gray_lut,x_lut,y_lut} !== {gray_dsp,x_dsp,y_dsp}) $fatal(1, "DSP/LUT mismatch");
            if (x_lut != count%OW || y_lut != count/OW) $fatal(1, "Raster mismatch");
            sx = x_lut*6/5; sy = y_lut*6/5;
            fx = x_lut*6%5; fy = y_lut*6%5;
            expected = (frame[sy][sx]*(5-fx)*(5-fy) + frame[sy][sx+1]*fx*(5-fy) +
                        frame[sy+1][sx]*(5-fx)*fy + frame[sy+1][sx+1]*fx*fy)/25;
            if (gray_lut !== 8'(expected)) $fatal(1, "Pixel mismatch at %d,%d: %d vs %d", x_lut,y_lut,gray_lut,expected);
            count++;
        end
        if (valid_next) begin
            if (x_next != next_count%(OW*5/6) || y_next != next_count/(OW*5/6)) $fatal(1, "Cascade raster mismatch");
            sx = x_next*6/5; sy = y_next*6/5;
            fx = x_next*6%5; fy = y_next*6%5;
            expected = (scaled[sy][sx]*(5-fx)*(5-fy) + scaled[sy][sx+1]*fx*(5-fy) +
                        scaled[sy+1][sx]*(5-fx)*fy + scaled[sy+1][sx+1]*fx*fy)/25;
            if (gray_next !== 8'(expected)) $fatal(1, "Cascade pixel mismatch");
            next_count++;
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        for (int test_case = 0; test_case < 5; test_case++) begin
            reset = 1;
            in_valid = 0;
            repeat (3) @(negedge clk);
            count = 0; next_count = 0;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                    case (test_case)
                        0: frame[y][x] = 0;
                        1: frame[y][x] = 255;
                        2: frame[y][x] = (x*3+y*7)%256;
                        3: frame[y][x] = ((x+y)%2)*255;
                        4: frame[y][x] = $urandom_range(255,0);
                    endcase
            for (int y = 0; y < OH; y++) begin
                for (int x = 0; x < OW; x++) begin
                    sx = x*6/5; sy = y*6/5;
                    fx = x*6%5; fy = y*6%5;
                    scaled[y][x] = (frame[sy][sx]*(5-fx)*(5-fy) + frame[sy][sx+1]*fx*(5-fy) +
                                    frame[sy+1][sx]*(5-fx)*fy + frame[sy+1][sx+1]*fx*fy)/25;
                end
            end
            reset = 0;
            for (int y = 0; y < H; y++) begin
                for (int x = 0; x < W; x++) begin
                    if (test_case >= 2 && (x+y)%7 == 0) begin
                        in_valid = 0;
                        repeat (2) @(negedge clk);
                    end
                    in_valid = 1; in_x = x; in_y = y; in_gray = frame[y][x];
                    @(negedge clk);
                end
            end
            in_valid = 0;
            repeat (20) @(negedge clk);
            if (count != OW*OH || next_count != (OW*5/6)*(OH*5/6)) $fatal(1, "Output count mismatch");
        end
        $display("PASS: image_scaler five images, DSP/LUT equivalence, seven-cycle latency, gaps, reset and cascade");
        $finish;
    end
endmodule
