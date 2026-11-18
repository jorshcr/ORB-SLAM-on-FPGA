`timescale 1ns / 1ps

module fast_score #(
    parameter int unsigned TAG_W = 1
)(
    input  logic             clk,
    input  logic             reset,
    input  logic             in_valid,
    input  logic [6:0][6:0][7:0] in_win,
    input  logic [7:0]       threshold,
    input  logic [TAG_W-1:0] in_tag,

    output logic             out_valid,
    output logic  [7:0]       out_score,
    output logic [TAG_W-1:0] out_tag
);

    localparam int unsigned LAT = 8; // Latency of pipeline

    // Ring generation and assignment
    // look up table for row and col of each of 16 pixels in ring
    localparam int RING_ROW [0:15] = '{0,0,1,2,3,4,5,6,6,6,5,4,3,2,1,0};
    localparam int RING_COL [0:15] = '{3,4,5,6,6,6,5,4,3,2,1,0,0,0,1,2};
    logic [7:0] ring [0:15];
    logic [7:0] center;
    assign center = in_win[3][3];
    for (genvar k = 0; k < 16; k++) begin : g_ring
        assign ring[k] = in_win[RING_ROW[k]][RING_COL[k]];
    end

    logic [7:0] d               [0:31]; // brightness difference from center
    logic [7:0] m2 [0:31], m4 [0:31], m8 [0:31], m9 [0:31]; // min differences across diff size arcs
    logic [7:0] r4              [0:7]; // max score across 4 diff arcs
    logic [7:0] s_b, s_d; // strongest bright and strongest dark score if found

    logic [LAT-1:0]       valid_pipe;
    logic [TAG_W+8-1:0]   side_pipe [0:LAT-1];
    logic [7:0]          thr_at_end; // threshold at end of pipeline (for use in adjustable thresh at runtime)
    assign thr_at_end = side_pipe[LAT-2][7:0];

    // Maximum of two adjacent arc scores of the same polarity.
    logic [7:0] arc_pair [0:15];
    for (genvar pair_index = 0; pair_index < 16; pair_index++) begin : g_arc_pairs
        assign arc_pair[pair_index] = (m9[2*pair_index] > m9[2*pair_index+1]) ?
                                     m9[2*pair_index] : m9[2*pair_index+1];
    end
    
    // compares 8 rings to get 4
    logic [7:0] r01, r23, r45, r67;
    assign r01 = max8(r4[0],r4[1]);
    assign r23 = max8(r4[2],r4[3]);
    assign r45 = max8(r4[4],r4[5]);
    assign r67 = max8(r4[6],r4[7]);

    always_ff @(posedge clk) begin
        if (reset)
            valid_pipe <= '0;
        else
            valid_pipe <= {valid_pipe[LAT-2:0], in_valid};    
    
        for (int k = 0; k < 16; k++) begin
            // stores darkness or brightness difference
            d[k]    <= (ring[k] > center) ? ring[k] - center : 8'd0;
            d[16+k] <= (center > ring[k]) ? center - ring[k] : 8'd0;
        end

        for (int p = 0; p < 2; p++) begin
            for (int k = 0; k < 16; k++) begin
                m2[p*16+k] <= min8(d[p*16+k], d[p*16+(k+1)%16]);
                m4[p*16+k] <= min8(m2[p*16+k], m2[p*16+(k+2)%16]);
                m8[p*16+k] <= min8(m4[p*16+k], m4[p*16+(k+4)%16]);
                m9[p*16+k] <= min8(m8[p*16+k], m8[p*16+(k+1)%16]);
            end
        end

        for (int k = 0; k < 8; k++)
            r4[k] <= max8(arc_pair[2*k], arc_pair[2*k+1]);

        s_b <= max8(r01, r23);
        s_d <= max8(r45, r67);

        out_score <= (max8(s_b, s_d) > thr_at_end) ? max8(s_b, s_d) : 8'd0;

        side_pipe[0] <= {in_tag, threshold};
        for (int k = 1; k < LAT; k++)
            side_pipe[k] <= side_pipe[k-1];

    end

    assign out_valid = valid_pipe[LAT-1];
    assign out_tag   = side_pipe[LAT-1][TAG_W+8-1:8];
    
    
    // Functions used above
    function automatic logic [7:0] min8(input logic [7:0] a, b);
        return (a < b) ? a : b;
    endfunction

    function automatic logic [7:0] max8(input logic [7:0] a, b);
        return (a > b) ? a : b;
    endfunction

endmodule
