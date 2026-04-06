// =============================================================================
// Module: cache_controller
// Project: Hardware LRU Cache Simulator
// Board: Nexys A7 (XC7A100T)
//
// Purpose:
//   The FSM brain of the entire cache system. Sequences all other modules
//   through a 5-state machine. No actual data lives here — it only generates
//   control signals that tell other modules what to do and when.
//
// State diagram:
//
//   ┌──────────────────────────────────────────────────────────┐
//   │                                                          │
//   ▼   access_req=0                                           │
//  IDLE ──────────────► IDLE                                   │
//   │                                                          │
//   │ access_req=1                                             │
//   ▼                                                          │
//  LOOKUP ──── hit=1 ──► HIT_UPDATE ──────────────────────────►│
//   │                                                          │
//   │ hit=0                                                    │
//   ▼                                                          │
//  MISS_EVICT ──────────► MISS_LOAD ──────────────────────────►│
//   (find LRU way)         (write new data into that way)      │
//                                                              │
// =============================================================================

module cache_controller(
    input        clk,
    input        reset,

    // ── External inputs ──────────────────────────────────────
    input        access_req,    // button press (debounced before reaching here)
    input [15:0] addr_in,       // raw 16-bit address from switches

    // ── From tag_comparator ──────────────────────────────────
    input        hit,           // 1 = tag matched and valid
    input  [1:0] hit_way,       // which way matched

    // ── From lru_controller ──────────────────────────────────
    input  [1:0] lru_way,       // which way to evict on a miss

    // ── From addr_decoder (wired externally through top_module) ──
    input  [11:0] tag_decoded,  // so controller can latch tag on miss
    input  [1:0]  index_decoded,

    // ── To cache_memory ──────────────────────────────────────
    output reg        write_en,     // enable write on miss load
    output reg [1:0]  way_sel,      // which way to write (= lru_way on miss)
    output reg [11:0] tag_to_write, // tag to store into cache on miss
    output reg [31:0] data_to_write,// data to store (simulated RAM fetch)

    // ── To lru_controller ────────────────────────────────────
    output reg        lru_update_en, // pulse: update LRU counters now
    output reg [1:0]  lru_used_way,  // tell LRU which way was used

    // ── To stats_display / LEDs ───────────────────────────────
    output reg        cache_hit_out,  // 1-cycle pulse on hit
    output reg        cache_miss_out  // 1-cycle pulse on miss
);

    // -------------------------------------------------------------------------
    // State encoding (one-hot would also work but binary is fine at this scale)
    // -------------------------------------------------------------------------
    localparam IDLE        = 3'd0;
    localparam LOOKUP      = 3'd1;
    localparam HIT_UPDATE  = 3'd2;
    localparam MISS_EVICT  = 3'd3;
    localparam MISS_LOAD   = 3'd4;

    reg [2:0] state, next_state;

    // -------------------------------------------------------------------------
    // Latched address fields
    // We latch these in LOOKUP so they don't change mid-transaction if the
    // user moves the switches while the FSM is running.
    // -------------------------------------------------------------------------
    reg [11:0] tag_latch;
    reg [1:0]  index_latch;
    reg [1:0]  way_latch;    // which way to evict (resolved in MISS_EVICT)

    // -------------------------------------------------------------------------
    // STATE REGISTER  (sequential, clocked)
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            tag_latch   <= 12'd0;
            index_latch <= 2'd0;
            way_latch   <= 2'd0;
        end
        else begin
            state <= next_state;

            // Latch the address fields exactly once, at the start of LOOKUP
            // so the rest of the pipeline sees a stable address.
            if (state == IDLE && access_req) begin
                tag_latch   <= tag_decoded;
                index_latch <= index_decoded;
            end

            // Latch the LRU way in MISS_EVICT (combinational lru_way can
            // change if index changes; we freeze it here before MISS_LOAD)
            if (state == MISS_EVICT) begin
                way_latch <= lru_way;
            end
        end
    end

    // -------------------------------------------------------------------------
    // NEXT-STATE + OUTPUT LOGIC  (combinational)
    //
    // Rule: every output must be assigned in EVERY branch to avoid latches.
    // Default all outputs to 0 at the top, override only in active states.
    // -------------------------------------------------------------------------
    always @(*) begin
        // ── Defaults (prevent latches) ────────────────────────────────────────
        next_state     = state;
        write_en       = 1'b0;
        way_sel        = 2'd0;
        tag_to_write   = 12'd0;
        data_to_write  = 32'd0;
        lru_update_en  = 1'b0;
        lru_used_way   = 2'd0;
        cache_hit_out  = 1'b0;
        cache_miss_out = 1'b0;

        case (state)

            // ── IDLE ─────────────────────────────────────────────────────────
            // Wait here doing nothing until the user presses the access button.
            IDLE: begin
                if (access_req)
                    next_state = LOOKUP;
                else
                    next_state = IDLE;
            end

            // ── LOOKUP ───────────────────────────────────────────────────────
            // Address is latched. tag_comparator runs combinationally using
            // tag_latch and index_latch wired from this module via top_module.
            // We simply read `hit` on the next clock edge to branch.
            //
            // Important: this state lasts exactly 1 cycle. The comparator is
            // combinational so its output is valid by the time we leave LOOKUP.
            LOOKUP: begin
                if (hit)
                    next_state = HIT_UPDATE;
                else
                    next_state = MISS_EVICT;
            end

            // ── HIT_UPDATE ───────────────────────────────────────────────────
            // Data is already in the cache. Signal the hit, then update LRU
            // so the matched way becomes the most-recently-used.
            HIT_UPDATE: begin
                cache_hit_out = 1'b1;       // pulse to stats + LED
                lru_update_en = 1'b1;       // update LRU counters
                lru_used_way  = hit_way;    // the way that was just accessed
                next_state    = IDLE;       // done in 1 cycle
            end

            // ── MISS_EVICT ───────────────────────────────────────────────────
            // Cache miss. Signal the miss. Read lru_way from LRU controller
            // (combinational output). We freeze it into way_latch this cycle
            // (handled in the sequential block above). Then move to MISS_LOAD.
            MISS_EVICT: begin
                cache_miss_out = 1'b1;      // pulse to stats + LED
                next_state     = MISS_LOAD;
            end

            // ── MISS_LOAD ────────────────────────────────────────────────────
            // Write the new cache line into the evicted way.
            //
            // data_to_write: In a real system this would come from a RAM read.
            // Here we simulate RAM data as {tag_latch, index_latch, 18'd0} —
            // deterministic, predictable, and makes testbench verification easy.
            // In hardware you'd add a MEM_FETCH state that waits for DDR2 data.
            //
            // After writing, update LRU: the newly loaded way is now freshest.
            MISS_LOAD: begin
                write_en      = 1'b1;
                way_sel       = way_latch;              // evict this way
                tag_to_write  = tag_latch;
                data_to_write = {tag_latch, index_latch, 18'd0}; // simulated data
                lru_update_en = 1'b1;
                lru_used_way  = way_latch;  // just loaded → treat as most recent
                next_state    = IDLE;
            end

            default: next_state = IDLE;

        endcase
    end

endmodule
