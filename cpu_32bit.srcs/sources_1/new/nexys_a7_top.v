`timescale 1ns / 1ps

module nexys_a7_top (

    // Nexys A7 100 MHz clock
    input wire clk,

    // Physical reset button (active-low)
    input wire resetn,

    // USB-UART: PC -> FPGA
    input wire uart_rx_pin,

    // USB-UART: FPGA -> PC
    output wire uart_tx_pin

);

    // ==========================================
    // Reset polarity conversion
    // Physical button is active-low.
    // CPU reset is active-high.
    // ==========================================
    wire reset = ~resetn;

    // ==========================================
    // Internal CPU debug signals
    // ==========================================
    wire [31:0] debug_pc;
    wire [31:0] debug_instruction;
    wire [31:0] debug_alu;

    wire        debug_reg_write;
    wire [4:0]  debug_reg_number;
    wire [31:0] debug_reg_data;

    wire        debug_mem_read;
    wire        debug_mem_write;
    wire [31:0] debug_mem_address;
    wire [31:0] debug_mem_write_data;

    wire        debug_branch_taken;
    wire        debug_jump_taken;
    wire        debug_stall;
    wire        debug_halted;

    // ==========================================
    // Instantiate the existing CPU
    // ==========================================
    cpu_top CPU_INSTANCE (

        .clk(clk),
        .reset(reset),

        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin),

        .debug_pc(debug_pc),
        .debug_instruction(debug_instruction),
        .debug_alu(debug_alu),

        .debug_reg_write(debug_reg_write),
        .debug_reg_number(debug_reg_number),
        .debug_reg_data(debug_reg_data),

        .debug_mem_read(debug_mem_read),
        .debug_mem_write(debug_mem_write),
        .debug_mem_address(debug_mem_address),
        .debug_mem_write_data(debug_mem_write_data),

        .debug_branch_taken(debug_branch_taken),
        .debug_jump_taken(debug_jump_taken),
        .debug_stall(debug_stall),
        .debug_halted(debug_halted)

    );

endmodule