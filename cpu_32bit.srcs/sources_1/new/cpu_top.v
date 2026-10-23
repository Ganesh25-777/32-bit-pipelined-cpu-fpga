`timescale 1ns / 1ps

module cpu_top #(
    parameter integer DEBUG_MONITOR_INTERVAL = 10_000_000
)(
    input clk,
    input reset,

    // =====================================================
    // UART INPUT
    // PC -> FPGA
    // =====================================================

    input uart_rx_pin,

    // =====================================================
    // UART OUTPUT
    // FPGA -> PC
    // =====================================================

    output uart_tx_pin,

    // =====================================================
    // DEBUG / CPU MONITOR OUTPUTS
    // =====================================================

    output [31:0] debug_pc,
    output [31:0] debug_instruction,
    output [31:0] debug_alu,

    // Register write-back information
    output        debug_reg_write,
    output [4:0]  debug_reg_number,
    output [31:0] debug_reg_data,

    // Memory information
    output        debug_mem_read,
    output        debug_mem_write,
    output [31:0] debug_mem_address,
    output [31:0] debug_mem_write_data,

    // Control / pipeline information
    output        debug_branch_taken,
    output        debug_jump_taken,
    output        debug_stall,
    output        debug_halted

);

    // =====================================================
    // 1. UART RX
    // =====================================================

    wire [7:0] uart_data;
    wire       uart_data_valid;

    uart_rx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(921600)
    ) UART_RX_UNIT (

        .clk(clk),
        .reset(reset),

        .rx(uart_rx_pin),

        .data_out(uart_data),
        .data_valid(uart_data_valid)

    );


    // =====================================================
    // 2. UART PROGRAM LOADER
    // =====================================================

    wire        imem_write_enable;
    wire [11:0] imem_write_address;
    wire [31:0] imem_write_data;

    wire program_loaded;

    uart_program_loader UART_PROGRAM_LOADER (
        .clk(clk),
        .reset(reset),

        .uart_data(uart_data),
        .uart_data_valid(uart_data_valid),

        .write_enable(imem_write_enable),
        .write_address(imem_write_address),
        .write_data(imem_write_data),

        .program_loaded(program_loaded)

    );


    // =====================================================
    // 3. CPU RESET
    // =====================================================

    wire cpu_reset;

    assign cpu_reset = reset | ~program_loaded;


    // =====================================================
    // 4. IF STAGE SIGNALS
    // =====================================================

    wire [31:0] current_pc;
    wire [31:0] instruction;

    wire        branch_taken;
    wire [31:0] branch_target;

    wire        jump_taken;
    wire [31:0] jump_target;

    wire        halt_taken;


    // =====================================================
    // 5. HAZARD / FLUSH SIGNALS
    // =====================================================

    wire stall;
    wire stall_flush;

    wire ex_flush;

    wire if_id_flush;
    wire id_ex_flush;

    reg cpu_halted;


    // =====================================================
    // 6. WRITE BACK SIGNALS
    // =====================================================

    wire [4:0]  wb_write_reg;
    wire [31:0] wb_write_data;
    wire        wb_reg_write;


    // =====================================================
    // 7. REGISTER FILE
    // =====================================================

    wire [31:0] read_data1;
    wire [31:0] read_data2;

    wire [4:0] rs;
    wire [4:0] rt;

    // Debug monitor register read interface
    wire [4:0]  monitor_reg_addr;
    wire [31:0] monitor_reg_data;


    register_file REG_FILE (

        .clk(clk),
        .reset(cpu_reset),

        // Normal CPU read ports
        .rs(rs),
        .rt(rt),

        .read_data1(read_data1),
        .read_data2(read_data2),

        // Normal CPU write port
        .rd(wb_write_reg),
        .write_data(wb_write_data),
        .reg_write(wb_reg_write),

        // Debug monitor read port
        .debug_reg_addr(monitor_reg_addr),
        .debug_reg_data(monitor_reg_data)

    );


    // =====================================================
    // 8. IF STAGE
    // =====================================================

    if_stage IF_STAGE (

        .clk(clk),
        .reset(cpu_reset),

        .stall(stall | cpu_halted),

        .branch_taken(branch_taken),
        .branch_target(branch_target),

        .jump(jump_taken),
        .jump_target(jump_target),

        // Instruction memory programming interface
        .imem_write_enable(imem_write_enable),
        .imem_write_address(imem_write_address),
        .imem_write_data(imem_write_data),

        .current_pc(current_pc),
        .instruction(instruction)

    );


    // =====================================================
    // 9. IF / ID REGISTER
    // =====================================================

    wire [31:0] id_pc;
    wire [31:0] id_instruction;


    if_id_register IF_ID (

        .clk(clk),
        .reset(cpu_reset),

        .flush(if_id_flush),
        .stall(stall | cpu_halted),

        .current_pc(current_pc),
        .instruction(instruction),

        .id_pc(id_pc),
        .id_instruction(id_instruction)

    );


    // =====================================================
    // 10. ID STAGE
    // =====================================================

    wire [31:0] id_current_pc;

    wire [31:0] id_read_data1;
    wire [31:0] id_read_data2;

    wire [4:0] rd;

    wire [31:0] immediate_out;
    wire [25:0] target;

    wire RegDst;
    wire RegWrite;
    wire ALUSecondData;

    wire MemRead;
    wire MemWrite;
    wire MemToReg;

    wire Branch;
    wire BranchNotEqual;

    wire Jump;
    wire Halt;

    wire [4:0] ALUControl;

    wire id_uses_rs;
    wire id_uses_rt;


    id_stage ID_STAGE (

        .clk(clk),
        .reset(cpu_reset),

        .current_pc(id_pc),
        .instruction(id_instruction),

        .read_data1(read_data1),
        .read_data2(read_data2),

        .id_current_pc(id_current_pc),

        .rs(rs),
        .rt(rt),

        .id_read_data1(id_read_data1),
        .id_read_data2(id_read_data2),

        .immediate_out(immediate_out),
        .target(target),
        .rd(rd),

        .RegDst(RegDst),
        .RegWrite(RegWrite),
        .ALUSecondData(ALUSecondData),

        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .MemToReg(MemToReg),

        .Branch(Branch),
        .BranchNotEqual(BranchNotEqual),

        .Jump(Jump),
        .Halt(Halt),

        .ALUControl(ALUControl),

        .id_uses_rs(id_uses_rs),
        .id_uses_rt(id_uses_rt)

    );


    // =====================================================
    // 11. ID / EX REGISTER
    // =====================================================

    wire [31:0] ex_pc;
    wire [31:0] ex_read_data1;
    wire [31:0] ex_read_data2;
    wire [31:0] ex_immediate;

    wire [4:0] ex_rs;
    wire [4:0] ex_rt;
    wire [4:0] ex_rd;

    wire ex_RegDst;
    wire ex_RegWrite;
    wire ex_ALUSecondData;

    wire [4:0] ex_ALUControl;

    wire ex_MemRead;
    wire ex_MemWrite;
    wire ex_MemToReg;

    wire ex_Branch;
    wire ex_BranchNotEqual;

    wire ex_Jump;
    wire ex_Halt;

    wire [25:0] ex_target;


    id_ex_register ID_EX (

        .clk(clk),
        .reset(cpu_reset),

        .flush(id_ex_flush),

        .current_pc(id_current_pc),

        .read_data1(id_read_data1),
        .read_data2(id_read_data2),

        .immediate_out(immediate_out),
        .target(target),

        .rs(rs),
        .rt(rt),
        .rd(rd),

        .RegDst(RegDst),
        .RegWrite(RegWrite),
        .ALUSecondData(ALUSecondData),

        .ALUControl(ALUControl),

        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .MemToReg(MemToReg),

        .Branch(Branch),
        .BranchNotEqual(BranchNotEqual),

        .Jump(Jump),
        .Halt(Halt),

        .ex_pc(ex_pc),
        .ex_read_data1(ex_read_data1),
        .ex_read_data2(ex_read_data2),
        .ex_immediate(ex_immediate),

        .ex_rs(ex_rs),
        .ex_rt(ex_rt),
        .ex_rd(ex_rd),

        .ex_RegDst(ex_RegDst),
        .ex_RegWrite(ex_RegWrite),
        .ex_ALUSecondData(ex_ALUSecondData),

        .ex_ALUControl(ex_ALUControl),

        .ex_MemRead(ex_MemRead),
        .ex_MemWrite(ex_MemWrite),
        .ex_MemToReg(ex_MemToReg),

        .ex_Branch(ex_Branch),
        .ex_BranchNotEqual(ex_BranchNotEqual),

        .ex_Jump(ex_Jump),
        .ex_Halt(ex_Halt),
        .ex_target(ex_target)

    );


    // =====================================================
    // 12. EX STAGE SIGNALS
    // =====================================================

    wire [31:0] alu_result;
    wire [4:0] destination_reg;

    // Multi-cycle multiplier interface.
    wire        ex_is_mul;
    wire        mul_in_mem;
    wire [31:0] mul_product;

    wire [31:0] mem_read_data2;


    wire mem_RegWrite;
    wire mem_MemRead;
    wire mem_MemWrite;
    wire mem_MemToReg;


    // =====================================================
    // 13. FORWARDING
    // =====================================================

    wire [1:0] forwardA;
    wire [1:0] forwardB;

    wire [31:0] exmem_forward_data;
    wire [31:0] exmem_alu_result;


    // =====================================================
    // 14. EX STAGE
    // =====================================================

    ex_stage EX_STAGE (

        .clk(clk),

        .ex_pc(ex_pc),

        .ex_read_data1(ex_read_data1),
        .ex_read_data2(ex_read_data2),
        .ex_immediate(ex_immediate),

        .ex_rs(ex_rs),
        .ex_rt(ex_rt),
        .ex_rd(ex_rd),

        .ex_RegDst(ex_RegDst),
        .ex_RegWrite(ex_RegWrite),
        .ex_ALUSecondData(ex_ALUSecondData),

        .ex_ALUControl(ex_ALUControl),

        .ex_MemRead(ex_MemRead),
        .ex_MemWrite(ex_MemWrite),
        .ex_MemToReg(ex_MemToReg),

        .ex_Branch(ex_Branch),
        .ex_BranchNotEqual(ex_BranchNotEqual),

        .ex_Jump(ex_Jump),
        .ex_Halt(ex_Halt),
        .ex_target(ex_target),

        .forwardA(forwardA),
        .forwardB(forwardB),

        .mem_forward_data(exmem_alu_result),
        .wb_forward_data(wb_write_data),

        .alu_result(alu_result),
       

        .branch_taken(branch_taken),
        .branch_target(branch_target),

        .jump_taken(jump_taken),
        .jump_target(jump_target),

        .flush(ex_flush),

        .halt_taken(halt_taken),

        .mem_read_data2(mem_read_data2),
        .destination_reg(destination_reg),

        .mem_RegWrite(mem_RegWrite),
        .mem_MemRead(mem_MemRead),
        .mem_MemWrite(mem_MemWrite),
        .mem_MemToReg(mem_MemToReg),

        // Late MUL result: product is aligned with the MUL in EX/MEM.
        .ex_is_mul(ex_is_mul),
        .mul_in_mem(mul_in_mem),
        .mul_product(mul_product)

    );


    // =====================================================
    // 15. EX / MEM REGISTER
    // =====================================================

    wire [31:0] exmem_read_data2;

    wire [4:0] exmem_destination_reg;

    wire exmem_MemRead;
    wire exmem_MemWrite;
    wire exmem_MemToReg;
    wire exmem_RegWrite;

    // Select the registered multiplier result only while the matching
    // MUL instruction is in MEM; all other instructions use EX/MEM ALU data.
    wire [31:0] memwb_alu_input;
    assign memwb_alu_input = mul_in_mem ? mul_product : exmem_alu_result;

    ex_mem_register EX_MEM (

        .clk(clk),
        .reset(cpu_reset),

        .alu_result(alu_result),
        .read_data2(mem_read_data2),

        .destination_reg(destination_reg),

        .MemRead(mem_MemRead),
        .MemWrite(mem_MemWrite),
        .MemToReg(mem_MemToReg),
        .RegWrite(mem_RegWrite),

        .mem_alu_result(exmem_alu_result),
        .mem_read_data2(exmem_read_data2),

        .mem_destination_reg(exmem_destination_reg),

        .mem_MemRead(exmem_MemRead),
        .mem_MemWrite(exmem_MemWrite),
        .mem_MemToReg(exmem_MemToReg),
        .mem_RegWrite(exmem_RegWrite)

    );


    // =====================================================
    // 16. MEMORY STAGE
    // =====================================================

    wire [31:0] memory_data;


    mem_stage MEM_STAGE (

        .clk(clk),

        .mem_alu_result(exmem_alu_result),
        .mem_read_data2(exmem_read_data2),

        .mem_MemRead(exmem_MemRead),
        .mem_MemWrite(exmem_MemWrite),

        .memory_data(memory_data)

    );


    // =====================================================
    // 17. EX/MEM FORWARDING DATA
    // =====================================================

    assign exmem_forward_data =
        exmem_MemToReg ? memory_data : exmem_alu_result;


    // =====================================================
    // 18. MEM / WB REGISTER
    // =====================================================

    wire [31:0] wb_alu_result;
    wire [31:0] wb_read_data;

    wire [4:0] wb_destination_reg;

    wire wb_RegWrite;
    wire wb_MemToReg;


    mem_wb_register MEM_WB (

        .clk(clk),
        .reset(cpu_reset),

        .mem_alu_result(memwb_alu_input),
        .mem_read_data(memory_data),

        .mem_destination_reg(exmem_destination_reg),

        .mem_RegWrite(exmem_RegWrite),
        .mem_MemToReg(exmem_MemToReg),

        .wb_alu_result(wb_alu_result),
        .wb_read_data(wb_read_data),

        .wb_destination_reg(wb_destination_reg),

        .wb_RegWrite(wb_RegWrite),
        .wb_MemToReg(wb_MemToReg)

    );


    // =====================================================
    // 19. WRITE BACK STAGE
    // =====================================================

    wb_stage WB_STAGE (

        .wb_alu_result(wb_alu_result),
        .wb_read_data(wb_read_data),

        .wb_MemToReg(wb_MemToReg),
        .wb_RegWrite(wb_RegWrite),

        .wb_destination_reg(wb_destination_reg),

        .wb_write_data(wb_write_data),
        .wb_write_reg(wb_write_reg),
        .wb_reg_write(wb_reg_write)

    );


    // =====================================================
    // 20. FORWARDING UNIT
    // =====================================================

forwarding_unit FORWARDING_UNIT (
    .ex_rs(ex_rs),
    .ex_rt(ex_rt),

    .mem_destination_reg(exmem_destination_reg),
    .mem_RegWrite(exmem_RegWrite),
    .mem_MemToReg(exmem_MemToReg),

    .wb_destination_reg(wb_destination_reg),
    .wb_RegWrite(wb_RegWrite),

    .forwardA(forwardA),
    .forwardB(forwardB)
);


    // =====================================================
    // 21. STALLING UNIT
    // =====================================================

    stalling_unit STALLING_UNIT (

        .id_rs(rs),
        .id_rt(rt),

        .id_uses_rs(id_uses_rs),
        .id_uses_rt(id_uses_rt),

        .ex_rt(ex_rt),
        .ex_MemRead(ex_MemRead),

        // MUL result becomes available one stage later than a normal ALU result.
        .ex_rd(ex_rd),
        .ex_is_mul(ex_is_mul),

        .stall(stall),
        .flush(stall_flush)

    );


    // =====================================================
    // 22. FLUSH CONTROL
    // =====================================================

    assign if_id_flush =
        ex_flush | cpu_halted;

    assign id_ex_flush =
        ex_flush | stall_flush | cpu_halted;


    // =====================================================
    // 23. HLT CONTROL
    // =====================================================

    always @(posedge clk or posedge cpu_reset) begin

        if (cpu_reset)
            cpu_halted <= 1'b0;

        else if (halt_taken)
            cpu_halted <= 1'b1;

    end


    // =====================================================
    // 24. DEBUG / CPU MONITOR OUTPUTS
    // =====================================================

    // Current instruction fetch state
    assign debug_pc          = current_pc;
    assign debug_instruction = instruction;

    // Current EX-stage ALU result
    assign debug_alu         = alu_result;

    // Write-back event
    assign debug_reg_write   = wb_reg_write;
    assign debug_reg_number  = wb_write_reg;
    assign debug_reg_data    = wb_write_data;

    // Memory event
    assign debug_mem_read       = exmem_MemRead;
    assign debug_mem_write      = exmem_MemWrite;
    assign debug_mem_address    = exmem_alu_result;
    assign debug_mem_write_data = exmem_read_data2;

    // Control events
    assign debug_branch_taken = branch_taken;
    assign debug_jump_taken   = jump_taken;
    assign debug_stall        = stall;
    assign debug_halted       = cpu_halted;


    // =====================================================
    // 25. DEBUG MONITOR
    // =====================================================

    wire [7:0] debug_tx_data;
    wire       debug_tx_valid;
    wire       debug_tx_busy;

    debug_monitor #(
        .CLK_FREQ(100_000_000),
        .MONITOR_INTERVAL(DEBUG_MONITOR_INTERVAL)
    ) DEBUG_MONITOR (

        .clk(clk),
        .reset(cpu_reset),

        .debug_pc(debug_pc),
        .debug_halted(debug_halted),

        .debug_reg_addr(monitor_reg_addr),
        .debug_reg_data_read(monitor_reg_data),

        .tx_data(debug_tx_data),
        .tx_valid(debug_tx_valid),
        .tx_busy(debug_tx_busy)

    );


    // =====================================================
    // 26. UART TX
    // =====================================================

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(921600)
    ) UART_TX_UNIT (

        .clk(clk),
        .reset(cpu_reset),

        .data_in(debug_tx_data),
        .data_valid(debug_tx_valid),

        .tx(uart_tx_pin),
        .busy(debug_tx_busy)

    );

endmodule