`timescale 1ns / 1ps

module debug_monitor #(
    parameter integer CLK_FREQ         = 100_000_000,
    parameter integer MONITOR_INTERVAL = 10_000_000
)(
    input        clk,
    input        reset,

    // =====================================================
    // CPU DEBUG INPUTS
    // =====================================================

    input  [31:0] debug_pc,
    input         debug_halted,

    // =====================================================
    // REGISTER FILE DEBUG READ PORT
    // =====================================================

    output reg [4:0] debug_reg_addr,
    input      [31:0] debug_reg_data_read,

    // =====================================================
    // UART TX INTERFACE
    // =====================================================

    output reg [7:0] tx_data,
    output reg       tx_valid,
    input            tx_busy
);

    // =====================================================
    // FSM STATES
    // =====================================================

    localparam [3:0]
        IDLE         = 4'd0,
        CAPTURE_REG  = 4'd1,
        NEXT_REG     = 4'd2,
        LOAD_BYTE    = 4'd3,
        SEND_BYTE    = 4'd4,
        WAIT_BUSY    = 4'd5,
        WAIT_IDLE    = 4'd6;

    reg [3:0] state;

    // =====================================================
    // MONITOR INTERVAL
    // =====================================================

    reg [31:0] interval_counter;

    // =====================================================
    // REGISTER CAPTURE
    // =====================================================

    reg [31:0] register_buffer [0:31];

    reg [5:0] capture_index;

    // =====================================================
    // PACKET TRANSMISSION
    // =====================================================

    reg [7:0] packet_byte_index;

    reg [31:0] pc_buffer;
    reg        halt_buffer;

    // Set after the final HALT-status packet has been transmitted.
    // This prevents periodic debug packets from continuing after HLT.
    reg        halt_packet_sent;

    // =====================================================
    // INTERVAL COUNTER
    // =====================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            interval_counter <= 32'd0;

        end

        else if (state == IDLE) begin

            if (interval_counter >= MONITOR_INTERVAL - 1)
                interval_counter <= 32'd0;

            else
                interval_counter <= interval_counter + 1'b1;

        end

    end

    // =====================================================
    // REGISTER BUFFER WRITE
    // Use a clock-only process so the register buffer is not inferred
    // as an asynchronously set/reset memory by the main FSM process.
    // Every buffer element is overwritten before packet transmission.
    // =====================================================

    always @(posedge clk) begin
        if (!reset && state == CAPTURE_REG && capture_index < 6'd32) begin
            register_buffer[capture_index] <= debug_reg_data_read;
        end
    end

    // =====================================================
    // MAIN FSM
    // =====================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            state <= IDLE;

            debug_reg_addr <= 5'd0;

            capture_index <= 6'd0;

            packet_byte_index <= 8'd0;

            pc_buffer <= 32'd0;
            halt_buffer <= 1'b0;
            halt_packet_sent <= 1'b0;

            tx_data <= 8'h00;
            tx_valid <= 1'b0;

        end

        else begin

            // tx_valid is a one-clock pulse
            tx_valid <= 1'b0;

            case (state)

                // =================================================
                // IDLE
                // =================================================

                IDLE: begin

                    // Continue periodic packets while running. Once HALT is
                    // asserted, allow exactly one final packet with halt=1.
                    if ((interval_counter >= MONITOR_INTERVAL - 1) &&
                        (!debug_halted || !halt_packet_sent)) begin

                        // Capture PC and HALT
                        pc_buffer <= debug_pc;
                        halt_buffer <= debug_halted;

                        // Start reading R0
                        capture_index <= 6'd0;
                        debug_reg_addr <= 5'd0;

                        state <= CAPTURE_REG;

                    end

                end


                // =================================================
                // CAPTURE REGISTER
                // =================================================

                CAPTURE_REG: begin

                    // The register buffer is written by the separate
                    // clock-only process above.
                    if (capture_index == 6'd31) begin

                        // All 32 registers captured
                        packet_byte_index <= 8'd0;

                        state <= LOAD_BYTE;

                    end

                    else begin

                        capture_index <= capture_index + 1'b1;

                        debug_reg_addr <= capture_index + 1'b1;

                        state <= NEXT_REG;

                    end

                end


                // =================================================
                // NEXT REGISTER
                // =================================================

                NEXT_REG: begin

                    // Allow debug_reg_addr to settle for one clock
                    state <= CAPTURE_REG;

                end


                // =================================================
                // LOAD PACKET BYTE
                // =================================================

                LOAD_BYTE: begin

                    if (!tx_busy) begin

                        case (packet_byte_index)

                            // -------------------------------------------------
                            // BYTE 0 = PACKET HEADER
                            // -------------------------------------------------

                            8'd0:
                                tx_data <= 8'hAA;


                            // -------------------------------------------------
                            // BYTES 1-4 = PC
                            // -------------------------------------------------

                            8'd1:
                                tx_data <= pc_buffer[31:24];

                            8'd2:
                                tx_data <= pc_buffer[23:16];

                            8'd3:
                                tx_data <= pc_buffer[15:8];

                            8'd4:
                                tx_data <= pc_buffer[7:0];


                            // -------------------------------------------------
                            // BYTES 5-132 = R0-R31
                            // -------------------------------------------------

                            // R0
                            8'd5:
                                tx_data <= register_buffer[0][31:24];

                            8'd6:
                                tx_data <= register_buffer[0][23:16];

                            8'd7:
                                tx_data <= register_buffer[0][15:8];

                            8'd8:
                                tx_data <= register_buffer[0][7:0];


                            // R1
                            8'd9:
                                tx_data <= register_buffer[1][31:24];

                            8'd10:
                                tx_data <= register_buffer[1][23:16];

                            8'd11:
                                tx_data <= register_buffer[1][15:8];

                            8'd12:
                                tx_data <= register_buffer[1][7:0];


                            // R2
                            8'd13:
                                tx_data <= register_buffer[2][31:24];

                            8'd14:
                                tx_data <= register_buffer[2][23:16];

                            8'd15:
                                tx_data <= register_buffer[2][15:8];

                            8'd16:
                                tx_data <= register_buffer[2][7:0];


                            // R3
                            8'd17:
                                tx_data <= register_buffer[3][31:24];

                            8'd18:
                                tx_data <= register_buffer[3][23:16];

                            8'd19:
                                tx_data <= register_buffer[3][15:8];

                            8'd20:
                                tx_data <= register_buffer[3][7:0];


                            // R4
                            8'd21:
                                tx_data <= register_buffer[4][31:24];

                            8'd22:
                                tx_data <= register_buffer[4][23:16];

                            8'd23:
                                tx_data <= register_buffer[4][15:8];

                            8'd24:
                                tx_data <= register_buffer[4][7:0];


                            // R5
                            8'd25:
                                tx_data <= register_buffer[5][31:24];

                            8'd26:
                                tx_data <= register_buffer[5][23:16];

                            8'd27:
                                tx_data <= register_buffer[5][15:8];

                            8'd28:
                                tx_data <= register_buffer[5][7:0];


                            // R6
                            8'd29:
                                tx_data <= register_buffer[6][31:24];

                            8'd30:
                                tx_data <= register_buffer[6][23:16];

                            8'd31:
                                tx_data <= register_buffer[6][15:8];

                            8'd32:
                                tx_data <= register_buffer[6][7:0];


                            // R7
                            8'd33:
                                tx_data <= register_buffer[7][31:24];

                            8'd34:
                                tx_data <= register_buffer[7][23:16];

                            8'd35:
                                tx_data <= register_buffer[7][15:8];

                            8'd36:
                                tx_data <= register_buffer[7][7:0];


                            // R8
                            8'd37:
                                tx_data <= register_buffer[8][31:24];

                            8'd38:
                                tx_data <= register_buffer[8][23:16];

                            8'd39:
                                tx_data <= register_buffer[8][15:8];

                            8'd40:
                                tx_data <= register_buffer[8][7:0];


                            // R9
                            8'd41:
                                tx_data <= register_buffer[9][31:24];

                            8'd42:
                                tx_data <= register_buffer[9][23:16];

                            8'd43:
                                tx_data <= register_buffer[9][15:8];

                            8'd44:
                                tx_data <= register_buffer[9][7:0];


                            // R10
                            8'd45:
                                tx_data <= register_buffer[10][31:24];

                            8'd46:
                                tx_data <= register_buffer[10][23:16];

                            8'd47:
                                tx_data <= register_buffer[10][15:8];

                            8'd48:
                                tx_data <= register_buffer[10][7:0];


                            // R11
                            8'd49:
                                tx_data <= register_buffer[11][31:24];

                            8'd50:
                                tx_data <= register_buffer[11][23:16];

                            8'd51:
                                tx_data <= register_buffer[11][15:8];

                            8'd52:
                                tx_data <= register_buffer[11][7:0];


                            // R12
                            8'd53:
                                tx_data <= register_buffer[12][31:24];

                            8'd54:
                                tx_data <= register_buffer[12][23:16];

                            8'd55:
                                tx_data <= register_buffer[12][15:8];

                            8'd56:
                                tx_data <= register_buffer[12][7:0];


                            // R13
                            8'd57:
                                tx_data <= register_buffer[13][31:24];

                            8'd58:
                                tx_data <= register_buffer[13][23:16];

                            8'd59:
                                tx_data <= register_buffer[13][15:8];

                            8'd60:
                                tx_data <= register_buffer[13][7:0];


                            // R14
                            8'd61:
                                tx_data <= register_buffer[14][31:24];

                            8'd62:
                                tx_data <= register_buffer[14][23:16];

                            8'd63:
                                tx_data <= register_buffer[14][15:8];

                            8'd64:
                                tx_data <= register_buffer[14][7:0];


                            // R15
                            8'd65:
                                tx_data <= register_buffer[15][31:24];

                            8'd66:
                                tx_data <= register_buffer[15][23:16];

                            8'd67:
                                tx_data <= register_buffer[15][15:8];

                            8'd68:
                                tx_data <= register_buffer[15][7:0];


                            // R16
                            8'd69:
                                tx_data <= register_buffer[16][31:24];

                            8'd70:
                                tx_data <= register_buffer[16][23:16];

                            8'd71:
                                tx_data <= register_buffer[16][15:8];

                            8'd72:
                                tx_data <= register_buffer[16][7:0];


                            // R17
                            8'd73:
                                tx_data <= register_buffer[17][31:24];

                            8'd74:
                                tx_data <= register_buffer[17][23:16];

                            8'd75:
                                tx_data <= register_buffer[17][15:8];

                            8'd76:
                                tx_data <= register_buffer[17][7:0];


                            // R18
                            8'd77:
                                tx_data <= register_buffer[18][31:24];

                            8'd78:
                                tx_data <= register_buffer[18][23:16];

                            8'd79:
                                tx_data <= register_buffer[18][15:8];

                            8'd80:
                                tx_data <= register_buffer[18][7:0];


                            // R19
                            8'd81:
                                tx_data <= register_buffer[19][31:24];

                            8'd82:
                                tx_data <= register_buffer[19][23:16];

                            8'd83:
                                tx_data <= register_buffer[19][15:8];

                            8'd84:
                                tx_data <= register_buffer[19][7:0];


                            // R20
                            8'd85:
                                tx_data <= register_buffer[20][31:24];

                            8'd86:
                                tx_data <= register_buffer[20][23:16];

                            8'd87:
                                tx_data <= register_buffer[20][15:8];

                            8'd88:
                                tx_data <= register_buffer[20][7:0];


                            // R21
                            8'd89:
                                tx_data <= register_buffer[21][31:24];

                            8'd90:
                                tx_data <= register_buffer[21][23:16];

                            8'd91:
                                tx_data <= register_buffer[21][15:8];

                            8'd92:
                                tx_data <= register_buffer[21][7:0];


                            // R22
                            8'd93:
                                tx_data <= register_buffer[22][31:24];

                            8'd94:
                                tx_data <= register_buffer[22][23:16];

                            8'd95:
                                tx_data <= register_buffer[22][15:8];

                            8'd96:
                                tx_data <= register_buffer[22][7:0];


                            // R23
                            8'd97:
                                tx_data <= register_buffer[23][31:24];

                            8'd98:
                                tx_data <= register_buffer[23][23:16];

                            8'd99:
                                tx_data <= register_buffer[23][15:8];

                            8'd100:
                                tx_data <= register_buffer[23][7:0];


                            // R24
                            8'd101:
                                tx_data <= register_buffer[24][31:24];

                            8'd102:
                                tx_data <= register_buffer[24][23:16];

                            8'd103:
                                tx_data <= register_buffer[24][15:8];

                            8'd104:
                                tx_data <= register_buffer[24][7:0];


                            // R25
                            8'd105:
                                tx_data <= register_buffer[25][31:24];

                            8'd106:
                                tx_data <= register_buffer[25][23:16];

                            8'd107:
                                tx_data <= register_buffer[25][15:8];

                            8'd108:
                                tx_data <= register_buffer[25][7:0];


                            // R26
                            8'd109:
                                tx_data <= register_buffer[26][31:24];

                            8'd110:
                                tx_data <= register_buffer[26][23:16];

                            8'd111:
                                tx_data <= register_buffer[26][15:8];

                            8'd112:
                                tx_data <= register_buffer[26][7:0];


                            // R27
                            8'd113:
                                tx_data <= register_buffer[27][31:24];

                            8'd114:
                                tx_data <= register_buffer[27][23:16];

                            8'd115:
                                tx_data <= register_buffer[27][15:8];

                            8'd116:
                                tx_data <= register_buffer[27][7:0];


                            // R28
                            8'd117:
                                tx_data <= register_buffer[28][31:24];

                            8'd118:
                                tx_data <= register_buffer[28][23:16];

                            8'd119:
                                tx_data <= register_buffer[28][15:8];

                            8'd120:
                                tx_data <= register_buffer[28][7:0];


                            // R29
                            8'd121:
                                tx_data <= register_buffer[29][31:24];

                            8'd122:
                                tx_data <= register_buffer[29][23:16];

                            8'd123:
                                tx_data <= register_buffer[29][15:8];

                            8'd124:
                                tx_data <= register_buffer[29][7:0];


                            // R30
                            8'd125:
                                tx_data <= register_buffer[30][31:24];

                            8'd126:
                                tx_data <= register_buffer[30][23:16];

                            8'd127:
                                tx_data <= register_buffer[30][15:8];

                            8'd128:
                                tx_data <= register_buffer[30][7:0];


                            // R31
                            8'd129:
                                tx_data <= register_buffer[31][31:24];

                            8'd130:
                                tx_data <= register_buffer[31][23:16];

                            8'd131:
                                tx_data <= register_buffer[31][15:8];

                            8'd132:
                                tx_data <= register_buffer[31][7:0];


                            // HALT
                            8'd133:
                                tx_data <= {7'b0, halt_buffer};


                            default:
                                tx_data <= 8'h00;

                        endcase

                        state <= SEND_BYTE;

                    end

                end


                // =================================================
                // SEND BYTE
                // =================================================

                SEND_BYTE: begin

                    tx_valid <= 1'b1;

                    state <= WAIT_BUSY;

                end


                // =================================================
                // WAIT FOR UART TO START
                // =================================================

                WAIT_BUSY: begin

                    if (tx_busy)
                        state <= WAIT_IDLE;

                end


                // =================================================
                // WAIT FOR UART TO FINISH
                // =================================================

                WAIT_IDLE: begin

                    if (!tx_busy) begin

                        if (packet_byte_index == 8'd133) begin

                            // Complete 134-byte packet. If this snapshot
                            // reports HALT, mark the final packet as sent.
                            packet_byte_index <= 8'd0;
                            if (halt_buffer)
                                halt_packet_sent <= 1'b1;

                            state <= IDLE;

                        end

                        else begin

                            packet_byte_index <= packet_byte_index + 1'b1;

                            state <= LOAD_BYTE;

                        end

                    end

                end


                default: begin

                    state <= IDLE;

                    debug_reg_addr <= 5'd0;

                    capture_index <= 6'd0;

                    packet_byte_index <= 8'd0;

                end

            endcase

        end

    end

endmodule