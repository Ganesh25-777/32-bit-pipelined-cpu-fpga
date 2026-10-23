
`timescale 1ns / 1ps

module forwarding_unit(
    input  [4:0] ex_rs,
    input  [4:0] ex_rt,

    input  [4:0] mem_destination_reg,
    input        mem_RegWrite,
    input        mem_MemToReg,

    input  [4:0] wb_destination_reg,
    input        wb_RegWrite,

    output reg [1:0] forwardA,
    output reg [1:0] forwardB
);

always @(*) begin
    forwardA = 2'b00;
    forwardB = 2'b00;

    // EX/MEM forwarding is for ALU results only.
    // Load results are forwarded from MEM/WB instead.
    if (mem_RegWrite &&
        !mem_MemToReg &&
        (mem_destination_reg != 5'd0) &&
        (mem_destination_reg == ex_rs)) begin
        forwardA = 2'b10;
    end
    else if (wb_RegWrite &&
             (wb_destination_reg != 5'd0) &&
             (wb_destination_reg == ex_rs)) begin
        forwardA = 2'b01;
    end

    if (mem_RegWrite &&
        !mem_MemToReg &&
        (mem_destination_reg != 5'd0) &&
        (mem_destination_reg == ex_rt)) begin
        forwardB = 2'b10;
    end
    else if (wb_RegWrite &&
             (wb_destination_reg != 5'd0) &&
             (wb_destination_reg == ex_rt)) begin
        forwardB = 2'b01;
    end
end

endmodule
