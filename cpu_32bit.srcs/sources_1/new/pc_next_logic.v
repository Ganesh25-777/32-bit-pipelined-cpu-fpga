`timescale 1ns / 1ps

module pc_next_logic(

    input  [31:0] current_pc,

    // =====================================================
    // STALL CONTROL
    // =====================================================

    input stall,

    // =====================================================
    // BRANCH CONTROL
    // =====================================================

    input branch_taken,
    input [31:0] branch_target,

    // =====================================================
    // JUMP CONTROL
    // =====================================================

    input jump,
    input [31:0] jump_target,

    output [31:0] next_pc

);

    // =====================================================
    // NEXT PC SELECTION
    //
    // Priority:
    //
    // 1. Taken branch
    // 2. Jump
    // 3. Stall
    // 4. Normal PC + 4
    //
    // =====================================================

    assign next_pc =
            branch_taken ? branch_target :
            jump         ? jump_target   :
            stall        ? current_pc    :
                           current_pc + 32'd4;

endmodule