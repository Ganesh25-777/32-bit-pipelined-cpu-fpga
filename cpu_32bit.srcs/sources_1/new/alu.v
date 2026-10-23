`timescale 1ns / 1ps

module alu(
    input  [31:0] alu_input_a,
    input  [31:0] alu_input_b,
    input  [4:0]  ALUControl,
    output reg [31:0] alu_result
);

    // =====================================================
    // ADD / SUBTRACT
    // =====================================================

    wire is_sub;
    wire [31:0] arithmetic_b;
    wire [32:0] arithmetic_result;

    assign is_sub = (ALUControl == 5'b00001);

    assign arithmetic_b = alu_input_b ^ {32{is_sub}};

    assign arithmetic_result =
        {1'b0, alu_input_a} +
        {1'b0, arithmetic_b} +
        is_sub;


    // =====================================================
    // ALU OPERATIONS
    //
    // MUL (5'b00101) is NOT computed here any more.
    // It is done by mul_unit one cycle later (in the MEM stage),
    // so this ALU only returns 0 for it. The real product is
    // inserted into the MEM/WB register in cpu_top.
    // =====================================================

    always @(*) begin

        alu_result = 32'b0;

        case (ALUControl)

            // ADD
            5'b00000: begin
                alu_result = arithmetic_result[31:0];
            end

            // SUB
            5'b00001: begin
                alu_result = arithmetic_result[31:0];
            end

            // AND
            5'b00010: begin
                alu_result = alu_input_a & alu_input_b;
            end

            // OR
            5'b00011: begin
                alu_result = alu_input_a | alu_input_b;
            end

            // SIGNED SLT
            5'b00100: begin
                alu_result =
                    ($signed(alu_input_a) <
                     $signed(alu_input_b)) ? 32'd1 : 32'd0;
            end

            // MUL: handled by mul_unit (late result)
            5'b00101: begin
                alu_result = 32'b0;
            end

            // MOV: PASS A
            5'b01000: begin
                alu_result = alu_input_a;
            end

            // MOVI: PASS B
            5'b01001: begin
                alu_result = alu_input_b;
            end

            // INVALID OPCODE
            default: begin
                alu_result = 32'b0;
            end

        endcase

    end

endmodule
