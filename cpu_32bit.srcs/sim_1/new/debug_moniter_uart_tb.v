`timescale 1ns / 1ps

module cpu_top_full_flow_tb;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg reset;

    // PC -> FPGA
    reg uart_rx_pin;

    // FPGA -> PC
    wire uart_tx_pin;


    // ============================================================
    // DEBUG OUTPUTS FROM CPU TOP
    // ============================================================

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


    // ============================================================
    // UART TIMING
    // ============================================================

    localparam integer CLK_PERIOD_NS = 10;

    // 100 MHz / 115200 baud
    // DUT uses:
    // CLKS_PER_BIT = 868
    // 868 * 10 ns = 8680 ns

    localparam integer BIT_TIME_NS      = 8680;
    localparam integer HALF_BIT_TIME_NS = 4340;

    localparam integer BYTE_TIME_NS = BIT_TIME_NS * 10;

    // Debug monitor interval
    localparam integer DEBUG_INTERVAL = 5000;


    // ============================================================
    // DEVICE UNDER TEST
    // ============================================================

    cpu_top #(
        .DEBUG_MONITOR_INTERVAL(DEBUG_INTERVAL)
    ) DUT (

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


    // ============================================================
    // 100 MHz CLOCK
    // ============================================================

    initial begin
        clk = 1'b0;
    end

    always #(CLK_PERIOD_NS / 2) clk = ~clk;


    // ============================================================
    // TEST PROGRAM
    // ============================================================

    reg [31:0] program [0:7];

    integer i;


    // ============================================================
    // UART TRANSMITTER
    // TESTBENCH -> FPGA
    //
    // 8-N-1
    // START + 8 DATA + STOP
    // ============================================================

    task uart_send_byte;

        input [7:0] data;

        integer b;

        begin

            // START BIT
            uart_rx_pin = 1'b0;
            #(BIT_TIME_NS);

            // DATA BITS - LSB FIRST
            for (b = 0; b < 8; b = b + 1) begin

                uart_rx_pin = data[b];
                #(BIT_TIME_NS);

            end

            // STOP BIT
            uart_rx_pin = 1'b1;
            #(BIT_TIME_NS);

        end

    endtask


    // ============================================================
    // SEND 32-BIT WORD
    //
    // MSB FIRST
    // ============================================================

    task uart_send_word;

        input [31:0] word;

        begin

            uart_send_byte(word[31:24]);
            uart_send_byte(word[23:16]);
            uart_send_byte(word[15:8]);
            uart_send_byte(word[7:0]);

        end

    endtask


    // ============================================================
    // UART RECEIVER
    // FPGA -> TESTBENCH
    //
    // 8-N-1
    //
    // IMPORTANT:
    // Start edge -> 1.5 bit -> DATA0 center
    // Each following data bit = +1 bit
    // After DATA7, +1 bit = STOP center
    //
    // DO NOT wait an additional half-bit after STOP.
    // ============================================================

    task uart_receive_byte;

        output [7:0] data;

        integer b;

        begin

            data = 8'h00;

            // ----------------------------------------------------
            // WAIT FOR START BIT
            // ----------------------------------------------------

            @(negedge uart_tx_pin);


            // ----------------------------------------------------
            // MOVE TO CENTER OF DATA BIT 0
            // ----------------------------------------------------

            #(BIT_TIME_NS + HALF_BIT_TIME_NS);


            // ----------------------------------------------------
            // RECEIVE 8 DATA BITS
            // ----------------------------------------------------

            for (b = 0; b < 8; b = b + 1) begin

                data[b] = uart_tx_pin;

                #(BIT_TIME_NS);

            end


            // ----------------------------------------------------
            // WE ARE NOW AT CENTER OF STOP BIT
            // ----------------------------------------------------

            if (uart_tx_pin !== 1'b1) begin

                $display(
                    "WARNING: UART STOP ERROR at %0t, DATA=%02h",
                    $time,
                    data
                );

            end

        end

    endtask


    // ============================================================
    // DEBUG PACKET
    //
    // TOTAL = 134 BYTES
    //
    // BYTE 0       = AA
    // BYTES 1..4   = PC
    // BYTES 5..132 = R0..R31
    // BYTE 133     = HALT
    // ============================================================

    reg [7:0] packet [0:133];

    reg [7:0] rx_byte;

    reg [31:0] packet_pc;

    reg [31:0] packet_regs [0:31];

    reg packet_halt;

    integer r;


    // ============================================================
    // RECEIVE COMPLETE DEBUG PACKET
    // ============================================================

    task receive_debug_packet;

        integer k;
        integer attempts;
        reg header_found;

        begin

            $display("");
            $display("============================================================");
            $display("WAITING FOR DEBUG PACKET");
            $display("Expected packet size = 134 bytes");
            $display("============================================================");


            // ----------------------------------------------------
            // SEARCH FOR AA HEADER
            // ----------------------------------------------------

            header_found = 1'b0;
            attempts = 0;

            while (!header_found && attempts < 1000) begin

                uart_receive_byte(rx_byte);

                attempts = attempts + 1;

                $display(
                    "UART RX BYTE %0d = %02h at %0t",
                    attempts,
                    rx_byte,
                    $time
                );

                if (rx_byte == 8'hAA) begin

                    header_found = 1'b1;

                end

            end


            // ----------------------------------------------------
            // HEADER NOT FOUND
            // ----------------------------------------------------

            if (!header_found) begin

                $display("");
                $display("ERROR: DEBUG HEADER AA NOT FOUND");
                $display("Simulation stopped.");

                $finish;

            end


            // ----------------------------------------------------
            // STORE HEADER
            // ----------------------------------------------------

            packet[0] = rx_byte;

            $display("");
            $display(
                "Packet header received = %02h at time %0t",
                rx_byte,
                $time
            );


            // ----------------------------------------------------
            // RECEIVE REMAINING 133 BYTES
            // ----------------------------------------------------

            for (k = 1; k < 134; k = k + 1) begin

                uart_receive_byte(rx_byte);

                packet[k] = rx_byte;

                $display(
                    "DEBUG PACKET BYTE [%0d] = %02h at %0t",
                    k,
                    rx_byte,
                    $time
                );

            end


            // ----------------------------------------------------
            // DECODE PC
            // ----------------------------------------------------

            packet_pc = {
                packet[1],
                packet[2],
                packet[3],
                packet[4]
            };


            // ----------------------------------------------------
            // DECODE R0-R31
            // ----------------------------------------------------

            for (r = 0; r < 32; r = r + 1) begin

                packet_regs[r] = {
                    packet[5 + r*4],
                    packet[6 + r*4],
                    packet[7 + r*4],
                    packet[8 + r*4]
                };

            end


            // ----------------------------------------------------
            // DECODE HALT
            // ----------------------------------------------------

            packet_halt = packet[133];


            // ----------------------------------------------------
            // PRINT COMPLETE PACKET
            // ----------------------------------------------------

            $display("");
            $display("============================================================");
            $display("DEBUG PACKET RECEIVED");
            $display("============================================================");

            $display(
                "HEADER = %02h",
                packet[0]
            );

            $display(
                "PC     = %08h",
                packet_pc
            );

            for (r = 0; r < 32; r = r + 1) begin

                $display(
                    "R%-2d    = %08h",
                    r,
                    packet_regs[r]
                );

            end

            $display(
                "HALT   = %02h",
                packet_halt
            );

            $display("============================================================");

        end

    endtask


    // ============================================================
    // PRINT INTERNAL CPU DATA FLOW
    // ============================================================

    task print_internal_flow;

        begin

            $display("");
            $display("------------------------------------------------------------");
            $display("INTERNAL CPU DATA FLOW");
            $display("------------------------------------------------------------");


            // ----------------------------------------------------
            // PROGRAM LOADER
            // ----------------------------------------------------

            $display("");
            $display("PROGRAM LOADER:");

            $display(
                "  program_loaded     = %b",
                DUT.program_loaded
            );

            $display(
                "  uart_data          = %02h",
                DUT.uart_data
            );

            $display(
                "  uart_data_valid    = %b",
                DUT.uart_data_valid
            );

            $display(
                "  imem_write_enable  = %b",
                DUT.imem_write_enable
            );

            $display(
                "  imem_write_address = %0d",
                DUT.imem_write_address
            );

            $display(
                "  imem_write_data    = %08h",
                DUT.imem_write_data
            );


            // ----------------------------------------------------
            // IF STAGE
            // ----------------------------------------------------

            $display("");
            $display("IF STAGE:");

            $display(
                "  PC                 = %08h",
                DUT.current_pc
            );

            $display(
                "  Instruction        = %08h",
                DUT.instruction
            );


            // ----------------------------------------------------
            // ID STAGE
            // ----------------------------------------------------

            $display("");
            $display("ID STAGE:");

            $display(
                "  ID PC              = %08h",
                DUT.id_pc
            );

            $display(
                "  ID Instruction     = %08h",
                DUT.id_instruction
            );


            // ----------------------------------------------------
            // EX STAGE
            // ----------------------------------------------------

            $display("");
            $display("EX STAGE:");

            $display(
                "  ALU result         = %08h",
                DUT.alu_result
            );

            $display(
                "  Destination        = R%0d",
                DUT.destination_reg
            );

            $display(
                "  Branch taken       = %b",
                DUT.branch_taken
            );

            $display(
                "  Jump taken         = %b",
                DUT.jump_taken
            );

            $display(
                "  Halt taken         = %b",
                DUT.halt_taken
            );


            // ----------------------------------------------------
            // MEMORY STAGE
            // ----------------------------------------------------

            $display("");
            $display("MEMORY STAGE:");

            $display(
                "  ALU address        = %08h",
                DUT.exmem_alu_result
            );

            $display(
                "  MemRead            = %b",
                DUT.exmem_MemRead
            );

            $display(
                "  MemWrite           = %b",
                DUT.exmem_MemWrite
            );

            $display(
                "  Write data         = %08h",
                DUT.exmem_read_data2
            );

            $display(
                "  Read data          = %08h",
                DUT.memory_data
            );


            // ----------------------------------------------------
            // WRITE BACK
            // ----------------------------------------------------

            $display("");
            $display("WRITE BACK:");

            $display(
                "  Write enable       = %b",
                DUT.wb_reg_write
            );

            $display(
                "  Register           = R%0d",
                DUT.wb_write_reg
            );

            $display(
                "  Write data         = %08h",
                DUT.wb_write_data
            );


            $display("");
            $display("------------------------------------------------------------");

        end

    endtask


    // ============================================================
    // EVENT MONITOR
    // ============================================================

    always @(posedge clk) begin

        // --------------------------------------------------------
        // INSTRUCTION MEMORY WRITE
        // --------------------------------------------------------

        if (DUT.imem_write_enable) begin

            $display(
                "[%0t] IMEM WRITE: address=%0d data=%08h",
                $time,
                DUT.imem_write_address,
                DUT.imem_write_data
            );

        end


        // --------------------------------------------------------
        // REGISTER WRITE BACK
        // --------------------------------------------------------

        if (debug_reg_write) begin

            $display(
                "[%0t] WB: R%0d <= %08h",
                $time,
                debug_reg_number,
                debug_reg_data
            );

        end


        // --------------------------------------------------------
        // MEMORY WRITE
        // --------------------------------------------------------

        if (debug_mem_write) begin

            $display(
                "[%0t] MEM WRITE: address=%08h data=%08h",
                $time,
                debug_mem_address,
                debug_mem_write_data
            );

        end


        // --------------------------------------------------------
        // MEMORY READ
        // --------------------------------------------------------

        if (debug_mem_read) begin

            $display(
                "[%0t] MEM READ: address=%08h",
                $time,
                debug_mem_address
            );

        end


        // --------------------------------------------------------
        // BRANCH
        // --------------------------------------------------------

        if (debug_branch_taken) begin

            $display(
                "[%0t] BRANCH TAKEN: target=%08h",
                $time,
                DUT.branch_target
            );

        end


        // --------------------------------------------------------
        // JUMP
        // --------------------------------------------------------

        if (debug_jump_taken) begin

            $display(
                "[%0t] JUMP TAKEN: target=%08h",
                $time,
                DUT.jump_target
            );

        end


        // --------------------------------------------------------
        // HALT
        // --------------------------------------------------------

        if (DUT.halt_taken) begin

            $display(
                "[%0t] HLT IN EX STAGE",
                $time
            );

        end

    end


    // ============================================================
    // FINAL RESULT CHECK
    // ============================================================

    integer errors;


    task check_results;

        begin

            errors = 0;

            $display("");
            $display("============================================================");
            $display("FINAL RESULT CHECK");
            $display("============================================================");


            // ----------------------------------------------------
            // HEADER
            // ----------------------------------------------------

            if (packet[0] !== 8'hAA) begin

                $display(
                    "FAIL: Header expected AA, got %02h",
                    packet[0]
                );

                errors = errors + 1;

            end


            // ----------------------------------------------------
            // PC
            // ----------------------------------------------------

            $display(
                "INFO: Debug PC = %08h",
                packet_pc
            );


            // ----------------------------------------------------
            // R0
            // ----------------------------------------------------

            if (packet_regs[0] !== 32'd0) begin

                $display(
                    "FAIL: R0 expected 0, got %08h",
                    packet_regs[0]
                );

                errors = errors + 1;

            end


            // ----------------------------------------------------
            // R1
            // ----------------------------------------------------

            if (packet_regs[1] !== 32'd100) begin

                $display(
                    "FAIL: R1 expected 100, got %08h",
                    packet_regs[1]
                );

                errors = errors + 1;

            end


            // ----------------------------------------------------
            // R2
            // ----------------------------------------------------

            if (packet_regs[2] !== 32'd123) begin

                $display(
                    "FAIL: R2 expected 123, got %08h",
                    packet_regs[2]
                );

                errors = errors + 1;

            end


            // ----------------------------------------------------
            // R3
            // ----------------------------------------------------

            if (packet_regs[3] !== 32'd123) begin

                $display(
                    "FAIL: R3 expected 123, got %08h",
                    packet_regs[3]
                );

                errors = errors + 1;

            end


            // ----------------------------------------------------
            // R4
            // ----------------------------------------------------

            if (packet_regs[4] !== 32'd124) begin

                $display(
                    "FAIL: R4 expected 124, got %08h",
                    packet_regs[4]
                );

                errors = errors + 1;

            end


            // ----------------------------------------------------
            // R5
            // ----------------------------------------------------

            if (packet_regs[5] !== 32'd999) begin

                $display(
                    "FAIL: R5 expected 999, got %08h",
                    packet_regs[5]
                );

                errors = errors + 1;

            end


            // ----------------------------------------------------
            // HALT
            // ----------------------------------------------------

            if (packet_halt !== 8'h01) begin

                $display(
                    "FAIL: HALT expected 01, got %02h",
                    packet_halt
                );

                errors = errors + 1;

            end


            // ----------------------------------------------------
            // R6-R31 SHOULD BE ZERO
            // ----------------------------------------------------

            for (r = 6; r < 32; r = r + 1) begin

                if (packet_regs[r] !== 32'd0) begin

                    $display(
                        "FAIL: R%0d expected 0, got %08h",
                        r,
                        packet_regs[r]
                    );

                    errors = errors + 1;

                end

            end


            // ----------------------------------------------------
            // FINAL RESULT
            // ----------------------------------------------------

            if (errors == 0) begin

                $display("");
                $display("********************************************");
                $display("* FULL CPU UART FLOW TEST PASSED          *");
                $display("*                                          *");
                $display("* UART RX -> LOADER -> IMEM -> CPU        *");
                $display("* CPU -> REGISTER FILE -> DEBUG MONITOR   *");
                $display("* DEBUG MONITOR -> UART TX                *");
                $display("********************************************");

            end
            else begin

                $display("");
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display(
                    "! FULL FLOW TEST FAILED: %0d ERROR(S)      !",
                    errors
                );
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

            end

            $display("============================================================");

        end

    endtask


    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // INITIAL CONDITIONS
        // --------------------------------------------------------

        clk         = 1'b0;
        reset       = 1'b1;
        uart_rx_pin = 1'b1;


        // --------------------------------------------------------
        // PROGRAM MACHINE CODE
        // --------------------------------------------------------

        program[0] = 32'h3C010064; // MOVI R1,100
        program[1] = 32'h3C02007B; // MOVI R2,123

        program[2] = 32'h24220000; // SW R2,0(R1)
        program[3] = 32'h20230000; // LW R3,0(R1)

        program[4] = 32'h28640001; // ADDI R4,R3,1
        program[5] = 32'h3C0503E7; // MOVI R5,999

        program[6] = 32'hFC000000; // HLT

        // End marker
        program[7] = 32'hFFFFFFFF;


        // --------------------------------------------------------
        // TEST HEADER
        // --------------------------------------------------------

        $display("");
        $display("============================================================");
        $display("FULL CPU UART DATA-FLOW TEST");
        $display("============================================================");


        // --------------------------------------------------------
        // HOLD CPU IN RESET
        // --------------------------------------------------------

        #100;

        reset = 1'b0;


        // --------------------------------------------------------
        // UART IDLE
        // --------------------------------------------------------

        #(BYTE_TIME_NS);


        // --------------------------------------------------------
        // SEND PROGRAM
        // --------------------------------------------------------

        $display("");
        $display("Sending program through UART...");
        $display("");

        for (i = 0; i < 8; i = i + 1) begin

            $display(
                "TX WORD %0d = %08h",
                i,
                program[i]
            );

            uart_send_word(program[i]);

        end


        // --------------------------------------------------------
        // UART IDLE
        // --------------------------------------------------------

        uart_rx_pin = 1'b1;


        $display("");
        $display("Program transmission finished.");

        $display(
            "program_loaded = %b",
            DUT.program_loaded
        );

        $display("");
        $display("Waiting for CPU to execute...");
        $display("");


        // --------------------------------------------------------
        // WAIT FOR HLT
        // --------------------------------------------------------

        wait (debug_halted === 1'b1);


        $display("");
        $display(
            "CPU REPORTED HALTED at time %0t",
            $time
        );


        // --------------------------------------------------------
        // PRINT INTERNAL CPU DATA FLOW
        // --------------------------------------------------------

        print_internal_flow;


        // --------------------------------------------------------
        // RECEIVE DEBUG MONITOR PACKET
        // --------------------------------------------------------

        receive_debug_packet;


        // --------------------------------------------------------
        // CHECK RESULTS
        // --------------------------------------------------------

        check_results;


        // --------------------------------------------------------
        // END
        // --------------------------------------------------------

        #1000;

        $display("");
        $display("TESTBENCH FINISHED.");
        $finish;

    end

endmodule