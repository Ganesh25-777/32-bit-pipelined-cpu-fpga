`timescale 1ns / 1ps

module ex_mem_register(

    input clk,
    input reset,

    // =====================================================
    // DATA FROM EX STAGE
    // =====================================================

    input [31:0] alu_result,
    input [31:0] read_data2,

    // =====================================================
    // DESTINATION REGISTER
    // =====================================================

    input [4:0] destination_reg,

    // =====================================================
    // CONTROL SIGNALS FROM EX STAGE
    // =====================================================

    input MemRead,
    input MemWrite,
    input MemToReg,
    input RegWrite,

    // =====================================================
    // OUTPUTS TO MEM STAGE
    // =====================================================

    output reg [31:0] mem_alu_result,
    output reg [31:0] mem_read_data2,

    output reg [4:0] mem_destination_reg,

    output reg mem_MemRead,
    output reg mem_MemWrite,
    output reg mem_MemToReg,
    output reg mem_RegWrite

);


always @(posedge clk or posedge reset) begin

    // =====================================================
    // RESET
    // =====================================================

    if (reset) begin

        mem_alu_result      <= 32'b0;
        mem_read_data2      <= 32'b0;
        mem_destination_reg <= 5'b0;

        mem_MemRead         <= 1'b0;
        mem_MemWrite        <= 1'b0;
        mem_MemToReg        <= 1'b0;
        mem_RegWrite        <= 1'b0;

    end

    // =====================================================
    // NORMAL OPERATION
    // =====================================================

    else begin

        mem_alu_result      <= alu_result;
        mem_read_data2      <= read_data2;
        mem_destination_reg <= destination_reg;

        mem_MemRead         <= MemRead;
        mem_MemWrite        <= MemWrite;
        mem_MemToReg        <= MemToReg;
        mem_RegWrite        <= RegWrite;

    end

end

endmodule