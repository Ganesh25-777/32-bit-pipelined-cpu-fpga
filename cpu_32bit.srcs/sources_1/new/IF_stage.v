`timescale 1ns / 1ps

module if_stage(

    input clk,
    input reset,
    input        imem_write_enable,
    input [11:0]  imem_write_address,
    input [31:0] imem_write_data,

    // =====================================================
    // STALL CONTROL
    // =====================================================

    input stall,

    // =====================================================
    // BRANCH CONTROL
    // =====================================================

    input        branch_taken,
    input [31:0] branch_target,

    // =====================================================
    // JUMP CONTROL
    // =====================================================

    input        jump,
    input [31:0] jump_target,

    // =====================================================
    // OUTPUTS
    // =====================================================

    output [31:0] current_pc,
    output [31:0] instruction

);

    wire [31:0] next_pc;

    // =====================================================
    // 1. PROGRAM COUNTER
    // =====================================================

    program_counter PC_UNIT (

        .clk(clk),
        .reset(reset),

        .next_pc(next_pc),

        .current_pc(current_pc)

    );

    // =====================================================
    // 2. INSTRUCTION MEMORY
    // =====================================================

    ins_mem IMEM_UNIT (
    
        .clk(clk),
    
        .current_pc(current_pc),
        .instruction(instruction),
    
        .write_enable(imem_write_enable),
        .write_address(imem_write_address),
        .write_data(imem_write_data)
    
    );
    // =====================================================
    // 3. NEXT PC LOGIC
    // =====================================================

    pc_next_logic PC_NEXT (

        .current_pc(current_pc),

        .stall(stall),

        .branch_taken(branch_taken),
        .branch_target(branch_target),

        .jump(jump),
        .jump_target(jump_target),

        .next_pc(next_pc)

    );

endmodule