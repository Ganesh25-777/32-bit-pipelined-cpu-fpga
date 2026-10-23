`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ganesh H K
//
// Create Date: 06.10.2026 16:24:04
// Design Name: 32-bit 5-Stage Pipelined CPU
// Module Name: uart_rx
// Project Name: 32-bit CPU on Nexys A7
// Target Devices: Nexys A7 (Artix-7 XC7A100T)
// Tool Versions: Vivado 2025.1
// Description:
// UART Receiver for the 32-bit CPU.
// Receives 8-bit serial data using the 8-N-1 UART protocol.
// Configured for 100 MHz system clock and 921600 baud rate.
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Receives one UART byte at a time and asserts data_valid
// for one clock cycle when a complete byte is received.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 921600
)(
    input        clk,
    input        reset,

    input        rx,

    output reg [7:0] data_out,
    output reg       data_valid
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg [15:0] clk_count;
    reg [3:0]  bit_index;
    reg [7:0]  rx_data;

    reg receiving;


    always @(posedge clk or posedge reset) begin

        if (reset) begin

            clk_count  <= 16'd0;
            bit_index  <= 4'd0;
            rx_data    <= 8'd0;

            data_out   <= 8'd0;
            data_valid <= 1'b0;

            receiving  <= 1'b0;

        end

        else begin

            // Default
            data_valid <= 1'b0;


            // =================================================
            // IDLE - WAIT FOR START BIT
            // =================================================

            if (!receiving) begin

                if (rx == 1'b0) begin

                    receiving <= 1'b1;

                    // Go to center of start bit
                    clk_count <= (CLKS_PER_BIT / 2) - 1;

                    bit_index <= 4'd0;

                end

            end


            // =================================================
            // RECEIVING
            // =================================================

            else begin

                if (clk_count == 0) begin

                    // -----------------------------------------
                    // START BIT
                    // -----------------------------------------

                    if (bit_index == 0) begin

                        // Verify start bit
                        if (rx == 1'b0) begin

                            // Wait one complete bit period
                            clk_count <= CLKS_PER_BIT - 1;

                            bit_index <= 4'd1;

                        end

                        else begin

                            // False start bit
                            receiving <= 1'b0;

                        end

                    end


                    // -----------------------------------------
                    // DATA BITS
                    // -----------------------------------------

                    else if (bit_index <= 8) begin

                        rx_data[bit_index - 1] <= rx;

                        clk_count <= CLKS_PER_BIT - 1;

                        bit_index <= bit_index + 1'b1;

                    end


                    // -----------------------------------------
                    // STOP BIT
                    // -----------------------------------------

                    else begin

                        receiving <= 1'b0;

                        data_out <= rx_data;

                        data_valid <= 1'b1;

                        bit_index <= 4'd0;

                    end

                end

                else begin

                    clk_count <= clk_count - 1'b1;

                end

            end

        end

    end

endmodule