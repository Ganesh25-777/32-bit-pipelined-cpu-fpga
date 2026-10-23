`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.09.2026 16:41:57
// Design Name: 
// Module Name: alu_input_mux
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

`timescale 1ns / 1ps

module alu_input_mux(

    // Input from register file through ID/EX
    input  [31:0] read_data2,

    // Immediate value from ID/EX
    input  [31:0] immediate,

    // Control signal
    // 0 -> use register data
    // 1 -> use immediate
    input ALUSecondData,

    // Output to ALU
    output reg [31:0] alu_input_b

);

always @(*) begin

    if (ALUSecondData == 1'b0)
        alu_input_b = read_data2;

    else
        alu_input_b = immediate;

end

endmodule