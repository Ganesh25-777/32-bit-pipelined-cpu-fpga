`timescale 1ns / 1ps
module ins_mem (
    input clk,

    // CPU instruction read
    input  [31:0] current_pc,
    output reg [31:0] instruction,

    // Program loader write
    input         write_enable,
    input  [11:0]  write_address,
    input  [31:0] write_data
);

reg [31:0] memory [0:4095];

// WRITE PORT
always @(posedge clk) begin
    if (write_enable)
        memory[write_address] <= write_data;
end

// READ PORT
always @(*) begin
    instruction = memory[current_pc / 32'd4];
end

endmodule