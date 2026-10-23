`timescale 1ns / 1ps

// =====================================================================
// MUL UNIT (late result)
//
// Timeline for a MUL instruction:
//   cycle t   (MUL in EX ) : forwarded operands are captured in a_q / b_q
//   cycle t+1 (MUL in MEM) : product is computed from a_q / b_q and must
//                            be written into the MEM/WB register's
//                            ALU-result field instead of EX/MEM's value
//
// Result is therefore available at the same point as a LW result, so the
// stalling unit treats MUL like a load (1-cycle stall for a dependent
// instruction in the next slot).
//
// a_q / b_q have NO reset on purpose, so Vivado can absorb them into the
// DSP48 input registers. v_q uses an initial value, no reset needed:
// it follows 'start', which is 0 while the ID/EX register is in reset.
// =====================================================================
module mul_unit (
    input  wire        clk,
    input  wire        start,       // MUL instruction is in EX this cycle
    input  wire [31:0] a,           // forwarded operand A (EX stage)
    input  wire [31:0] b,           // ALU operand B      (EX stage)

    output wire        busy_mem,    // MUL instruction is in MEM this cycle
    output wire [31:0] product      // lower 32 bits of a*b, valid when busy_mem=1
);

    reg [31:0] a_q;
    reg [31:0] b_q;
    reg        v_q = 1'b0;

    always @(posedge clk) begin
        a_q <= a;
        b_q <= b;
        v_q <= start;
    end

    assign busy_mem = v_q;

    // -----------------------------------------------------------------
    // Lower 32 bits of the product from three 16x16 partial products
    // (same arithmetic as the original alu.v)
    // -----------------------------------------------------------------
    wire [31:0] mul_ll = {16'b0, a_q[15:0]}  * {16'b0, b_q[15:0]};
    wire [31:0] mul_lh = {16'b0, a_q[15:0]}  * {16'b0, b_q[31:16]};
    wire [31:0] mul_hl = {16'b0, a_q[31:16]} * {16'b0, b_q[15:0]};

    wire [15:0] mul_high = mul_ll[31:16] + mul_lh[15:0] + mul_hl[15:0];

    assign product = {mul_high, mul_ll[15:0]};

endmodule
