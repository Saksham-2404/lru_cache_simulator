// =============================================================================
// Module: lru_controller
// Project: Hardware LRU Cache Simulator
// Board: Nexys A7 (XC7A100T)
//
// Purpose:
//   Maintains 2-bit age counters for every way in every set.
//   Counter = 0 → most recently used
//   Counter = 3 → least recently used → evict this way
//
//   On each access (hit or miss load):
//     → Set counter[index][used_way] = 0   (just accessed = freshest)
//     → Increment all other counters in that set, capped at 3
//
//   lru_way output always reflects which way is currently oldest (counter == 3)
//   in the requested set. The cache_controller reads this before eviction.
//
// Counter update example for set 0, 4-way:
//   Initial state  → [0, 1, 2, 3]   (way3 is LRU)
//   Access way 2   → [1, 2, 0, 3]   (way2 freshest, way3 still LRU)
//   Access way 3   → [2, 3, 1, 0]   (way3 freshest, way1 is now LRU)
// =============================================================================

module lru_controller(
    input        clk,
    input        reset,

    input        update_en,   // pulse HIGH for 1 cycle to trigger an update
    input  [1:0] index,       // which set to update (0–3)
    input  [1:0] used_way,    // which way was just accessed in that set

    output reg [1:0] lru_way  // way to evict next miss in set `index`
);

    // -------------------------------------------------------------------------
    // Storage: 4 sets × 4 ways, each counter is 2 bits wide
    // counters[set][way]
    // -------------------------------------------------------------------------
    reg [1:0] counters [0:3][0:3];

    integer s, w;   // loop variables

    // -------------------------------------------------------------------------
    // RESET + UPDATE (sequential)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            // On reset: initialise all sets so way0 = newest, way3 = oldest
            // This gives a deterministic starting LRU order
            for (s = 0; s < 4; s = s + 1) begin
                counters[s][0] <= 2'd0;
                counters[s][1] <= 2'd1;
                counters[s][2] <= 2'd2;
                counters[s][3] <= 2'd3;
            end
        end
        else if (update_en) begin
            // Only touch the set identified by `index`
            for (w = 0; w < 4; w = w + 1) begin
                if (w == used_way) begin
                    // This way was just used → reset its age to 0 (freshest)
                    counters[index][w] <= 2'd0;
                end
                else begin
                    // Every other way in this set ages by 1, capped at 3
                    // Cap prevents counter overflow and keeps ordering stable
                    if (counters[index][w] < 2'd3)
                        counters[index][w] <= counters[index][w] + 2'd1;
                    // If already at 3, leave it — it's already marked as LRU
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // LRU WAY OUTPUT (combinational)
    // Scan the 4 counters of the requested set; report whichever == 3.
    // There will always be exactly one counter at 3 after reset (by design).
    //
    // Priority: way0 > way1 > way2 > way3 — only matters during the brief
    // startup window before the first 4 unique accesses to a set, when
    // multiple counters may still hold value 3 from reset.
    // After any 4 distinct accesses to a set, all counters are unique (0–3).
    // -------------------------------------------------------------------------
    always @(*) begin
        // Default: evict way 3 (safe fallback)
        lru_way = 2'd3;

        // Check in reverse priority so the highest-priority match wins
        if (counters[index][3] == 2'd3) lru_way = 2'd3;
        if (counters[index][2] == 2'd3) lru_way = 2'd2;
        if (counters[index][1] == 2'd3) lru_way = 2'd1;
        if (counters[index][0] == 2'd3) lru_way = 2'd0;
    end

endmodule
