`timescale 1ns / 1ps

module ex_stage(

    // =====================================================
    // CLOCK (NEW - needed by the late-result multiplier)
    // =====================================================

    input         clk,

    // =====================================================
    // DATA FROM ID/EX REGISTER
    // =====================================================

    input  [31:0] ex_pc,
    input  [31:0] ex_read_data1,
    input  [31:0] ex_read_data2,
    input  [31:0] ex_immediate,

    // =====================================================
    // REGISTER NUMBERS
    // =====================================================

    input [4:0] ex_rt,
    input [4:0] ex_rd,
    input [4:0] ex_rs,

    // =====================================================
    // CONTROL SIGNALS
    // =====================================================

    input        ex_RegDst,
    input        ex_RegWrite,
    input        ex_ALUSecondData,

    input  [4:0] ex_ALUControl,

    input        ex_MemRead,
    input        ex_MemWrite,
    input        ex_MemToReg,

    input        ex_Branch,
    input        ex_BranchNotEqual,

    input        ex_Jump,
    input        ex_Halt,

    // =====================================================
    // JUMP TARGET
    // =====================================================

    input [25:0] ex_target,

    // =====================================================
    // FORWARDING CONTROL
    //
    // 00 -> Register File value
    // 10 -> EX/MEM ALU result
    // 01 -> MEM/WB write-back value
    // =====================================================

    input [1:0]  forwardA,
    input [1:0]  forwardB,

    input [31:0] mem_forward_data,
    input [31:0] wb_forward_data,

    // =====================================================
    // OUTPUTS FROM EX STAGE
    // =====================================================

    output [31:0] alu_result,
    output [4:0]  destination_reg,

    // =====================================================
    // BRANCH OUTPUTS
    // =====================================================

    output        branch_taken,
    output [31:0] branch_target,

    // =====================================================
    // JUMP OUTPUTS
    // =====================================================

    output        jump_taken,
    output [31:0] jump_target,
    output        halt_taken,

    // =====================================================
    // FLUSH OUTPUT
    //
    // Activated when branch or jump is taken
    // =====================================================

    output        flush,

    // =====================================================
    // SIGNALS PASSED TO EX/MEM REGISTER
    // =====================================================

    output [31:0] mem_read_data2,

    output        mem_RegWrite,
    output        mem_MemRead,
    output        mem_MemWrite,
    output        mem_MemToReg,

    // =====================================================
    // MULTIPLIER INTERFACE (NEW)
    //
    // ex_is_mul   : a valid MUL instruction is in EX now
    //               -> connect to stalling_unit.ex_is_mul
    // mul_in_mem  : a MUL instruction is in MEM now
    // mul_product : its result, valid when mul_in_mem = 1
    //               -> mux into the MEM/WB ALU-result input:
    //                  mul_in_mem ? mul_product : <old value>
    // =====================================================

    output        ex_is_mul,
    output        mul_in_mem,
    output [31:0] mul_product

);

    // =====================================================
    // INTERNAL SIGNALS
    // =====================================================

    wire [31:0] forwarded_data1;
    wire [31:0] forwarded_data2;

    wire [31:0] alu_operand_b;

    wire [31:0] pc_plus_4;


    // =====================================================
    // PC + 4
    // =====================================================

    assign pc_plus_4 = ex_pc + 32'd4;


    // =====================================================
    // FORWARDING - OPERAND A
    // =====================================================

    assign forwarded_data1 =
            (forwardA == 2'b10) ? mem_forward_data :
            (forwardA == 2'b01) ? wb_forward_data  :
                                  ex_read_data1;


    // =====================================================
    // FORWARDING - OPERAND B
    // =====================================================

    assign forwarded_data2 =
            (forwardB == 2'b10) ? mem_forward_data :
            (forwardB == 2'b01) ? wb_forward_data  :
                                  ex_read_data2;


    // =====================================================
    // ALU INPUT B MUX
    // =====================================================

    alu_input_mux ALU_INPUT_MUX (

        .read_data2(forwarded_data2),
        .immediate(ex_immediate),
        .ALUSecondData(ex_ALUSecondData),
        .alu_input_b(alu_operand_b)

    );


    // =====================================================
    // ALU
    // =====================================================

    alu ALU_UNIT (

        .alu_input_a(forwarded_data1),
        .alu_input_b(alu_operand_b),

        .ALUControl(ex_ALUControl),

        .alu_result(alu_result)

    );


    // =====================================================
    // MULTIPLIER (late result, completes in MEM stage)
    //
    // ex_RegWrite is part of the condition so that a bubble
    // that still carries a stale ALUControl can never look
    // like a MUL (that would stall forever).
    // =====================================================

    assign ex_is_mul = ex_RegWrite && (ex_ALUControl == 5'b00101);

    mul_unit MUL_UNIT (

        .clk(clk),
        .start(ex_is_mul),
        .a(forwarded_data1),
        .b(alu_operand_b),

        .busy_mem(mul_in_mem),
        .product(mul_product)

    );


    // =====================================================
    // DESTINATION REGISTER
    // =====================================================

    assign destination_reg =
            ex_RegDst ? ex_rd : ex_rt;


    // =====================================================
    // BRANCH DECISION
    //
    // BEQZ:
    //   Branch = 1
    //   BranchNotEqual = 0
    //   Taken when RS == 0
    //
    // BNEQZ:
    //   Branch = 1
    //   BranchNotEqual = 1
    //   Taken when RS != 0
    //
    // forwarded_data1 is used so that a recent ALU result
    // can be used immediately by the branch.
    // =====================================================

    assign branch_taken =
            ex_Branch &&
            (
                (!ex_BranchNotEqual &&
                 (forwarded_data1 == 32'b0))

                ||

                (ex_BranchNotEqual &&
                 (forwarded_data1 != 32'b0))
            );


    // =====================================================
    // BRANCH TARGET
    //
    // target = PC + 4 + (immediate << 2)
    // =====================================================

    assign branch_target =
            pc_plus_4 + (ex_immediate << 2);


    // =====================================================
    // JUMP
    //
    // jump_target =
    // {PC+4[31:28], target[25:0], 2'b00}
    // =====================================================

    assign jump_taken =
            ex_Jump;


    assign jump_target =
            {pc_plus_4[31:28], ex_target, 2'b00};


    // =====================================================
    // FLUSH
    //
    // Branch taken OR Jump OR Halt
    // =====================================================

    assign halt_taken = ex_Halt;

    assign flush =
        branch_taken | jump_taken | halt_taken;


    // =====================================================
    // SIGNALS PASSED TO EX/MEM
    // =====================================================

    // For SW, pass the forwarded RT value
    assign mem_read_data2 =
            forwarded_data2;


    // =====================================================
    // CONTROL SIGNALS TO EX/MEM
    // =====================================================

    assign mem_RegWrite =
            ex_RegWrite;

    assign mem_MemRead =
            ex_MemRead;

    assign mem_MemWrite =
            ex_MemWrite;

    assign mem_MemToReg =
            ex_MemToReg;

endmodule
