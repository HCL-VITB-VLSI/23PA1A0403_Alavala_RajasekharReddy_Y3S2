//  Parameterized Round Robin Arbiter
module round_robin_arbiter #(
    parameter integer WIDTH = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] req,
    output reg  [WIDTH-1:0] grant,
    output wire             grant_valid
);
    //----Pointer Register----
    // Exactly $clog2(WIDTH) bits -> 2 FFs for WIDTH=4
    reg  [$clog2(WIDTH)-1:0] ptr;
    // ── Step 1: Rotate req so ptr maps to bit-0 ──
    // req_rot[j] = req[(j + ptr) % WIDTH]
    wire [WIDTH-1:0] req_rot;
    genvar g;
    generate
        for (g = 0; g < WIDTH; g = g + 1) begin : GEN_ROT
            assign req_rot[g] = req[(g + ptr) % WIDTH];
        end
    endgenerate
    // ── Step 2: Isolate lowest set bit (priority encode) ──
    // grant_rot is one-hot; bit-0 = highest priority in rotated view
    wire [WIDTH-1:0] grant_rot;
    assign grant_rot = req_rot & (~req_rot + 1'b1);
    // ── Step 3: Un-rotate back to original bit positions ───
    // grant_rot[j]=1 means original index (j+ptr)%WIDTH is granted
    // Therefore: grant_next[g] = grant_rot[(g - ptr + WIDTH) % WIDTH]
    wire [WIDTH-1:0] grant_next;
    generate
        for (g = 0; g < WIDTH; g = g + 1) begin : GEN_UNROT
            assign grant_next[g] = grant_rot[(g - ptr + WIDTH) % WIDTH];
        end
    endgenerate
    // ── Step 4: One-hot -> binary index, then +1 mod WIDTH ───
    reg [$clog2(WIDTH)-1:0] granted_idx;
    integer k;
    always @(*) begin
        granted_idx = {$clog2(WIDTH){1'b0}};
        for (k = 0; k < WIDTH; k = k + 1)
            if (grant_next[k]) granted_idx = k[$clog2(WIDTH)-1:0];
    end
  
  // +1 wraps naturally: $clog2(WIDTH) bits wide
    wire [$clog2(WIDTH)-1:0] next_ptr;
    assign next_ptr = granted_idx + 1'b1;

    // ── Sequential: only ptr and grant are registered ──
    always @(posedge clk) begin
        if (!rst_n) begin
            ptr   <= {$clog2(WIDTH){1'b0}};
            grant <= {WIDTH{1'b0}};
        end else if (|req) begin
            grant <= grant_next;
            ptr   <= next_ptr;
        end else begin
            grant <= {WIDTH{1'b0}};
            // ptr holds when no requests
        end
    end
    assign grant_valid = |grant;
endmodule
