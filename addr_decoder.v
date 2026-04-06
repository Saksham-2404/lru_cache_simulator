module addr_decoder(
    input  [15:0] addr,     // full 16-bit address

    output [11:0] tag,      // tag field
    output [1:0]  index,    // set selector
    output [1:0]  offset    // byte selector inside block
);

    // Address split (combinational logic)
    assign tag    = addr[15:4];  // upper 12 bits
    assign index  = addr[3:2];   // next 2 bits
    assign offset = addr[1:0];   // lowest 2 bits

endmodule
