`timescale 1ns / 1ps

module mem_stage(

    input clk,

    // =====================================================
    // INPUTS FROM EX/MEM REGISTER
    // =====================================================

    input [31:0] mem_alu_result,
    input [31:0] mem_read_data2,

    input        mem_MemRead,
    input        mem_MemWrite,

    // =====================================================
    // OUTPUT FROM DATA MEMORY
    // =====================================================

    output [31:0] memory_data

);

    // =====================================================
    // DATA MEMORY
    // =====================================================

    data_memory DATA_MEMORY_UNIT (

        .clk(clk),

        .MemRead(mem_MemRead),
        .MemWrite(mem_MemWrite),

        .address(mem_alu_result),
        .write_data(mem_read_data2),

        .read_data(memory_data)

    );

endmodule