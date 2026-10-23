`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.09.2026 14:51:36
// Design Name: 
// Module Name: mem_wb_reg
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

/*
===============================================================================
                         MEM/WB PIPELINE REGISTER
===============================================================================

PURPOSE:
--------
The MEM/WB register is the pipeline register between the MEM stage
and the WB (Write Back) stage.

It stores the outputs of the MEM stage at the rising edge of the
clock and passes them to the WB stage during the next clock cycle.

INPUTS FROM MEM STAGE:
----------------------

1. mem_alu_result
   - ALU result produced in the EX stage.
   - Used by normal ALU instructions such as ADD, SUB, AND, OR, etc.
   - For LW/SW, this contains the calculated memory address.

2. mem_read_data
   - Data read from Data Memory.
   - Used by LW instructions.

3. mem_destination_reg
   - Register number that will receive the result in the WB stage.

4. mem_RegWrite
   - Tells the WB stage whether the Register File must be written.

5. mem_MemToReg
   - Selects which value should be written to the Register File:
       0 -> ALU result
       1 -> Data Memory result

OUTPUTS TO WB STAGE:
--------------------

The register stores the MEM-stage information and forwards it
to the WB stage on the next clock cycle.

DATA FLOW:
----------

       MEM STAGE OUTPUTS
              │
              ↓
     ┌───────────────────┐
     │      MEM/WB        │
     │     REGISTER       │
     └───────────────────┘
              │
              ↓
        WB STAGE INPUTS
For ADD:

    ALU result → MEM/WB → WB → Register File

For LW:

    Data Memory → MEM/WB → WB → Register File

For SW:

    Data Memory is written during MEM.
    RegWrite = 0, so nothing is written back.

IMPORTANT:
----------
This module does not perform any calculation.

It only stores and forwards data and control signals between
the MEM and WB stages.

===============================================================================
*/

module mem_wb_register(

    input clk,
    input reset,

    // =====================================================
    // DATA FROM MEM STAGE
    // =====================================================

    input [31:0] mem_alu_result,
    input [31:0] mem_read_data,
    input [4:0]  mem_destination_reg,

    // =====================================================
    // CONTROL SIGNALS FROM MEM STAGE
    // =====================================================

    input mem_RegWrite,
    input mem_MemToReg,

    // =====================================================
    // DATA TO WB STAGE
    // =====================================================

    output reg [31:0] wb_alu_result,
    output reg [31:0] wb_read_data,
    output reg [4:0]  wb_destination_reg,

    // =====================================================
    // CONTROL SIGNALS TO WB STAGE
    // =====================================================

    output reg wb_RegWrite,
    output reg wb_MemToReg

);


    // =====================================================
    // PIPELINE REGISTER
    // =====================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            // -------------------------------------------------
            // Reset data
            // -------------------------------------------------

            wb_alu_result      <= 32'b0;
            wb_read_data       <= 32'b0;

            // -------------------------------------------------
            // Reset destination register
            // -------------------------------------------------

            wb_destination_reg <= 5'b0;

            // -------------------------------------------------
            // Reset control signals
            // -------------------------------------------------

            wb_RegWrite        <= 1'b0;
            wb_MemToReg        <= 1'b0;

        end

        else begin

            // -------------------------------------------------
            // Store MEM-stage data
            // -------------------------------------------------

            wb_alu_result      <= mem_alu_result;
            wb_read_data       <= mem_read_data;

            // -------------------------------------------------
            // Store destination register
            // -------------------------------------------------

            wb_destination_reg <= mem_destination_reg;

            // -------------------------------------------------
            // Store control signals
            // -------------------------------------------------

            wb_RegWrite        <= mem_RegWrite;
            wb_MemToReg        <= mem_MemToReg;

        end

    end

endmodule
