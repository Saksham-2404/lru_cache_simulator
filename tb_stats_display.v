`timescale 1ns / 1ps

module tb_stats_display;

    reg clk;
    reg reset;
    reg cache_hit;
    reg cache_miss;

    wire [7:0] seg;
    wire [7:0] an;
    wire [1:0] led;

    // Instantiate DUT
    stats_display uut (
        .clk(clk),
        .reset(reset),
        .cache_hit(cache_hit),
        .cache_miss(cache_miss),
        .seg(seg),
        .an(an),
        .led(led)
    );

    //------------------------------------------------------------
    // 100 MHz clock -> 10 ns period
    //------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //------------------------------------------------------------
    // Test Sequence
    //------------------------------------------------------------
    initial begin
        reset      = 1;
        cache_hit  = 0;
        cache_miss = 0;

        // Hold reset for a few cycles
        #20;
        reset = 0;

        // Generate 3 hits
        #10 cache_hit = 1;
        #10 cache_hit = 0;

        #20 cache_hit = 1;
        #10 cache_hit = 0;

        #20 cache_hit = 1;
        #10 cache_hit = 0;

        // Generate 2 misses
        #30 cache_miss = 1;
        #10 cache_miss = 0;

        #20 cache_miss = 1;
        #10 cache_miss = 0;

        // Wait and observe display scan + LEDs
        #500;

        $display("Final hit_count should be 3");
        $display("Final miss_count should be 2");

        $finish;
    end

endmodule
