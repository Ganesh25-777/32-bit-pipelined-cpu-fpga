`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.09.2026 14:28:13
// Design Name: 
// Module Name: data_memory
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
                           DATA MEMORY
===============================================================================

PURPOSE:
--------
This module implements the CPU's Data Memory.

It is used by:

    LW -> Read data from memory
    SW -> Write data into memory

Each memory location stores 32 bits (4 bytes).

Therefore, valid word-aligned addresses are:

    0, 4, 8, 12, 16, 20, ...

The address is converted into a memory index using address[11:2].

DATA FLOW:
----------

        address
           |
           ↓
    ┌───────────────┐
    │  DATA MEMORY  │
    │               │
    │ memory[index] │
    └───────┬───────┘
            |
            ↓
        read_data

For SW:
    address + write_data + MemWrite
                    ↓
                memory[index]

For LW:
    address + MemRead
          ↓
      memory[index]
          ↓
       read_data

===============================================================================
*/

module data_memory(

    input        clk,
    input        MemRead,
    input        MemWrite,

    input  [31:0] address,
    input  [31:0] write_data,

    output reg [31:0] read_data

);

    // =====================================================
    // 1024 WORDS × 32 BITS
    // =====================================================

    reg [31:0] memory [0:1023];


    // =====================================================
    // WRITE OPERATION
    // =====================================================
    // SW:
    // MemWrite = 1
    //
    // Address 0  → memory[0]
    // Address 4  → memory[1]
    // Address 8  → memory[2]
    // Address 12 → memory[3]
    // =====================================================

    always @(posedge clk) begin

        if (MemWrite)
            memory[address/4] <= write_data;

    end


    // =====================================================
    // READ OPERATION
    // =====================================================
    // LW:
    // MemRead = 1
    // =====================================================

    always @(*) begin

        if (MemRead)
            read_data = memory[address/4];
        else
            read_data = 32'b0;

    end

endmodule