# 32-bit Five-Stage Pipelined CPU on Nexys A7

A Verilog implementation of a 32-bit, five-stage pipelined CPU, together with a small assembly language, Python assembler/IDE, behavioral simulation flow, and UART-based programming/debugging for the Digilent Nexys A7-100T FPGA board.

The Vivado project targets the Artix-7 device `xc7a100tcsg324-1` and was created with Vivado 2025.1. The design uses the board's 100 MHz clock and onboard USB-UART bridge.

For step-by-step setup, simulation, FPGA upload, and troubleshooting, see the [CPU Programmer User Manual](CPU_Programmer_User_Manual.pdf). Keep the PDF in the repository root with this README so the link works on GitHub.

## Contents

- [Features](#features)
- [Architecture](#architecture)
- [Instruction set](#instruction-set)
- [Assembly language](#assembly-language)
- [Project structure](#project-structure)
- [Requirements](#requirements)
- [Launch the assembler IDE](#launch-the-assembler-ide)
- [Run a behavioral simulation](#run-a-behavioral-simulation)
- [Build and program the FPGA](#build-and-program-the-fpga)
- [Program the CPU over UART](#program-the-cpu-over-uart)
- [UART debug packet](#uart-debug-packet)
- [Memory and reset behavior](#memory-and-reset-behavior)
- [Current simulation example](#current-simulation-example)
- [Troubleshooting](#troubleshooting)
- [Important project notes](#important-project-notes)

## Features

- 32-bit datapath and 32 general-purpose architectural registers (`R0`-`R31`).
- Five pipeline stages: Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory Access (MEM), and Write Back (WB).
- Integer arithmetic, bitwise logic, signed comparisons, multiplication, immediate operations, load/store, conditional branches, jumps, and halt.
- Pipeline registers between stages, a forwarding unit, a stalling unit, and control logic for branch/jump handling.
- 4096-word instruction memory and 1024-word data memory in the RTL.
- A Python/Tkinter assembly editor and assembler that displays the generated machine words.
- Two run paths: behavioral simulation in Vivado XSim and programming a physical Nexys A7 through UART.
- UART debug monitor that periodically sends the program counter and all 32 registers, then sends a final halted-state packet when the CPU reaches `HLT`.

## Architecture

The main datapath is divided into these stages:

| Stage | Main responsibility | Related source files |
|---|---|---|
| IF | Program counter, instruction fetch, next-PC selection | `IF_stage.v`, `program_counter.v`, `ins_mem.v`, `pc_next_logic.v` |
| ID | Instruction decode, control signals, register reads, immediate generation | `ID_stage.v`, `instruction_decoder.v`, `control_unit.v`, `immidiate_generator.v`, `register_memory.v` |
| EX | ALU operations, operand selection, multiply datapath | `ex_stage.v`, `alu.v`, `alu_input_mux.v`, `mul_unit.v` |
| MEM | Data-memory access | `mem_stage.v`, `data_memory.v` |
| WB | Select and write a result into the register file | `wb_stage.v`, `mem_wb_reg.v`, `register_memory.v` |

Pipeline state is carried by `if_id_reg.v`, `id_ex_reg.v`, `ex_mem_reg.v`, and `mem_wb_reg.v`. `forwarding_unit.v` handles data forwarding and `Stalling_unit.v` identifies dependencies that require a stall. `cpu_top.v` connects the CPU stages, UART receiver, program loader, debug monitor, and UART transmitter. `nexys_a7_top.v` is the FPGA-facing top module.

### Top-level hardware

- **Vivado top module:** `nexys_a7_top`
- **CPU integration module:** `cpu_top`
- **Target board:** Digilent Nexys A7-100T
- **FPGA part:** `xc7a100tcsg324-1`
- **Clock:** 100 MHz; XDC period is 10 ns
- **Reset:** external `resetn` input is active-low; `nexys_a7_top.v` converts it to the active-high internal reset

## Instruction set

Registers are written as `R0` through `R31`. Mnemonics are case-insensitive in the assembler. The supported mnemonics and operand formats are listed below.

| Instruction | Syntax | Meaning |
|---|---|---|
| `MOVI` | `MOVI Rt, immediate` | Load a 16-bit immediate into `Rt`; the immediate is zero-extended |
| `ADD` | `ADD Rd, Rs, Rt` | `Rd = Rs + Rt` |
| `SUB` | `SUB Rd, Rs, Rt` | `Rd = Rs - Rt` |
| `AND` | `AND Rd, Rs, Rt` | Bitwise AND |
| `OR` | `OR Rd, Rs, Rt` | Bitwise OR |
| `SLT` | `SLT Rd, Rs, Rt` | Set `Rd` to 1 if signed `Rs < Rt`, otherwise 0 |
| `MUL` | `MUL Rd, Rs, Rt` | Multiply `Rs` by `Rt` and write the 32-bit result to `Rd` |
| `MOV` | `MOV Rd, Rs` | Copy `Rs` to `Rd` |
| `ADDI` | `ADDI Rt, Rs, immediate` | Add a sign-extended immediate to `Rs` |
| `SUBI` | `SUBI Rt, Rs, immediate` | Subtract a sign-extended immediate from `Rs` |
| `SLTI` | `SLTI Rt, Rs, immediate` | Set `Rt` to 1 if signed `Rs < immediate`, otherwise 0 |
| `LW` | `LW Rt, offset(Rs)` | Load a 32-bit word from data memory at `Rs + offset` |
| `SW` | `SW Rt, offset(Rs)` | Store a 32-bit word to data memory at `Rs + offset` |
| `BEQZ` | `BEQZ Rs, label` | Branch if `Rs == 0` |
| `BNEQZ` | `BNEQZ Rs, label` | Branch if `Rs != 0` |
| `J` | `J label` | Jump to a label |
| `HLT` | `HLT` | Halt CPU execution |

The assembler accepts decimal and Python-style base-prefixed integer literals supported by `int(value, 0)`, such as `16`, `0x10`, and `0b10000`. Immediate values are checked against the assembler's 16-bit range `-32768` through `65535`. Except for `MOVI`, the RTL sign-extends 16-bit immediates; `MOVI` zero-extends them. A negative `MOVI` therefore becomes its 16-bit bit pattern after encoding and is then zero-extended.

### Assembly example

```asm
# Count R1 down from 5 to zero.
MOVI R1, 5
MOVI R2, 1

LOOP:
SUBI R1, R1, 1
BNEQZ R1, LOOP

MOV R3, R1
HLT
```

Use `#` for comments. Labels use the form `LABEL:` and can be referenced by `BEQZ`, `BNEQZ`, and `J`. Put `HLT` at the end of a program so that the CPU stops and the monitor can report the final state.

### Instruction encodings

The assembler generates 32-bit words:

- **R-type:** opcode `[31:26]`, `rs` `[25:21]`, `rt` `[20:16]`, `rd` `[15:11]`, and zero-filled lower bits `[10:0]`.
- **I-type:** opcode `[31:26]`, `rs` `[25:21]`, `rt` `[20:16]`, and immediate `[15:0]`.
- **Branch:** opcode `[31:26]`, source register `[25:21]`, and a 16-bit PC-relative instruction offset. The assembler resolves labels and calculates the offset.
- **Jump:** opcode `[31:26]` and a target instruction index; the CPU forms the byte address internally.
- **HLT:** opcode `111111`, encoded by the assembler as `0xFC000000`.

The GUI appends `0xFFFFFFFF` as a **program-loader end marker** after the assembled program. It is not a source-level instruction to add manually. The UART loader uses it to determine when all instruction words have arrived and then releases the CPU from its loading reset.

## Project structure

The ZIP includes the Vivado project and its generated working files. The main files are:

```text
cpu_32bit/
|-- cpu_32bit.xpr
|-- assembler.py
|-- cpu_assembler_gui_fresh.py
|-- cpu_assembler_gui_uart_diagnostic.py
|-- run_simulation_fresh.bat
|-- run_simulation_fresh.tcl
|-- simulation_result.json          # Example result from a previous run
|-- cpu_execution_trace.txt         # Existing trace/debug output
|-- cpu_32bit.srcs/
|   |-- sources_1/new/               # Synthesizable RTL modules
|   |-- constrs_1/new/nexys_a7_top.xdc
|   `-- sim_1/new/
|       |-- cpu_sim_tb.v
|       |-- debug_moniter_uart_tb.v
|       `-- program_counter_tb.v
|-- backup/                          # Older GUI/simulation files
|-- cpu_32bit.runs/                  # Vivado synthesis/implementation outputs
|-- cpu_32bit.cache/                 # Vivado cache
`-- cpu_32bit.gen/                   # Generated Vivado IP output
```

### Key RTL files

| File | Purpose |
|---|---|
| `nexys_a7_top.v` | Physical FPGA interface and reset polarity conversion |
| `cpu_top.v` | Top-level CPU integration, reset gating, loader, UART and debug connections |
| `IF_stage.v`, `ID_stage.v`, `ex_stage.v`, `mem_stage.v`, `wb_stage.v` | Pipeline stages |
| `if_id_reg.v`, `id_ex_reg.v`, `ex_mem_reg.v`, `mem_wb_reg.v` | Pipeline registers |
| `control_unit.v`, `instruction_decoder.v`, `immidiate_generator.v` | Instruction decode and control/immediate generation |
| `alu.v`, `alu_input_mux.v`, `mul_unit.v` | Execution datapath |
| `forwarding_unit.v`, `Stalling_unit.v` | Dependency forwarding and stall logic |
| `register_memory.v` | 32 x 32-bit register file; `R0` is hardwired to zero in reads and protected from writes |
| `ins_mem.v`, `data_memory.v` | Instruction and data memory |
| `uart.v`, `uart_program_loader.v`, `uart_tx.v`, `debug_moniter.v` | UART receive/transmit, program loading and CPU status output |
| `cpu_sim_tb.v` | Testbench that loads `program.hex` through the UART receive path, waits for `HLT`, and writes JSON state |
| `nexys_a7_top.xdc` | Clock, UART, and reset pin constraints |
| `assembler.py` | Assembly-to-machine-code functions |
| `cpu_assembler_gui_fresh.py` | Main GUI for editing, assembling, simulating, and FPGA monitoring |
| `cpu_assembler_gui_uart_diagnostic.py` | Alternate UART diagnostic GUI variant |

## Requirements

- Windows is the simplest supported environment for the supplied `.bat` scripts.
- Python 3 installed.
- Tkinter available in the Python installation (normally included with the standard Windows installer).
- `pyserial` for the physical FPGA UART connection:

  ```bash
  pip install pyserial
  ```

- AMD/Xilinx Vivado 2025.1 with the Nexys A7 board files for the simulation and FPGA build flows.
- A Digilent Nexys A7-100T board and USB cable for hardware operation.

## Launch the assembler IDE

Open a terminal in the directory containing `assembler.py` and `cpu_assembler_gui_fresh.py`, then run:

```bash
python cpu_assembler_gui_fresh.py
```

The GUI includes an assembly editor, generated machine-code view, CPU register monitor, status indicators, COM-port controls, and two modes: **Simulation** and **Nexys A7**. Save the assembly source as a `.asm` file before running it so the generated `program.hex` is stored alongside that source.

Useful keyboard shortcuts:

| Shortcut | Action |
|---|---|
| `F5` | Assemble current source |
| `F6` | Assemble and send to FPGA (FPGA mode, UART connected) |
| `F7` | Build/run simulation (Simulation mode) |

## Run a behavioral simulation

The simulation testbench uses Vivado XSim and the same UART receive/program-loader path used by the physical board.

1. Open `cpu_assembler_gui_fresh.py` and save a valid `.asm` program.
2. Select **Simulation** mode.
3. Confirm the simulation command in **Tools / Simulation Settings** (default: `run_simulation_fresh.bat`) and the result name (default: `simulation_result.json`).
4. Click **Build / Sim** or press `F7`.
5. The GUI assembles the program, writes `program.hex`, launches the simulation script, reads the resulting JSON, and updates the PC/register monitor.
6. Check the reported status. A finished program should report `HALTED` when it reaches `HLT`; a timeout indicates that execution did not reach a halt before the testbench limit.

The testbench reads one 32-bit hex word per line, transmits it through simulated UART at 921600 baud, sends the loader end marker, waits for `program_loaded`, and then waits for `debug_halted`. On completion it writes the PC, halt flag, status, number of program words, execution cycle count, last instruction, unknown-register count, and all 32 register values to `simulation_result.json`.

**Path configuration is required on other machines.** The supplied scripts contain paths from the original Windows setup: `D:\assembler\cpu_32bit.xpr`, `D:\assembler\program.hex`, and `D:\assembler\simulation_result.json`; the batch file also points to `D:\2025.1\Vivado\bin`. For an unchanged script run, place the project at the expected paths. Otherwise, update the paths consistently in `run_simulation_fresh.bat`, `run_simulation_fresh.tcl`, and the `CPU_PROGRAM_HEX_PATH` / `CPU_RESULT_JSON_PATH` macros in `cpu_sim_tb.v`, and ensure the GUI's simulation command/result settings match the location of the generated files.

## Build and program the FPGA

1. Open `cpu_32bit.xpr` in Vivado 2025.1.
2. Verify that `nexys_a7_top` is the synthesis top module and that `nexys_a7_top.xdc` is enabled.
3. Run **Run Synthesis**, then **Run Implementation**, then **Generate Bitstream**.
4. Open **Hardware Manager**, connect to the target, and program the FPGA with the generated bitstream (the archived project contains `cpu_32bit.runs/impl_1/nexys_a7_top.bit` from an earlier build).
5. Connect the board to the host through the Nexys A7 USB-UART connection.

The XDC assignments used by the project are:

| Signal | Nexys A7 pin | Purpose |
|---|---|---|
| `clk` | `E3` | 100 MHz board clock |
| `uart_rx_pin` | `C4` | Host-to-FPGA UART data |
| `uart_tx_pin` | `D4` | FPGA-to-host UART debug data |
| `resetn` | `C12` | Active-low reset input |

## Program the CPU over UART

1. Program the FPGA with the bitstream and release the board reset button.
2. Launch `cpu_assembler_gui_fresh.py` and select **Nexys A7** mode.
3. Click **Refresh COM Ports**, select the COM port assigned to the board's USB-UART bridge, and set the baud rate to `921600`.
4. Click **Connect**. UART uses **8 data bits, no parity, 1 stop bit (8-N-1)**.
5. Open or type the assembly program, include `HLT`, and click **Assemble & Send** / press `F6`.
6. The GUI appends the `0xFFFFFFFF` loader marker and sends the 32-bit words MSB byte first. The loader writes the words to instruction memory and starts the CPU after receiving the marker.
7. Watch the PC, R0-R31, status, and received-packet count in the CPU monitor. The monitor sends a final packet with the halt flag set when `HLT` is reached.

When uploading a new program after a previous program has been loaded, reset the board first so the UART program loader returns to its waiting state. The status message **Program sent successfully** confirms that the host completed sending bytes; use the CPU monitor's incoming packets and `HALTED` status to verify execution.

## UART debug packet

The debug monitor transmits fixed-size 134-byte packets at a default interval of 10,000,000 clock cycles (about 100 ms at 100 MHz).

| Bytes | Contents |
|---|---|
| `0` | Header byte `0xAA` |
| `1-4` | Program counter, 32-bit big-endian |
| `5-132` | R0 through R31, each 32-bit big-endian (4 bytes/register) |
| `133` | Halt flag (`0` = running, `1` = halted) |

The GUI scans for the `0xAA` header and decodes the packet. Register values are displayed in hexadecimal and signed decimal representation. Because the protocol has a single-byte header and no additional checksum, this is a lightweight development monitor rather than a robust general-purpose serial protocol.

## Memory and reset behavior

- **Register file:** 32 registers x 32 bits. `R0` always reads as zero, and writes to `R0` are ignored. The register file is reset to zero when CPU reset is asserted.
- **Instruction memory:** 4096 x 32 bits. Instructions are written sequentially by the program loader. The PC is byte-addressed and advances by 4 during normal sequential execution.
- **Data memory:** 1024 x 32-bit words. The RTL indexes data memory by `address / 4`; use word-aligned byte addresses (0, 4, 8, ...). The memory is written by `SW` and read by `LW`. The current RTL does not include runtime bounds or alignment checks.
- **Program loading:** the CPU is held in reset until the UART loader receives `0xFFFFFFFF` as the end marker. This marker is appended automatically by the GUI and handled separately by the testbench.
- **Halt:** source-level `HLT` has machine encoding `0xFC000000`. It is separate from the loader's `0xFFFFFFFF` end marker.
- **Data-memory initialization:** the provided RTL does not explicitly initialize the data-memory array on reset. A program should write locations before relying on their contents.

## Current simulation example

The included `simulation_result.json` is a snapshot from a previous simulation. It reports `HALTED`, `errors: 0`, `unknown_register_count: 0`, 238 program words, and 125 execution cycles. This describes that recorded run only; results depend on the assembly program being tested.

## Troubleshooting

| Symptom | Checks |
|---|---|
| Python GUI will not start | Run from the project directory; confirm Python and Tkinter are installed. |
| COM ports are missing | Connect/power the board, check the USB cable/driver, then click **Refresh COM Ports**. |
| Serial connection fails | Close other serial-terminal applications using the same COM port. Confirm baud `921600` and 8-N-1. |
| GUI says the program was sent but no CPU packets arrive | Reset the board before a new upload, confirm the correct COM port and bitstream, and check the UART pins in the XDC. The send message alone is not proof that the CPU has executed the program. |
| Simulation cannot find project or hex file | Update the hard-coded `D:/assembler` paths and Vivado installation path in the `.bat`, `.tcl`, and testbench macros. |
| Simulation times out | Confirm that the source reaches `HLT`, labels are correct, and the program is not stuck in a branch/jump loop. |
| `LW`/`SW` data looks wrong | Confirm the effective address is word-aligned and that the program stores data before loading it. |
| Assembler reports an error | Check the exact operand order, register range `R0`-`R31`, immediate range, memory syntax `offset(Rs)`, and label spelling. |

## Important project notes

- The archive contains Vivado-generated folders (`.cache`, `.gen`, `.runs`, and related files), simulation outputs, and backups. They are not all hand-written RTL; they are project/build artifacts. For a smaller GitHub repository, retain the active RTL, XDC, testbenches, assembler/GUI, simulation scripts, and project configuration, and only keep generated files that you intentionally want to distribute.
- `immidiate_generator.v` and `debug_moniter.v` are the actual filenames in the project; their spellings are preserved in this documentation to match the source tree.
- The helper `uart_to_program_loader.v` is included in the archive but is not listed among the active RTL sources in the supplied `.xpr` configuration. The main hardware path uses `uart.v`, `uart_program_loader.v`, and `uart_tx.v`.
- The project uses Windows-specific simulation scripts as supplied. Review their paths before publishing instructions for users on another machine.
