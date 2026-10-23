`timescale 1ns / 1ps

module debug_monitor_uart_tb;

    // =========================================================
    // Clock / reset
    // =========================================================

    reg clk;
    reg reset;

    always #5 clk = ~clk;   // 100 MHz


    // =========================================================
    // Fake CPU debug signals
    // =========================================================

    reg [31:0] debug_pc;

    reg [31:0] debug_r1;
    reg [31:0] debug_r2;
    reg [31:0] debug_r3;
    reg [31:0] debug_r4;
    reg [31:0] debug_r5;

    reg debug_halted;


    // =========================================================
    // Debug monitor -> UART TX
    // =========================================================

    wire [7:0] tx_data;
    wire       tx_valid;
    wire       tx_busy;

    wire uart_tx_pin;


    // =========================================================
    // Debug monitor
    // =========================================================

    debug_monitor #(
        .CLK_FREQ(100_000_000),

        // Short interval for simulation
        .MONITOR_INTERVAL(1000)

    ) MONITOR (
        .clk(clk),
        .reset(reset),

        .debug_pc(debug_pc),

        .debug_r1(debug_r1),
        .debug_r2(debug_r2),
        .debug_r3(debug_r3),
        .debug_r4(debug_r4),
        .debug_r5(debug_r5),

        .debug_halted(debug_halted),

        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .tx_busy(tx_busy)
    );


    // =========================================================
    // UART transmitter
    // =========================================================

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) UART_TX (
        .clk(clk),
        .reset(reset),

        .data_in(tx_data),
        .data_valid(tx_valid),

        .tx(uart_tx_pin),
        .busy(tx_busy)
    );


    // =========================================================
    // UART receiver variables
    // =========================================================

    localparam integer BIT_TIME_NS = 8681;

    reg [7:0] received_byte;

    integer rx_byte_count;
    integer packet_errors;

    integer i;


    // =========================================================
    // UART receive task
    //
    // Decodes the actual uart_tx_pin waveform.
    // =========================================================

    task receive_uart_byte;
        output [7:0] data;

        integer j;

        begin

            // ---------------------------------------------
            // Wait for START bit
            // ---------------------------------------------

            @(negedge uart_tx_pin);

            // Move to middle of START bit
            #(BIT_TIME_NS / 2);

            // ---------------------------------------------
            // Check START bit
            // ---------------------------------------------

            if (uart_tx_pin !== 1'b0) begin

                $display(
                    "ERROR: Invalid UART START bit at time %0t ns",
                    $time
                );

            end

            // Move to middle of first data bit
            #(BIT_TIME_NS);

            // ---------------------------------------------
            // Receive 8 data bits
            // LSB first
            // ---------------------------------------------

            for (j = 0; j < 8; j = j + 1) begin

                data[j] = uart_tx_pin;

                #(BIT_TIME_NS);

            end

            // ---------------------------------------------
            // Check STOP bit
            // ---------------------------------------------

            if (uart_tx_pin !== 1'b1) begin

                $display(
                    "ERROR: Invalid UART STOP bit at time %0t ns",
                    $time
                );
            end

            // Finish stop bit
            #(BIT_TIME_NS);

        end

    endtask


    // =========================================================
    // Expected packet
    //
    // AA
    // PC = 00000010
    // R1 = 00000005
    // R2 = 0000000A
    // R3 = 0000000F
    // R4 = 00000014
    // R5 = 00000019
    // HALT = 01
    // =========================================================

    reg [7:0] expected_packet [0:25];

    initial begin

        expected_packet[0]  = 8'hAA;

        expected_packet[1]  = 8'h00;
        expected_packet[2]  = 8'h00;
        expected_packet[3]  = 8'h00;
        expected_packet[4]  = 8'h10;

        expected_packet[5]  = 8'h00;
        expected_packet[6]  = 8'h00;
        expected_packet[7]  = 8'h00;
        expected_packet[8]  = 8'h05;

        expected_packet[9]  = 8'h00;
        expected_packet[10] = 8'h00;
        expected_packet[11] = 8'h00;
        expected_packet[12] = 8'h0A;

        expected_packet[13] = 8'h00;
        expected_packet[14] = 8'h00;
        expected_packet[15] = 8'h00;
        expected_packet[16] = 8'h0F;

        expected_packet[17] = 8'h00;
        expected_packet[18] = 8'h00;
        expected_packet[19] = 8'h00;
        expected_packet[20] = 8'h14;

        expected_packet[21] = 8'h00;
        expected_packet[22] = 8'h00;
        expected_packet[23] = 8'h00;
        expected_packet[24] = 8'h19;

        expected_packet[25] = 8'h01;

    end


    // =========================================================
    // UART receiver process
    // =========================================================

    initial begin

        rx_byte_count = 0;
        packet_errors = 0;

        // Wait for reset to finish
        wait (reset == 1'b0);

        // Continuously receive bytes
        forever begin

            receive_uart_byte(received_byte);

            $display(
                "TIME=%0t ns | UART RX BYTE = %02h",
                $time,
                received_byte
            );

            // ---------------------------------------------
            // Check byte
            // ---------------------------------------------

            if (rx_byte_count < 26) begin

                if (received_byte !== expected_packet[rx_byte_count]) begin

                    $display(
                        "ERROR: BYTE %0d | Expected=%02h | Received=%02h",
                        rx_byte_count,
                        expected_packet[rx_byte_count],
                        received_byte
                    );

                    packet_errors = packet_errors + 1;

                end
                else begin

                    $display(
                        "PASS: BYTE %0d = %02h",
                        rx_byte_count,
                        received_byte
                    );

                end

            end

            rx_byte_count = rx_byte_count + 1;

        end

    end


    // =========================================================
    // Main test
    // =========================================================

    initial begin

        clk = 1'b0;

        reset = 1'b1;

        // Fake CPU state
        debug_pc = 32'h00000010;

        debug_r1 = 32'h00000005;
        debug_r2 = 32'h0000000A;
        debug_r3 = 32'h0000000F;
        debug_r4 = 32'h00000014;
        debug_r5 = 32'h00000019;

        debug_halted = 1'b1;


        // -----------------------------------------------------
        // Reset
        // -----------------------------------------------------

        #100;

        reset = 1'b0;


        $display("");
        $display("----------------------------------------");
        $display("UART DEBUG MONITOR TEST START");
        $display("----------------------------------------");

        $display("Expected packet:");
        $display(
            "AA 00 00 00 10 00 00 00 05 "
        );
        $display(
            "00 00 00 0A 00 00 00 0F "
        );
        $display(
            "00 00 00 14 00 00 00 19 01"
        );

        $display("----------------------------------------");


        // -----------------------------------------------------
        // Wait until the first complete packet is received
        // -----------------------------------------------------

        wait (rx_byte_count >= 26);

        #100;


        // -----------------------------------------------------
        // Final result
        // -----------------------------------------------------

        $display("----------------------------------------");

        if (packet_errors == 0) begin

            $display("ALL 26 BYTES RECEIVED CORRECTLY");
            $display("UART DEBUG MONITOR TEST PASSED");

        end

        else begin

            $display(
                "UART DEBUG MONITOR TEST FAILED"
            );

            $display(
                "TOTAL ERRORS = %0d",
                packet_errors
            );

        end

        $display("----------------------------------------");

        $finish;

    end

endmodule