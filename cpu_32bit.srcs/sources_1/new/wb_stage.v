`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.09.2026 15:24:49
// Design Name: 
// Module Name: wb_stage
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
`timescale 1ns / 1ps

/*
===============================================================================
                              WB STAGE
===============================================================================

PURPOSE:
--------
The WB (Write Back) stage is the final stage of the pipeline.

It selects the data that must be written back into the Register File.

MemToReg:
----------
    0 → Write ALU result
    1 → Write Data Memory result


RegWrite:
---------
    0 → Do not write to Register File
    1 → Write data into Register File

===============================================================================
*/

module wb_stage(

    // =====================================================
    // Inputs from MEM/WB Pipeline Register
    // =====================================================

    input  [31:0] wb_alu_result,
    input  [31:0] wb_read_data,

    input         wb_MemToReg,
    input         wb_RegWrite,

    input  [4:0]  wb_destination_reg,


    // =====================================================
    // Outputs to Register File
    // =====================================================

    output [31:0] wb_write_data,
    output [4:0]  wb_write_reg,
    output        wb_reg_write

);


    // =====================================================
    // WRITE-BACK DATA MUX
    // =====================================================
    //
    // MemToReg = 0 → ALU result
    // MemToReg = 1 → Data Memory result
    //
    // Example:
    //
    // ADD → ALU result → Register File
    //
    // LW  → Memory data → Register File
    // =====================================================

    assign wb_write_data =
            wb_MemToReg ? wb_read_data : wb_alu_result;


    // =====================================================
    // DESTINATION REGISTER
    // =====================================================
    //
    // The destination register was already selected
    // earlier in the EX stage.
    //
    // WB simply passes it to the Register File.
    // =====================================================

    assign wb_write_reg =
            wb_destination_reg;


    // =====================================================
    // REGISTER WRITE ENABLE
    // =====================================================
    //
    // RegWrite = 1 → Register File writes the data
    // RegWrite = 0 → No write
    // =====================================================

    assign wb_reg_write =
            wb_RegWrite;


endmodule
