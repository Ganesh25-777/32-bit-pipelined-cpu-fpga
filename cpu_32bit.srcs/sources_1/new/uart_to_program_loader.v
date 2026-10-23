`timescale 1ns / 1ps

module uart_program_loader_tb;

    reg clk;
    reg reset;

    reg [7:0] uart_data;
    reg       uart_data_valid;

    wire        write_enable;
    wire [4:0]  write_address;
    wire [31:0] write_data;
    wire        program_loaded;


    // =====================================================
    // DUT
    // =====================================================

    uart_program_loader DUT (

        .clk(clk),
        .reset(reset),

        .uart_data(uart_data),
        .uart_data_valid(uart_data_valid),

        .write_enable(write_enable),
        .write_address(write_address),
        .write_data(write_data),

        .program_loaded(program_loaded)

    );


    // =====================================================
    // CLOCK
    // =====================================================

    always #5 clk = ~clk;


    // =====================================================
    // SEND ONE BYTE TO LOADER
    // =====================================================

    task send_byte;

        input [7:0] data;

        begin

            @(negedge clk);

            uart_data       = data;
            uart_data_valid = 1'b1;

            @(negedge clk);

            uart_data_valid = 1'b0;

        end

    endtask


    // =====================================================
    // TEST
    // =====================================================

    initial begin

        clk             = 1'b0;
        reset           = 1'b1;

        uart_data       = 8'h00;
        uart_data_valid = 1'b0;


        // =================================================
        // RESET
        // =================================================

        #100;

        reset = 1'b0;

        #100;


        // =================================================
        // INSTRUCTION 0
        // MOVI R1, 10
        // 3C 01 00 0A
        // =================================================

        $display("");
        $display("Sending Instruction 0");

        send_byte(8'h3C);
        send_byte(8'h01);
        send_byte(8'h00);
        send_byte(8'h0A);

        #100;


        // =================================================
        // INSTRUCTION 1
        // MOVI R2, 20
        // 3C 02 00 14
        // =================================================

        $display("");
        $display("Sending Instruction 1");

        send_byte(8'h3C);
        send_byte(8'h02);
        send_byte(8'h00);
        send_byte(8'h14);

        #100;


        // =================================================
        // INSTRUCTION 2
        // ADD R3, R1, R2
        // 00 22 18 00
        // =================================================

        $display("");
        $display("Sending Instruction 2");

        send_byte(8'h00);
        send_byte(8'h22);
        send_byte(8'h18);
        send_byte(8'h00);

        #100;


        // =================================================
        // INSTRUCTION 3
        // HLT
        // FC 00 00 00
        // =================================================

        $display("");
        $display("Sending Instruction 3");

        send_byte(8'hFC);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h00);

        #100;


        // =================================================
        // END PROGRAM
        // FFFFFFFF
        // =================================================

        $display("");
        $display("Sending END PROGRAM");

        send_byte(8'hFF);
        send_byte(8'hFF);
        send_byte(8'hFF);
        send_byte(8'hFF);

        #100;


        // =================================================
        // FINISH
        // =================================================

        $display("");
        $display("==============================================");
        $display("PROGRAM LOADING TEST FINISHED");
        $display("==============================================");

        $finish;

    end


    // =====================================================
    // MONITOR
    // =====================================================

    always @(posedge clk) begin

        if (write_enable) begin

            $display(
                "WRITE: Address = %0d | Data = %h",
                write_address,
                write_data
            );

        end

        if (program_loaded) begin

            $display(
                "PROGRAM LOADED = 1"
            );

        end

    end

endmodule