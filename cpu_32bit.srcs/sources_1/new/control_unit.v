`timescale 1ns / 1ps

module control_unit(
    input  [5:0] opcode,

    output reg RegDst,
    output reg RegWrite,
    output reg ALUSecondData,

    output reg MemRead,
    output reg MemWrite,
    output reg MemToReg,

    output reg Branch,

    // 0 = BEQZ
    // 1 = BNEQZ
    output reg BranchNotEqual,

    output reg Jump,
    output reg Halt,

    output reg [4:0] ALUControl,

    // =================================================
    // REGISTER USAGE FOR STALL DETECTION
    // =================================================

    output reg id_uses_rs,
    output reg id_uses_rt
);

always @(*) begin

    // =================================================
    // DEFAULT VALUES
    // =================================================

    RegDst         = 1'b0;
    RegWrite       = 1'b0;
    ALUSecondData  = 1'b0;

    MemRead        = 1'b0;
    MemWrite       = 1'b0;
    MemToReg       = 1'b0;

    Branch         = 1'b0;
    BranchNotEqual = 1'b0;

    Jump           = 1'b0;
    Halt           = 1'b0;

    ALUControl     = 5'b00000;

    id_uses_rs     = 1'b0;
    id_uses_rt     = 1'b0;


    case (opcode)

        // =================================================
        // R-TYPE
        // =================================================

        6'b000000: begin       // ADD
            RegDst        = 1'b1;
            RegWrite      = 1'b1;
            ALUSecondData = 1'b0;
            ALUControl    = 5'b00000;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b1;
        end

        6'b000001: begin       // SUB
            RegDst        = 1'b1;
            RegWrite      = 1'b1;
            ALUSecondData = 1'b0;
            ALUControl    = 5'b00001;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b1;
        end

        6'b000010: begin       // AND
            RegDst        = 1'b1;
            RegWrite      = 1'b1;
            ALUSecondData = 1'b0;
            ALUControl    = 5'b00010;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b1;
        end

        6'b000011: begin       // OR
            RegDst        = 1'b1;
            RegWrite      = 1'b1;
            ALUSecondData = 1'b0;
            ALUControl    = 5'b00011;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b1;
        end

        6'b000100: begin       // SLT
            RegDst        = 1'b1;
            RegWrite      = 1'b1;
            ALUSecondData = 1'b0;
            ALUControl    = 5'b00100;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b1;
        end

        6'b000101: begin       // MUL
            RegDst        = 1'b1;
            RegWrite      = 1'b1;
            ALUSecondData = 1'b0;
            ALUControl    = 5'b00101;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b1;
        end
       6'b000111: begin      //MOV
          RegDst        = 1'b1;
          RegWrite      = 1'b1;
          ALUSecondData = 1'b0;

          ALUControl    = 5'b01000;   // PASS A

         id_uses_rs    = 1'b1;
         id_uses_rt    = 1'b0;
       end

        // =================================================
        // I-TYPE
        // =================================================

        6'b001000: begin       // LW
            RegDst        = 1'b0;
            RegWrite      = 1'b1;
            ALUSecondData = 1'b1;
            MemRead       = 1'b1;
            MemToReg      = 1'b1;
            ALUControl    = 5'b00000;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b0;
        end

        6'b001001: begin       // SW
            RegWrite      = 1'b0;
            ALUSecondData = 1'b1;
            MemWrite      = 1'b1;
            ALUControl    = 5'b00000;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b1;
        end

        6'b001010: begin       // ADDI
            RegDst        = 1'b0;
            RegWrite      = 1'b1;
            ALUSecondData = 1'b1;
            ALUControl    = 5'b00000;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b0;
        end

        6'b001011: begin       // SUBI
            RegDst        = 1'b0;
            RegWrite      = 1'b1;
            ALUSecondData = 1'b1;
            ALUControl    = 5'b00001;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b0;
        end

        6'b001100: begin       // SLTI
            RegDst        = 1'b0;
            RegWrite      = 1'b1;
            ALUSecondData = 1'b1;
            ALUControl    = 5'b00100;

            id_uses_rs    = 1'b1;
            id_uses_rt    = 1'b0;
        end


        // =================================================
        // BRANCH
        // =================================================

        6'b001101: begin       // BNEQZ
            RegWrite       = 1'b0;
            ALUSecondData  = 1'b0;

            Branch         = 1'b1;
            BranchNotEqual = 1'b1;

            id_uses_rs     = 1'b1;
            id_uses_rt     = 1'b0;
        end

        6'b001110: begin       // BEQZ
            RegWrite       = 1'b0;
            ALUSecondData  = 1'b0;

            Branch         = 1'b1;
            BranchNotEqual = 1'b0;

            id_uses_rs     = 1'b1;
            id_uses_rt     = 1'b0;
        end
        
        6'b001111: begin  //MOVI
        RegDst        = 1'b0;
        RegWrite      = 1'b1;
        ALUSecondData = 1'b1;
    
        ALUControl    = 5'b01001;   // PASS B
    
        id_uses_rs    = 1'b0;
        id_uses_rt    = 1'b0;
    end

        // =================================================
        // JUMP
        // =================================================

        6'b010000: begin       // J
            RegWrite   = 1'b0;
            Jump       = 1'b1;

            id_uses_rs = 1'b0;
            id_uses_rt = 1'b0;
        end


        // =================================================
        // HALT
        // =================================================

        6'b111111: begin       // HLT
            RegWrite   = 1'b0;
            Halt       = 1'b1;

            id_uses_rs = 1'b0;
            id_uses_rt = 1'b0;
        end


        // =================================================
        // UNKNOWN OPCODE
        // =================================================

        default: begin
            RegDst         = 1'b0;
            RegWrite       = 1'b0;
            ALUSecondData  = 1'b0;

            MemRead        = 1'b0;
            MemWrite       = 1'b0;
            MemToReg       = 1'b0;

            Branch         = 1'b0;
            BranchNotEqual = 1'b0;

            Jump           = 1'b0;
            Halt           = 1'b0;

            ALUControl     = 5'b00000;

            id_uses_rs     = 1'b0;
            id_uses_rt     = 1'b0;
        end

    endcase

end

endmodule