`timescale 1ns / 1ps

module id_ex_register(

    input clk,
    input reset,
    input flush,

    // =====================================================
    // DATA FROM ID STAGE
    // =====================================================

    input [31:0] current_pc,
    input [31:0] read_data1,
    input [31:0] read_data2,
    input [31:0] immediate_out,
    input [25:0] target,

    // =====================================================
    // REGISTER NUMBERS
    // =====================================================

    input [4:0] rs,
    input [4:0] rt,
    input [4:0] rd,

    // =====================================================
    // CONTROL SIGNALS FROM ID STAGE
    // =====================================================

    input RegDst,
    input RegWrite,
    input ALUSecondData,

    input [4:0] ALUControl,

    input MemRead,
    input MemWrite,
    input MemToReg,

    // Branch control
    input Branch,
    input BranchNotEqual,

    input Jump,
    input Halt,

    // =====================================================
    // OUTPUTS TO EX STAGE
    // =====================================================

    output reg [31:0] ex_pc,
    output reg [31:0] ex_read_data1,
    output reg [31:0] ex_read_data2,
    output reg [31:0] ex_immediate,

    // =====================================================
    // REGISTER NUMBERS TO EX STAGE
    // =====================================================

    output reg [4:0] ex_rs,
    output reg [4:0] ex_rt,
    output reg [4:0] ex_rd,

    // =====================================================
    // CONTROL SIGNALS TO EX STAGE
    // =====================================================

    output reg ex_RegDst,
    output reg ex_RegWrite,
    output reg ex_ALUSecondData,

    output reg [4:0] ex_ALUControl,

    output reg ex_MemRead,
    output reg ex_MemWrite,
    output reg ex_MemToReg,

    // Branch controls
    output reg ex_Branch,
    output reg ex_BranchNotEqual,

    output reg ex_Jump,
    output reg ex_Halt,

    // =====================================================
    // BRANCH / JUMP TARGET
    // =====================================================

    output reg [25:0] ex_target

);


always @(posedge clk or posedge reset) begin

    // =====================================================
    // RESET
    // =====================================================

    if (reset) begin

        // Data
        ex_pc            <= 32'b0;
        ex_read_data1    <= 32'b0;
        ex_read_data2    <= 32'b0;
        ex_immediate     <= 32'b0;

        // Register numbers
        ex_rs            <= 5'b0;
        ex_rt            <= 5'b0;
        ex_rd            <= 5'b0;

        // Control
        ex_RegDst        <= 1'b0;
        ex_RegWrite      <= 1'b0;
        ex_ALUSecondData <= 1'b0;

        ex_ALUControl    <= 5'b0;

        ex_MemRead       <= 1'b0;
        ex_MemWrite      <= 1'b0;
        ex_MemToReg      <= 1'b0;

        // Branch
        ex_Branch        <= 1'b0;
        ex_BranchNotEqual <= 1'b0;

        // Jump / Halt
        ex_Jump          <= 1'b0;
        ex_Halt          <= 1'b0;

        // Target
        ex_target        <= 26'b0;

    end

    // =====================================================
    // FLUSH
    // =====================================================

    else if (flush) begin

        // Insert a bubble into EX stage

        ex_pc            <= 32'b0;
        ex_read_data1    <= 32'b0;
        ex_read_data2    <= 32'b0;
        ex_immediate     <= 32'b0;

        ex_rs            <= 5'b0;
        ex_rt            <= 5'b0;
        ex_rd            <= 5'b0;

        ex_RegDst        <= 1'b0;
        ex_RegWrite      <= 1'b0;
        ex_ALUSecondData <= 1'b0;

        ex_ALUControl    <= 5'b0;

        ex_MemRead       <= 1'b0;
        ex_MemWrite      <= 1'b0;
        ex_MemToReg      <= 1'b0;

        ex_Branch        <= 1'b0;
        ex_BranchNotEqual <= 1'b0;

        ex_Jump          <= 1'b0;
        ex_Halt          <= 1'b0;

        ex_target        <= 26'b0;

    end

    // =====================================================
    // NORMAL OPERATION
    // =====================================================

    else begin

        // -------------------------------------------------
        // Data
        // -------------------------------------------------

        ex_pc            <= current_pc;
        ex_read_data1    <= read_data1;
        ex_read_data2    <= read_data2;
        ex_immediate     <= immediate_out;

        // -------------------------------------------------
        // Register numbers
        // -------------------------------------------------

        ex_rs            <= rs;
        ex_rt            <= rt;
        ex_rd            <= rd;

        // -------------------------------------------------
        // ALU control
        // -------------------------------------------------

        ex_RegDst        <= RegDst;
        ex_RegWrite      <= RegWrite;
        ex_ALUSecondData <= ALUSecondData;

        ex_ALUControl    <= ALUControl;

        // -------------------------------------------------
        // Memory control
        // -------------------------------------------------

        ex_MemRead       <= MemRead;
        ex_MemWrite      <= MemWrite;
        ex_MemToReg      <= MemToReg;

        // -------------------------------------------------
        // Branch control
        // -------------------------------------------------

        ex_Branch        <= Branch;
        ex_BranchNotEqual <= BranchNotEqual;

        // -------------------------------------------------
        // Jump / Halt
        // -------------------------------------------------

        ex_Jump          <= Jump;
        ex_Halt          <= Halt;

        // -------------------------------------------------
        // Branch / Jump target
        // -------------------------------------------------

        ex_target        <= target;

    end

end

endmodule