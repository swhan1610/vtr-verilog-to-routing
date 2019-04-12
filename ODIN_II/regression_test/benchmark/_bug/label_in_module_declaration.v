// DEFINES
`define BITS 32         // Bit width of the operands

module main_label_in_module_declaration(
    clk,
    in,
    out
);
    input clk;
    input [`BITS-1:0] in;
    output [`BITS-1:0] out;

    label_in_module_declaration module1(clk, in, out);
  
endmodule

// `define BITS 64         // Bit width of the operands

module label_in_module_declaration(
    input clk,
    input [`BITS-1:0] in,
    output [`BITS-1:0] out
);
  
    always @(posedge clk)
    begin
        out <= in;
    end
  
endmodule