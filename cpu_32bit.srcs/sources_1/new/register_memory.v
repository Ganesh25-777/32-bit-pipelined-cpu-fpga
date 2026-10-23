`timescale 1ns / 1ps

module register_file(
    input clk,
    input reset,

    // =====================================================
    // NORMAL READ PORTS
    // =====================================================

    input  [4:0]  rs,
    input  [4:0]  rt,
    output [31:0] read_data1,
    output [31:0] read_data2,

    // =====================================================
    // NORMAL WRITE PORT
    // =====================================================

    input  [4:0]  rd,
    input  [31:0] write_data,
    input        reg_write,

    // =====================================================
    // DEBUG / MONITOR READ PORT
    // =====================================================

    input  [4:0]  debug_reg_addr,
    output [31:0] debug_reg_data
);

reg [31:0] registers [0:31];

integer i;

// =====================================================
// REGISTER WRITE
// =====================================================

always @(posedge clk or posedge reset) begin

    if (reset) begin

        for (i = 0; i < 32; i = i + 1)
            registers[i] <= 32'b0;

    end

    else begin

        // Never write R0
        if (reg_write && (rd != 5'b00000))
            registers[rd] <= write_data;

    end

end

// =====================================================
// READ PORT 1 WITH WRITE-BACK BYPASS
// =====================================================

assign read_data1 =
        (rs == 5'b00000) ? 32'b0 :
        (reg_write && (rd != 5'b00000) && (rd == rs))
        ? write_data :
        registers[rs];

// =====================================================
// READ PORT 2 WITH WRITE-BACK BYPASS
// =====================================================

assign read_data2 =
        (rt == 5'b00000) ? 32'b0 :
        (reg_write && (rd != 5'b00000) && (rd == rt))
        ? write_data :
        registers[rt];

// =====================================================
// DEBUG / MONITOR READ
// =====================================================

assign debug_reg_data =
        (debug_reg_addr == 5'b00000)
        ? 32'b0
        : registers[debug_reg_addr];

endmodule