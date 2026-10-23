`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.10.2026 17:00:32
// Design Name: 
// Module Name: uart_program_loader
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module uart_program_loader (

    input clk,
    input reset,

    // From UART RX
    input [7:0] uart_data,
    input       uart_data_valid,

    // To Instruction Memory
    output reg        write_enable,
    output reg [11:0]  write_address,
    output reg [31:0] write_data,

    // CPU start signal
    output reg program_loaded

);

    reg [1:0] byte_count;

    reg [31:0] instruction_buffer;

    reg [11:0] current_address;


    always @(posedge clk or posedge reset) begin

        if (reset) begin

            byte_count         <= 2'd0;
            instruction_buffer <= 32'd0;

            current_address    <= 5'd0;

            write_enable       <= 1'b0;
            write_address      <= 5'd0;
            write_data         <= 32'd0;

            program_loaded     <= 1'b0;

        end

        else begin

            // Default: write_enable is only HIGH for one clock
            write_enable <= 1'b0;


            // =================================================
            // RECEIVE UART BYTE
            // =================================================

            if (uart_data_valid && !program_loaded) begin

                case (byte_count)

                    // -----------------------------------------
                    // BYTE 0
                    // -----------------------------------------

                    2'd0: begin

                        instruction_buffer[31:24] <= uart_data;

                        byte_count <= 2'd1;

                    end


                    // -----------------------------------------
                    // BYTE 1
                    // -----------------------------------------

                    2'd1: begin

                        instruction_buffer[23:16] <= uart_data;

                        byte_count <= 2'd2;

                    end


                    // -----------------------------------------
                    // BYTE 2
                    // -----------------------------------------

                    2'd2: begin

                        instruction_buffer[15:8] <= uart_data;

                        byte_count <= 2'd3;

                    end


                    // -----------------------------------------
                    // BYTE 3
                    // -----------------------------------------

                    2'd3: begin

                        // Check for END PROGRAM command
                        if ({instruction_buffer[31:8], uart_data}
                            == 32'hFFFFFFFF) begin

                            program_loaded <= 1'b1;

                            byte_count <= 2'd0;

                        end

                        else begin

                            // Store final byte
                            instruction_buffer[7:0] <= uart_data;

                            // Write instruction
                            write_enable  <= 1'b1;

                            write_address <= current_address;

                            write_data <= {
                                instruction_buffer[31:8],
                                uart_data
                            };

                            // Next instruction address
                            current_address <= current_address + 1'b1;

                            byte_count <= 2'd0;

                        end

                    end

                endcase

            end

        end

    end

endmodule
