`timescale 1ns / 1ps

module tan_multiply (
    input logic clk,
    input logic reset,
    input logic [21:0] abs_moment_x,
    input logic in_valid,

    output logic [14:0][34:0] products,
    output logic out_valid
);
    // Sector boundaries: tan((k + 1) * 90/16 degrees), scaled by 256.
    localparam logic [12:0] TAN [0:14] = '{
        13'd25, // 5.625 deg: 25/256
        13'd51, // 11.25 deg: 51/256
        13'd78, // 16.875 deg: 78/256
        13'd106, // 22.5 deg: 106/256
        13'd137, // 28.125 deg: 137/256
        13'd171, // 33.75 deg: 171/256
        13'd210, // 39.375 deg: 210/256
        13'd256, // 45 deg: 256/256
        13'd312, // 50.625 deg: 312/256
        13'd383, // 56.25 deg: 383/256
        13'd479, // 61.875 deg: 479/256
        13'd618, // 67.5 deg: 618/256
        13'd844, // 73.125 deg: 844/256
        13'd1287, // 78.75 deg: 1287/256
        13'd2599 // 84.375 deg: 2599/256
    };

    always_ff @(posedge clk) begin
        if (reset) begin
            products <= '0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;

            if (in_valid) begin
                for (int k = 0; k < 15; k++)
                    products[k] <= abs_moment_x * TAN[k];
            end
        end
    end

endmodule
