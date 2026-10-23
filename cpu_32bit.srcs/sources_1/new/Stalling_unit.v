`timescale 1ns / 1ps

// =====================================================================
// STALLING UNIT
//
// Two "late result" producers need a 1-cycle stall when the very next
// instruction (in ID) needs their result:
//   1) LW  : result comes from data memory (destination = rt)
//   2) MUL : result comes from mul_unit in MEM (destination = rd)
//
// Both use the same stall + flush behaviour as before.
// =====================================================================
module stalling_unit(
    input [4:0] id_rs,
    input [4:0] id_rt,
    input       id_uses_rs,
    input       id_uses_rt,

    // load in EX
    input [4:0] ex_rt,
    input       ex_MemRead,

    // MUL in EX (NEW)
    input [4:0] ex_rd,
    input       ex_is_mul,

    output reg  stall,
    output reg  flush
);

always @(*) begin
    stall = 1'b0;
    flush = 1'b0;

    // ---------------- load-use hazard (unchanged) -----------------
    if (ex_MemRead &&
        (ex_rt != 5'd0) &&
        (
            (id_uses_rs && (id_rs == ex_rt)) ||
            (id_uses_rt && (id_rt == ex_rt))
        )) begin
        stall = 1'b1;
        flush = 1'b1;
    end

    // ---------------- MUL-use hazard (NEW) ------------------------
    if (ex_is_mul &&
        (ex_rd != 5'd0) &&
        (
            (id_uses_rs && (id_rs == ex_rd)) ||
            (id_uses_rt && (id_rt == ex_rd))
        )) begin
        stall = 1'b1;
        flush = 1'b1;
    end
end

endmodule
