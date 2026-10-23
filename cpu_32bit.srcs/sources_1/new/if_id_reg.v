module if_id_register(
    input clk,
    input reset,
    input flush,
    input stall,

    input  [31:0] current_pc,
    input  [31:0] instruction,

    output reg [31:0] id_pc,
    output reg [31:0] id_instruction
);

always @(posedge clk or posedge reset) begin

    if (reset) begin
        id_pc          <= 32'b0;
        id_instruction <= 32'b0;
    end

    else if (flush) begin
        id_pc          <= 32'b0;
        id_instruction <= 32'b0;
    end

    else if (stall) begin
        id_pc          <= id_pc;
        id_instruction <= id_instruction;
    end

    else begin
        id_pc          <= current_pc;
        id_instruction <= instruction;
    end

end
endmodule