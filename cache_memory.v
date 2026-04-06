module cache_memory(
    input clk,

    input [1:0] index,       // which set
    input [1:0] way_sel,     // which way to write
    input write_en,

    input [11:0] tag_in,
    input [31:0] data_in,

    output reg [11:0] tag_out [0:3],
    output reg [31:0] data_out [0:3],
    output reg [3:0]  valid_out
);

    // Storage arrays
    reg [11:0] tags  [0:3][0:3];   // [set][way]
    reg [31:0] data  [0:3][0:3];
    reg        valid [0:3][0:3];

 

    integer i;

    // ---------------------------
    // READ LOGIC (combinational)
    // ---------------------------
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            tag_out[i]   = tags[index][i];
            data_out[i]  = data[index][i];
            valid_out[i] = valid[index][i];
        end
    end

    // ---------------------------
    // WRITE LOGIC (sequential)
    // ---------------------------
    always @(posedge clk) begin
        if (write_en) begin
            tags[index][way_sel]  <= tag_in;
            data[index][way_sel]  <= data_in;
            valid[index][way_sel] <= 1'b1;
        end
    end

endmodule
