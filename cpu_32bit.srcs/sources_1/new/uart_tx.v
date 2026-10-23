`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.10.2026 00:51:19
// Design Name: 
// Module Name: uart_tx
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


module uart_tx #(
    parameter integer CLK_FREQ  = 100_000_000,
    parameter integer BAUD_RATE = 921600
)(
    input        clk,
    input        reset,

    // Data interface
    input  [7:0]  data_in,
    input        data_valid,

    // UART output
    output reg   tx,

    // High while transmitting
    output       busy
);

    // =====================================================
    // BAUD RATE
    // =====================================================

    localparam integer CLKS_PER_BIT =
        CLK_FREQ / BAUD_RATE;


    // =====================================================
    // STATE MACHINE
    // =====================================================

    localparam [2:0]
        IDLE  = 3'd0,
        START = 3'd1,
        DATA  = 3'd2,
        STOP  = 3'd3;

    reg [2:0] state;


    // =====================================================
    // INTERNAL REGISTERS
    // =====================================================

    reg [31:0] clock_count;
    reg [2:0]  bit_index;
    reg [7:0]  data_buffer;


    // =====================================================
    // BUSY
    // =====================================================

    assign busy = (state != IDLE);


    // =====================================================
    // UART TRANSMITTER
    // =====================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            state       <= IDLE;
            clock_count <= 32'd0;
            bit_index   <= 3'd0;
            data_buffer <= 8'd0;
            tx          <= 1'b1;

        end

        else begin

            case (state)

                // =========================================
                // IDLE
                // =========================================

                IDLE: begin

                    tx          <= 1'b1;
                    clock_count <= 32'd0;
                    bit_index   <= 3'd0;

                    if (data_valid) begin

                        data_buffer <= data_in;

                        // Start bit
                        tx <= 1'b0;

                        state <= START;

                        clock_count <= 32'd0;

                    end

                end


                // =========================================
                // START BIT
                // =========================================

                START: begin

                    if (clock_count == CLKS_PER_BIT - 1) begin

                        clock_count <= 32'd0;
                        bit_index   <= 3'd0;

                        // First data bit
                        tx <= data_buffer[0];

                        state <= DATA;

                    end

                    else begin

                        clock_count <= clock_count + 1'b1;

                    end

                end


                // =========================================
                // DATA BITS
                // LSB FIRST
                // =========================================

                DATA: begin

                    if (clock_count == CLKS_PER_BIT - 1) begin

                        clock_count <= 32'd0;

                        if (bit_index == 3'd7) begin

                            // All 8 data bits transmitted
                            // Move to stop bit

                            tx <= 1'b1;

                            state <= STOP;

                        end

                        else begin

                            bit_index <= bit_index + 1'b1;

                            tx <= data_buffer[bit_index + 1'b1];

                        end

                    end

                    else begin

                        clock_count <= clock_count + 1'b1;

                    end

                end


                // =========================================
                // STOP BIT
                // =========================================

                STOP: begin

                    if (clock_count == CLKS_PER_BIT - 1) begin

                        clock_count <= 32'd0;

                        tx <= 1'b1;

                        state <= IDLE;

                    end

                    else begin

                        clock_count <= clock_count + 1'b1;

                    end

                end


                // =========================================
                // DEFAULT
                // =========================================

                default: begin

                    state       <= IDLE;
                    clock_count <= 32'd0;
                    bit_index   <= 3'd0;
                    tx          <= 1'b1;

                end

            endcase

        end

    end

endmodule
