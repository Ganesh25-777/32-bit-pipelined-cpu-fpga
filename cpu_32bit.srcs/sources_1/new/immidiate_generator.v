`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.09.2026 18:04:25
// Design Name: 
// Module Name: immidiate_generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module immediate_generator(
    input  [15:0] immediate,
    input  [5:0] opcode,

    output [31:0] immediate_out
);

assign immediate_out =
    (opcode == 6'b001111) ?
    {16'b0, immediate} :              // MOVI → zero extension
    {{16{immediate[15]}}, immediate};  // Others → sign extension

endmodule