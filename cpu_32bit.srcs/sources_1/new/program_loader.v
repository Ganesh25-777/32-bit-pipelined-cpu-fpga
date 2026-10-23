`timescale 1ns / 1ps

module program_loader (
    input clk,
    input reset,

    // External program loading interface
    input        load_enable,
    input [4:0]  load_address,
    input [31:0] load_data,
    input        load_done,

    // Connections to instruction memory
    output        write_enable,
    output [4:0]  write_address,
    output [31:0] write_data,

    // Indicates that the CPU can start
    output reg program_loaded
);

    // Pass external programming signals directly to instruction memory
    assign write_enable  = load_enable;
    assign write_address = load_address;
    assign write_data    = load_data;

    // Program loading status
    always @(posedge clk or posedge reset) begin

        if (reset) begin
            program_loaded <= 1'b0;
        end

        else if (load_done) begin
            program_loaded <= 1'b1;
        end

    end

endmodule