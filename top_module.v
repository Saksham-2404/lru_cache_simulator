// =============================================================================
// Module: top_module
// Project: Hardware LRU Cache Simulator
// Board: Nexys A7 (XC7A100T-1CSG324C)
//
// Purpose:
//   Connects all submodules and maps internal signals to FPGA physical I/O.
//   No logic lives here — only wiring and instantiation.
//
// I/O mapping:
//   SW[15:0]  → 16-bit memory address input
//   BTNC      → access request (debounced)
//   BTNL      → system reset
//   LED[0]    → cache hit indicator
//   LED[1]    → cache miss indicator
//   SEG[6:0]  → 7-segment cathode outputs (active low on Nexys A7)
//   AN[7:0]   → digit anode enables (active low on Nexys A7)
//   DP        → decimal point (tied off)
// =============================================================================

module top_module(
    input        clk,           // 100 MHz system clock (E3 on Nexys A7)

    // ── Switches ─────────────────────────────────────────────
    input  [15:0] SW,           // 16-bit memory address

    // ── Buttons ──────────────────────────────────────────────
    input        BTNC,          // access request
    input        BTNL,          // system reset

    // ── LEDs ─────────────────────────────────────────────────
    output [15:0] LED,          // LED[0]=hit, LED[1]=miss, rest unused

    // ── 7-Segment display ─────────────────────────────────────
    output [6:0]  SEG,          // cathodes (a-g), active low
    output        DP,           // decimal point, active low
    output [7:0]  AN            // anodes, active low
);

    // =========================================================================
    // INTERNAL SIGNALS (wires connecting submodule ports)
    // =========================================================================

    // ── Address decoder outputs ───────────────────────────────
    wire [11:0] tag_decoded;
    wire [1:0]  index_decoded;
    wire [1:0]  offset_decoded;   // not used by cache logic, but decoded anyway

    // ── Cache memory outputs ──────────────────────────────────
    wire [11:0] tag_out    [0:3];
    wire [31:0] data_out   [0:3];  // available for future display / UART stretch goal
    wire [3:0]  valid_out;

    // ── Tag comparator outputs ────────────────────────────────
    wire        hit;
    wire [1:0]  hit_way;

    // ── LRU controller outputs ────────────────────────────────
    wire [1:0]  lru_way;

    // ── Cache controller outputs ──────────────────────────────
    wire        write_en;
    wire [1:0]  way_sel;
    wire [11:0] tag_to_write;
    wire [31:0] data_to_write;
    wire        lru_update_en;
    wire [1:0]  lru_used_way;
    wire        cache_hit_out;
    wire        cache_miss_out;

    // ── Debounced button signals ──────────────────────────────
    wire        access_req_db;   // debounced BTNC
    wire        reset_db;        // debounced BTNL

    // ── LRU controller index feed ─────────────────────────────
    // The LRU controller needs to know which set to read lru_way from.
    // During MISS_EVICT the index in use is index_decoded (latched inside FSM).
    // We connect index_decoded here; the FSM latches it internally.
    wire [1:0]  lru_index;
    assign lru_index = index_decoded;

    // =========================================================================
    // SUBMODULE INSTANTIATIONS
    // =========================================================================

    // ── 1. Button Debouncer ───────────────────────────────────────────────────
    // Physical buttons bounce for ~5–20 ms. Without debouncing, one press
    // triggers dozens of accesses. The debouncer filters this to a clean edge.
    // We use a simple counter-based debouncer: output only changes after the
    // input has been stable for N clock cycles (here ~5 ms at 100 MHz = 500,000).
    debouncer #(.STABLE_COUNT(500_000)) u_dbnc_access (
        .clk    (clk),
        .btn_in (BTNC),
        .btn_out(access_req_db)
    );

    debouncer #(.STABLE_COUNT(500_000)) u_dbnc_reset (
        .clk    (clk),
        .btn_in (BTNL),
        .btn_out(reset_db)
    );

    // ── 2. Address Decoder ────────────────────────────────────────────────────
    addr_decoder u_addr_dec (
        .addr   (SW),
        .tag    (tag_decoded),
        .index  (index_decoded),
        .offset (offset_decoded)
    );

    // ── 3. Cache Memory ───────────────────────────────────────────────────────
    cache_memory u_cache_mem (
        .clk      (clk),
        .index    (index_decoded),
        .way_sel  (way_sel),
        .write_en (write_en),
        .tag_in   (tag_to_write),
        .data_in  (data_to_write),
        .tag_out  (tag_out),
        .data_out (data_out),
        .valid_out(valid_out)
    );

    // ── 4. Tag Comparator ─────────────────────────────────────────────────────
    tag_comparator u_tag_cmp (
        .tag_in    (tag_decoded),
        .tag_stored(tag_out),       // from cache_memory
        .valid_bits(valid_out),
        .hit       (hit),
        .hit_way   (hit_way)
    );

    // ── 5. LRU Controller ────────────────────────────────────────────────────
    lru_controller u_lru (
        .clk       (clk),
        .reset     (reset_db),
        .update_en (lru_update_en),
        .index     (lru_index),
        .used_way  (lru_used_way),
        .lru_way   (lru_way)
    );

    // ── 6. Cache Controller (FSM) ────────────────────────────────────────────
    cache_controller u_ctrl (
        .clk           (clk),
        .reset         (reset_db),
        .access_req    (access_req_db),
        .addr_in       (SW),
        .hit           (hit),
        .hit_way       (hit_way),
        .lru_way       (lru_way),
        .tag_decoded   (tag_decoded),
        .index_decoded (index_decoded),
        .write_en      (write_en),
        .way_sel       (way_sel),
        .tag_to_write  (tag_to_write),
        .data_to_write (data_to_write),
        .lru_update_en (lru_update_en),
        .lru_used_way  (lru_used_way),
        .cache_hit_out (cache_hit_out),
        .cache_miss_out(cache_miss_out)
    );

    // ── 7. Stats Display ─────────────────────────────────────────────────────
    // stats_display is your teammate's module. Ports assumed below.
    // Adjust port names if your teammate's implementation differs.
    stats_display u_stats (
        .clk      (clk),
        .reset    (reset_db),
        .hit_in   (cache_hit_out),
        .miss_in  (cache_miss_out),
        .SEG      (SEG),
        .DP       (DP),
        .AN       (AN)
    );

    // ── 8. LED Driver ────────────────────────────────────────────────────────
    // LED[0] = hit, LED[1] = miss.
    // cache_hit_out / cache_miss_out are 1-cycle pulses. We stretch them to
    // ~0.25 seconds so they're visible to the human eye (25,000,000 cycles).
    led_blink u_led_hit (
        .clk    (clk),
        .pulse  (cache_hit_out),
        .led_out(LED[0])
    );

    led_blink u_led_miss (
        .clk    (clk),
        .pulse  (cache_miss_out),
        .led_out(LED[1])
    );

    // Unused LEDs — tie off to 0
    assign LED[15:2] = 14'd0;

endmodule


// =============================================================================
// Helper module: debouncer
// Simple counter-based button debouncer.
// Output only changes when input has been stable for STABLE_COUNT cycles.
// =============================================================================
module debouncer #(
    parameter STABLE_COUNT = 500_000  // 5ms at 100MHz
)(
    input  clk,
    input  btn_in,
    output reg btn_out
);
    reg [$clog2(STABLE_COUNT)-1 : 0] count;
    reg btn_prev;

    always @(posedge clk) begin
        if (btn_in !== btn_prev) begin
            // Input changed — restart stability counter
            count    <= 0;
            btn_prev <= btn_in;
        end
        else if (count < STABLE_COUNT - 1) begin
            count <= count + 1;
        end
        else begin
            // Input stable for STABLE_COUNT cycles — commit to output
            btn_out <= btn_in;
        end
    end
endmodule


// =============================================================================
// Helper module: led_blink
// Stretches a 1-cycle pulse to ~0.25 seconds so it's human-visible.
// =============================================================================
module led_blink #(
    parameter HOLD_CYCLES = 25_000_000  // 0.25s at 100MHz
)(
    input  clk,
    input  pulse,
    output reg led_out
);
    reg [24:0] count;

    always @(posedge clk) begin
        if (pulse) begin
            led_out <= 1'b1;
            count   <= 0;
        end
        else if (count < HOLD_CYCLES - 1) begin
            count <= count + 1;
        end
        else begin
            led_out <= 1'b0;
        end
    end
endmodule
