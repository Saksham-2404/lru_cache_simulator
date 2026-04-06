module tag_comparator(

    input  [11:0] tag_in,             // incoming tag from addr_decoder
    input  [11:0] tag_stored [0:3],   // 4 tags from cache (1 set, 4 ways)
    input  [3:0]  valid_bits,         // valid bits of 4 ways

    output reg hit,                  // hit or miss
    output reg [1:0] hit_way         // which way matched
);

    always @(*) begin
        // default values (VERY IMPORTANT to avoid latches)
        hit = 0;
        hit_way = 2'b00;

        // Check each way
        if ((tag_in == tag_stored[0]) && valid_bits[0]) begin
            hit = 1;
            hit_way = 2'd0;
        end
        else if ((tag_in == tag_stored[1]) && valid_bits[1]) begin
            hit = 1;
            hit_way = 2'd1;
        end
        else if ((tag_in == tag_stored[2]) && valid_bits[2]) begin
            hit = 1;
            hit_way = 2'd2;
        end
        else if ((tag_in == tag_stored[3]) && valid_bits[3]) begin
            hit = 1;
            hit_way = 2'd3;
        end
    end

endmodule
