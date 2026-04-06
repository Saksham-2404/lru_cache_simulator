`timescale 1ns/1ps

module tb_cache_controller;

    reg        clk, reset, access_req, hit;
    reg  [1:0] hit_way, lru_way;
    reg  [15:0] addr_in;
    reg  [11:0] tag_decoded;
    reg  [1:0]  index_decoded;

    wire        write_en, lru_update_en, cache_hit_out, cache_miss_out;
    wire [1:0]  way_sel, lru_used_way;
    wire [11:0] tag_to_write;
    wire [31:0] data_to_write;

    cache_controller dut (
        .clk(clk), .reset(reset), .access_req(access_req),
        .addr_in(addr_in), .hit(hit), .hit_way(hit_way),
        .lru_way(lru_way), .tag_decoded(tag_decoded), .index_decoded(index_decoded),
        .write_en(write_en), .way_sel(way_sel), .tag_to_write(tag_to_write),
        .data_to_write(data_to_write), .lru_update_en(lru_update_en),
        .lru_used_way(lru_used_way), .cache_hit_out(cache_hit_out),
        .cache_miss_out(cache_miss_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Monitor: print on every posedge to catch outputs at the right moment
    always @(posedge clk) begin
        if (write_en || cache_hit_out || cache_miss_out || lru_update_en)
            $display("  t=%0t | write_en=%b hit_out=%b miss_out=%b lru_upd=%b way_sel=%0d tag_wr=%h",
                $time, write_en, cache_hit_out, cache_miss_out,
                lru_update_en, way_sel, tag_to_write);
    end

    initial begin
        reset=1; access_req=0; hit=0; hit_way=0; lru_way=2'd2;
        addr_in=16'h00A4; tag_decoded=12'h00A; index_decoded=2'd1;
        repeat(3) @(posedge clk); reset=0; repeat(2) @(posedge clk);

        $display("\n=== MISS PATH ===");
        hit=0; lru_way=2'd2;
        access_req=1; @(posedge clk); #1; access_req=0;
        repeat(5) @(posedge clk);

        $display("\n=== HIT PATH ===");
        hit=1; hit_way=2'd2;
        access_req=1; @(posedge clk); #1; access_req=0;
        repeat(4) @(posedge clk);

        $display("\nDone."); $finish;
    end
endmodule
