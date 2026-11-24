`timescale 1ns / 1ps

module tan_multiply (
    input logic clk,
    input logic reset,
    input logic [21:0] abs_moment_x,
    input logic in_valid,

    output logic [15:0][42:0] products,
    output logic out_valid
);
    // Unsigned Q5.16: tan((k + 0.5) * 90/16 degrees), rounded to nearest.
    localparam logic [20:0] TAN [0:15] = '{
        21'd3220, // 2.8125 deg: 3220/65536 = 0.0491333008
        21'd9721, // 8.4375 deg: 9721/65536 = 0.1483306885
        21'd16416, // 14.0625 deg: 16416/65536 = 0.2504882812
        21'd23449, // 19.6875 deg: 23449/65536 = 0.3578033447
        21'd30996, // 25.3125 deg: 30996/65536 = 0.4729614258
        21'd39281, // 30.9375 deg: 39281/65536 = 0.5993804932
        21'd48605, // 36.5625 deg: 48605/65536 = 0.7416534424
        21'd59398, // 42.1875 deg: 59398/65536 = 0.9063415527
        21'd72308, // 47.8125 deg: 72308/65536 = 1.1033325195
        21'd88365, // 53.4375 deg: 88365/65536 = 1.3483428955
        21'd109340, // 59.0625 deg: 109340/65536 = 1.6683959961
        21'd138564, // 64.6875 deg: 138564/65536 = 2.1143188477
        21'd183161, // 70.3125 deg: 183161/65536 = 2.7948150635
        21'd261634, // 75.9375 deg: 261634/65536 = 3.9922180176
        21'd441808, // 81.5625 deg: 441808/65536 = 6.7414550781
        21'd1334016 // 87.1875 deg: 1334016/65536 = 20.3554687500
    };

    always_ff @(posedge clk) begin
        if (reset) begin
            products <= '0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;

            if (in_valid) begin
                for (int k = 0; k < 16; k++)
                    products[k] <= abs_moment_x * TAN[k];
                    
            end
        end
    end

endmodule
