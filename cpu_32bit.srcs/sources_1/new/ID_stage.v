`timescale 1ns / 1ps

module id_stage(
    input clk,
    input reset,

    // =====================================================
    // FROM IF/ID REGISTER
    // =====================================================

    input [31:0] current_pc,
    input [31:0] instruction,

    // =====================================================
    // DATA FROM REGISTER FILE
    // =====================================================

    input [31:0] read_data1,
    input [31:0] read_data2,

    output [31:0] id_current_pc,

    // =====================================================
    // REGISTER NUMBERS TO REGISTER FILE
    // =====================================================

    output [4:0] rs,
    output [4:0] rt,

    // =====================================================
    // REGISTER DATA
    // =====================================================

    output [31:0] id_read_data1,
    output [31:0] id_read_data2,

    // =====================================================
    // OUTPUTS TO ID/EX REGISTER
    // =====================================================

    output [31:0] immediate_out,
    output [25:0] target,
    output [4:0] rd,

    // =====================================================
    // CONTROL SIGNALS
    // =====================================================

    output RegDst,
    output RegWrite,
    output ALUSecondData,

    output MemRead,
    output MemWrite,
    output MemToReg,

    output Branch,

    // 0 = BEQZ
    // 1 = BNEQZ
    output BranchNotEqual,

    output Jump,
    output Halt,

    output [4:0] ALUControl,

    // =====================================================
    // REGISTER USAGE FOR STALL DETECTION
    // =====================================================

    output id_uses_rs,
    output id_uses_rt

);

    // =====================================================
    // INTERNAL SIGNALS
    // =====================================================

    wire [5:0] opcode;
    wire [15:0] immediate;


    // =====================================================
    // 1. INSTRUCTION DECODER
    // =====================================================

    instruction_decoder decoder_inst(

        .instruction(instruction),

        .opcode(opcode),
        .rs(rs),
        .rt(rt),
        .rd(rd),
        .immediate(immediate),
        .target(target)

    );


    // =====================================================
    // 2. CONTROL UNIT
    // =====================================================

    control_unit control_unit_inst(

        .opcode(opcode),

        .RegDst(RegDst),
        .RegWrite(RegWrite),
        .ALUSecondData(ALUSecondData),

        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .MemToReg(MemToReg),

        .Branch(Branch),
        .BranchNotEqual(BranchNotEqual),

        .Jump(Jump),
        .Halt(Halt),

        .ALUControl(ALUControl),

        .id_uses_rs(id_uses_rs),
        .id_uses_rt(id_uses_rt)

    );


    // =====================================================
    // 3. IMMEDIATE GENERATOR
    // =====================================================

   immediate_generator immediate_generator_inst(

    .immediate(immediate),
    .opcode(opcode),
    .immediate_out(immediate_out)

);


    // =====================================================
    // 4. PASS PC
    // =====================================================

    assign id_current_pc = current_pc;


    // =====================================================
    // 5. REGISTER DATA
    // =====================================================

    assign id_read_data1 = read_data1;
    assign id_read_data2 = read_data2;


endmodule