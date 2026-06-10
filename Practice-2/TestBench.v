//  Testbench for round_robin_arbiter
`timescale 1ns/1ps
module tb_round_robin;
    parameter WIDTH = 4;
    reg             clk, rst_n;
    reg [WIDTH-1:0] req;
    wire[WIDTH-1:0] grant;
    wire            grant_valid;

    // ── DUT ──
    round_robin_arbiter #(.WIDTH(WIDTH)) DUT (
        .clk(clk), .rst_n(rst_n),
        .req(req), .grant(grant), .grant_valid(grant_valid)
    );

    // ── Clock Generation ──
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // ── Golden reference pointer ──
    integer gold_ptr;
    reg [WIDTH-1:0] gold_grant;

    task compute_golden;
        integer k;
        begin
            gold_grant = 0;
            for (k = 0; k < WIDTH; k = k + 1) begin
                if (req[(k + gold_ptr) % WIDTH] && gold_grant == 0)
                    gold_grant = 1 << ((k + gold_ptr) % WIDTH);
            end
            if (gold_grant != 0) begin
                for (k = 0; k < WIDTH; k = k + 1)
                    if (gold_grant[k]) gold_ptr = (k + 1) % WIDTH;
            end
        end
    endtask

    // ── Main Test Stimulus ──
    integer i, pass_cnt, fail_cnt;
    reg [WIDTH-1:0] rand_req;

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_round_robin);
        pass_cnt = 0; fail_cnt = 0;
        gold_ptr = 0;

        // Reset
        rst_n = 0; req = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst_n = 1;

        // ── Case 1: Single Requester ──
        $display("\n=== Case 1: Only req[0] active ===");
        repeat(4) begin
            req = 4'b0001;
            @(posedge clk); #1;
            compute_golden;
            if (grant === gold_grant)
                begin $display("PASS: grant=%b", grant); pass_cnt = pass_cnt+1; end
            else
                begin $display("FAIL: got=%b exp=%b", grant, gold_grant); fail_cnt = fail_cnt+1; end
        end

        // ── Case 2: Two Alternating ──
        $display("\n=== Case 2: Alternating req[0]/req[1] ===");
        gold_ptr = 0;
        repeat(6) begin
            req = (req == 4'b0001) ? 4'b0010 : 4'b0001;
            @(posedge clk); #1;
            compute_golden;
            if (grant === gold_grant)
                begin $display("PASS: req=%b grant=%b", req, grant); pass_cnt = pass_cnt+1; end
            else
                begin $display("FAIL: req=%b got=%b exp=%b", req, grant, gold_grant); fail_cnt = fail_cnt+1; end
        end

        // ── Case 3: All Requesters Active ──
        $display("\n=== Case 3: All requesters active ===");
        req = {WIDTH{1'b1}};
        gold_ptr = 0;
        repeat(WIDTH*2) begin
            @(posedge clk); #1;
            compute_golden;
            if (grant === gold_grant)
                begin $display("PASS: grant=%b", grant); pass_cnt = pass_cnt+1; end
            else
                begin $display("FAIL: got=%b exp=%b", grant, gold_grant); fail_cnt = fail_cnt+1; end
        end

        // ── Case 4: Random patterns ──
        $display("\n=== Case 4: Random request patterns ===");
        gold_ptr = 0;
        for (i = 0; i < 20; i = i + 1) begin
            req = $random % (1 << WIDTH);
            @(posedge clk); #1;
            compute_golden;
            $display("ptr=%0d req=%b grant=%b gv=%b",
                DUT.ptr, req, grant, grant_valid);
            if (grant === gold_grant)
                pass_cnt = pass_cnt + 1;
            else begin
                $display("MISMATCH: exp=%b", gold_grant);
                fail_cnt = fail_cnt + 1;
            end
        end
        $display("\n=============================");
        $display(" Results: PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt);
        $display("=============================");
        $finish;
    end
endmodule
