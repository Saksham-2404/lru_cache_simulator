// =============================================================================
// Testbench: tb_lru_controller
// Tests the counter update sequence defined in the project document.
//
// Expected sequence (set 0):
//   After reset:          [0,1,2,3]  → lru_way = 3
//   Access way 0 again:   [0,2,3,3]  → should not change way0
//      wait — let's follow the exact project doc sequence:
//   Access set0 way0:     [0,1,2,3]  → lru = way3
//   Access set0 way2:     [1,2,0,3]  → lru = way3
//   Access set0 way3:     [2,3,1,0]  → lru = way1
// =============================================================================

`timescale 1ns/1ps

module tb_lru_controller;

    reg        clk, reset, update_en;
    reg  [1:0] index, used_way;
    wire [1:0] lru_way;

    lru_controller dut (
        .clk      (clk),
        .reset    (reset),
        .update_en(update_en),
        .index    (index),
        .used_way (used_way),
        .lru_way  (lru_way)
    );

    // 10ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    task do_access;
        input [1:0] set;
        input [1:0] way;
        begin
            index     = set;
            used_way  = way;
            update_en = 1;
            @(posedge clk); #1;
            update_en = 0;
            @(posedge clk); #1;
            $display("  → set=%0d  accessed way=%0d  | lru_way=%0d", set, way, lru_way);
        end
    endtask

    initial begin
        reset = 1; update_en = 0; index = 0; used_way = 0;
        repeat(3) @(posedge clk);
        reset = 0;
        @(posedge clk); #1;

        $display("\n--- Project doc verification sequence (set 0) ---");
        $display("After reset: lru_way=%0d (expect 3)", lru_way);

        do_access(0, 0);   // access set0 way0 → counters should be [0,1,2,3], lru=3
        $display("  Expect lru=3");

        do_access(0, 2);   // access set0 way2 → [1,2,0,3], lru=3
        $display("  Expect lru=3");

        do_access(0, 3);   // access set0 way3 → [2,3,1,0], lru=1
        $display("  Expect lru=1");

        $display("\n--- Multi-set independence test ---");
        do_access(1, 0);   // set1 should be independent
        do_access(2, 3);
        $display("  set0 lru_way with index=0:");
        index = 0; #1;
        $display("  set0 lru=%0d (should still be 1)", lru_way);

        $display("\nAll LRU tests done.");
        $finish;
    end

endmodule
