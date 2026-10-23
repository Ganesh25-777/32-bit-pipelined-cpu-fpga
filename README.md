# 32-bit Five-Stage Pipelined CPU on Nexys A7

A 32-bit CPU implemented in Verilog with a five-stage pipeline, a custom assembly language and Python/Tkinter assembler IDE. The project supports behavioral simulation in AMD/Xilinx Vivado XSim and programming/debugging on a Digilent Nexys A7-100T FPGA over UART.

**FPGA target:** Artix-7 `xc7a100tcsg324-1`  
**Vivado version used:** 2025.1  
**Clock:** 100 MHz  
**Main FPGA top:** `nexys_a7_top`  
**Simulation testbench:** `cpu_sim_tb`

> **Important: the paths shown in this repository are the paths on the original development setup.** They are not universal paths and will not automatically match another computer. The current reference paths are `D:\cpu_32bit` for the project and `D:\2025.1\Vivado\bin` for the Vivado `bin` directory. If you clone/extract the project to a different folder, use a different drive, or install Vivado elsewhere, replace the corresponding paths in the BAT file, Tcl script, and Verilog testbench with the locations on your own computer. All three simulation components must point to the same project folder. See **Required simulation paths and relocating the project** below before running XSim.

For the step-by-step setup and programming workflow, see [CPU_Programmer_User_Manual.pdf](CPU_Programmer_User_Manual.pdf).

## Features

- 32-bit datapath and 32 architectural registers (`R0`-`R31`); `R0` reads as zero and writes are ignored.
- Five pipeline stages: Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory (MEM) and Write Back (WB).
- Arithmetic, bitwise logic, multiplication, signed comparisons, immediate instructions, load/store, conditional branches, jumps and halt.
- Pipeline registers, forwarding logic and stalling logic.
- Instruction memory and data memory implemented in RTL.
- Python/Tkinter editor and assembler that generates 32-bit machine words.
- Behavioral simulation that loads `program.hex` through the simulated UART/program-loader path and writes CPU state to `simulation_result.json`.
- UART programming and register/PC monitoring on the Nexys A7.

## Architecture

| Stage | Responsibility | Main modules |
|---|---|---|
| IF | Program counter, instruction fetch and next-PC selection | `IF_stage.v`, `program_counter.v`, `ins_mem.v`, `pc_next_logic.v` |
| ID | Decode, register reads, control and immediate generation | `ID_stage.v`, `instruction_decoder.v`, `control_unit.v`, `immidiate_generator.v`, `register_memory.v` |
| EX | ALU operations, operand selection and multiplication | `ex_stage.v`, `alu.v`, `alu_input_mux.v`, `mul_unit.v` |
| MEM | Data-memory access | `mem_stage.v`, `data_memory.v` |
| WB | Register write-back selection and write | `wb_stage.v`, `mem_wb_reg.v`, `register_memory.v` |

`if_id_reg.v`, `id_ex_reg.v`, `ex_mem_reg.v` and `mem_wb_reg.v` carry pipeline state. `forwarding_unit.v` supports data forwarding, and `Stalling_unit.v` handles dependencies that require a stall. `cpu_top.v` integrates the CPU, UART receiver, program loader, debug monitor and transmitter. `nexys_a7_top.v` connects the design to the board pins.

## Instruction set

Register names are `R0` through `R31`. The assembler accepts these mnemonics:

| Instruction | Syntax | Meaning |
|---|---|---|
| `MOVI` | `MOVI Rt, immediate` | Load a 16-bit immediate; zero-extended |
| `ADD` | `ADD Rd, Rs, Rt` | Add two registers |
| `SUB` | `SUB Rd, Rs, Rt` | Subtract `Rt` from `Rs` |
| `AND` | `AND Rd, Rs, Rt` | Bitwise AND |
| `OR` | `OR Rd, Rs, Rt` | Bitwise OR |
| `SLT` | `SLT Rd, Rs, Rt` | Set destination to 1 if signed `Rs < Rt`, otherwise 0 |
| `MUL` | `MUL Rd, Rs, Rt` | Multiply two registers; write the 32-bit result |
| `MOV` | `MOV Rd, Rs` | Copy one register to another |
| `ADDI` | `ADDI Rt, Rs, immediate` | Add a sign-extended immediate |
| `SUBI` | `SUBI Rt, Rs, immediate` | Subtract a sign-extended immediate |
| `SLTI` | `SLTI Rt, Rs, immediate` | Signed less-than comparison with an immediate |
| `LW` | `LW Rt, offset(Rs)` | Load a word from data memory at `Rs + offset` |
| `SW` | `SW Rt, offset(Rs)` | Store a word to data memory at `Rs + offset` |
| `BEQZ` | `BEQZ Rs, label` | Branch if `Rs == 0` |
| `BNEQZ` | `BNEQZ Rs, label` | Branch if `Rs != 0` |
| `J` | `J label` | Unconditional jump |
| `HLT` | `HLT` | Halt CPU execution |

The assembler accepts decimal and base-prefixed values, such as `10`, `0x10` and `0b10000`. The immediate range accepted by the assembler is `-32768` through `65535`. `MOVI` zero-extends its encoded 16-bit value; other immediate operations use signed immediates. Labels use `LABEL:` syntax and can be targeted by `BEQZ`, `BNEQZ` and `J`. Use `#` for assembly comments.

### Small assembly example

```asm
MOVI R1, 5
MOVI R2, 1
LOOP:
SUBI R1, R1, 1
BNEQZ R1, LOOP
HLT
```

The GUI creates `program.hex` from the saved source program. The program loader's `0xFFFFFFFF` end marker is added by the host GUI/testbench; do not use it as a replacement for the source-level `HLT` instruction.


### Key files

| File | Purpose |
|---|---|
| `cpu_32bit.xpr` | Vivado project configuration |
| `nexys_a7_top.v` | FPGA-facing top and reset polarity conversion |
| `cpu_top.v` | CPU integration, loading/reset control and UART/debug connections |
| `IF_stage.v`, `ID_stage.v`, `ex_stage.v`, `mem_stage.v`, `wb_stage.v` | Pipeline stages |
| `forwarding_unit.v`, `Stalling_unit.v` | Data dependency control |
| `register_memory.v`, `ins_mem.v`, `data_memory.v` | Register, instruction and data memories |
| `uart.v`, `uart_program_loader.v`, `uart_tx.v`, `debug_moniter.v` | UART, program loading and debug output |
| `nexys_a7_top.xdc` | Clock, UART and reset pin constraints |
| `cpu_sim_tb.v` | UART-based testbench; reads HEX and writes JSON |
| `assembler.py` | Assembly-to-machine-code logic |
| `cpu_assembler_gui_fresh.py` | Standard assembler GUI |
| `cpu_assembler_gui_uart_diagnostic.py` | GUI variant with additional UART transmission/reception diagnostics |
| `run_simulation_fresh.bat` | Windows launcher for batch-mode Vivado simulation |
| `run_simulation_fresh.tcl` | Opens the project and runs XSim from Tcl |

## Requirements

- Windows is assumed by the supplied `.bat` script.
- Python 3 and Tkinter.
- `pyserial` for a physical UART connection:

  ```bash
  python -m pip install pyserial
  ```

- AMD/Xilinx Vivado 2025.1 for simulation and FPGA implementation.
- Digilent Nexys A7-100T board and USB cable for hardware use.

## Start the assembler GUI

Open Command Prompt or PowerShell in `D:\cpu_32bit` and run one of the included GUIs:

```powershell
python cpu_assembler_gui_uart_diagnostic.py
```

The diagnostic version is useful when troubleshooting UART communication. The standard alternative is:

```powershell
python cpu_assembler_gui_fresh.py
```

Keep `assembler.py` in the same directory as the GUI. For the supplied simulation scripts, save your `.asm` file directly in `D:\cpu_32bit`; the GUI writes `program.hex` alongside the saved assembly source. This keeps the generated HEX in the location expected by the scripts and testbench.

Useful shortcuts: `F5` assembles, `F6` assembles and sends to FPGA in FPGA mode, and `F7` runs the simulation in Simulator mode.

## Required simulation paths and relocating the project

The paths below describe the **current/reference setup used to test this project**. They are examples tied to one Windows computer. If you install or extract the project to another location, do not keep these paths unchanged: edit each setting to match the actual location on your computer.

### Current/reference locations

| Item | Current path on the reference setup |
|---|---|
| Project root folder | `D:\cpu_32bit` |
| Vivado `bin` directory | `D:\2025.1\Vivado\bin` |
| Vivado project | `D:\cpu_32bit\cpu_32bit.xpr` |
| Batch launcher | `D:\cpu_32bit\run_simulation_fresh.bat` |
| Tcl script | `D:\cpu_32bit\run_simulation_fresh.tcl` |
| Generated machine-code input | `D:\cpu_32bit\program.hex` |
| Simulation result | `D:\cpu_32bit\simulation_result.json` |

For the current setup, verify that `D:\2025.1\Vivado\bin\vivado.bat` exists and that `D:\cpu_32bit\cpu_32bit.xpr` exists. If either file is somewhere else, use its real location in the appropriate settings.

### When using a different folder or computer

For example, if your project is at `C:\Projects\cpu_32bit` and your Vivado installation is at `C:\Xilinx\Vivado\2025.1\bin`, update all of the following. These example paths must also be changed if they do not match your own installation.

**1. Edit `run_simulation_fresh.bat`.** Update every path variable and the working directory. For the example locations above, the relevant lines would be:

```bat
set "VIVADO=C:\Xilinx\Vivado\2025.1\bin"
set "PROJECT=C:\Projects\cpu_32bit\cpu_32bit.xpr"
set "TCL=C:\Projects\cpu_32bit\run_simulation_fresh.tcl"
set "RESULT=C:\Projects\cpu_32bit\simulation_result.json"
cd /d C:\Projects\cpu_32bit
```

Also update the `program.hex` existence check in the BAT file so it checks `C:\Projects\cpu_32bit\program.hex`. `VIVADO` must be the directory that directly contains `vivado.bat`, not merely the top-level Vivado installation folder.

On the reference setup, those same lines are:

```bat
set "VIVADO=D:\2025.1\Vivado\bin"
set "PROJECT=D:\cpu_32bit\cpu_32bit.xpr"
set "TCL=D:\cpu_32bit\run_simulation_fresh.tcl"
set "RESULT=D:\cpu_32bit\simulation_result.json"
cd /d D:\cpu_32bit
```

**2. Edit `run_simulation_fresh.tcl`.** Change the `PROJECT` variable, the `program.hex` existence check, and the line that removes an old JSON result so they all use your actual project root. Example for `C:\Projects\cpu_32bit` (use forward slashes in Tcl paths):

```tcl
set PROJECT "C:/Projects/cpu_32bit/cpu_32bit.xpr"
if {![file exists $PROJECT]} {
    error "Vivado project not found: $PROJECT"
}
if {![file exists "C:/Projects/cpu_32bit/program.hex"]} {
    error "program.hex not found: C:/Projects/cpu_32bit/program.hex"
}
catch {file delete -force "C:/Projects/cpu_32bit/simulation_result.json"}
```

For the reference setup, replace `C:/Projects/cpu_32bit` in this example with `D:/cpu_32bit`.

**3. Edit the path macros in `cpu_sim_tb.v`.** Open `cpu_32bit.srcs/sim_1/new/cpu_sim_tb.v` and set both macros to your project root. Example:

```verilog
`ifndef CPU_PROGRAM_HEX_PATH
`define CPU_PROGRAM_HEX_PATH "C:/Projects/cpu_32bit/program.hex"
`endif

`ifndef CPU_RESULT_JSON_PATH
`define CPU_RESULT_JSON_PATH "C:/Projects/cpu_32bit/simulation_result.json"
`endif
```

Use forward slashes in the Verilog file paths. If the macros already exist, edit the existing definitions rather than duplicating them. Save the testbench and let Vivado recompile it.

**4. Keep the GUI output location aligned.** Save your `.asm` file directly in the project root (for the reference setup, `D:\cpu_32bit`). The GUI writes `program.hex` beside the currently saved assembly file. In the GUI's Simulation Settings, use `run_simulation_fresh.bat` as the simulation command and `simulation_result.json` as the result filename when using the project-root workflow. If your paths differ, ensure the GUI, BAT, Tcl, and testbench all point to the same files.

### Path consistency rule

The batch launcher, Tcl script, Verilog testbench macros, and the GUI-generated files must agree on the locations. If you change the project folder, update the paths in **all three simulation files** (`run_simulation_fresh.bat`, `run_simulation_fresh.tcl`, and `cpu_sim_tb.v`) and save assembly files to the configured output folder. Do not only update the `.bat` file: that can fix the project lookup but still leave XSim looking for `program.hex` or writing JSON in the old folder.

## Run a behavioral simulation

1. Confirm `D:\cpu_32bit\cpu_32bit.xpr` exists.
2. Confirm `%VIVADO%\vivado.bat` exists for the path configured in the BAT file.
3. Check the matching paths in the BAT file, Tcl file and testbench macros as described above.
4. Start the GUI and save the `.asm` file in `D:\cpu_32bit`.
5. Select **Simulator** mode. In Simulation Settings, use `run_simulation_fresh.bat` and `simulation_result.json`.
6. Click **Assemble** or **Build / Sim**. The simulation flow creates `program.hex`, clears a stale JSON result, launches Vivado in batch mode, runs `cpu_sim_tb`, and reads the new JSON into the GUI.
7. Review Build Output if the process fails. The testbench status can indicate `HALTED`, `TIMEOUT`, `FILE_ERROR`, `LOAD_TIMEOUT`, `MALFORMED_HEX`, `PROGRAM_TOO_LARGE`, `EMPTY_PROGRAM` or `UNKNOWN_STATE`.

The testbench sends program words through the same UART RX/program-loader path used by hardware. It sends 32-bit words most-significant byte first at 921600 baud, appends the `0xFFFFFFFF` loader marker, waits for execution to halt or time out, then writes the PC, halt flag, status, program-word count, execution cycles and 32 registers to JSON.

## Build and program the FPGA

1. Open `cpu_32bit.xpr` in Vivado 2025.1.
2. Verify `nexys_a7_top` is the synthesis top and that `nexys_a7_top.xdc` is enabled.
3. Run **Run Synthesis**, **Run Implementation**, then **Generate Bitstream**.
4. Open **Hardware Manager**, connect to the Nexys A7 and program the generated bitstream.
5. Connect the board to the computer over the board's USB-UART bridge.

Pin assignments used in the XDC:

| Signal | Pin | Purpose |
|---|---|---|
| `clk` | `E3` | 100 MHz board clock |
| `uart_rx_pin` | `C4` | Computer-to-FPGA UART receive |
| `uart_tx_pin` | `D4` | FPGA-to-computer debug transmit |
| `resetn` | `C12` | Active-low reset input |

## Send a program to the FPGA

1. Program the bitstream and reset the board before loading a new program.
2. Start the GUI and choose **Nexys A7** mode.
3. Click **Refresh COM Ports**, select the board's COM port, and choose `921600` baud.
4. Click **Connect**. Serial format is 8 data bits, no parity, 1 stop bit (8-N-1).
5. Open or type the assembly program; include `HLT` at the end.
6. Click **Assemble** or **Send to FPGA** (F6, where enabled).
7. Watch PC, HALT status and registers in CPU Monitor. A host-side send-complete message only means the serial port accepted the bytes; incoming monitor packets and final `HALTED` status are the better evidence of execution.

If a previous program has already loaded, reset the board before sending another because the loader has to return to its waiting state.

## UART debug packet

The debug monitor sends 134-byte packets at a default interval of 10,000,000 clock cycles (about 100 ms at 100 MHz):

| Bytes | Content |
|---|---|
| `0` | Header `0xAA` |
| `1-4` | Program counter, 32-bit big-endian |
| `5-132` | `R0`-`R31`, 4 bytes each, big-endian |
| `133` | Halt flag (`0` running, `1` halted) |

## Memory and reset notes

- The CPU has 32 32-bit registers; `R0` reads as zero and ignores writes.
- The PC uses byte addresses and advances by 4 for sequential instructions.
- Data memory is word-oriented; use word-aligned byte addresses such as 0, 4, 8, and so on for `LW` and `SW`.
- Data memory is not explicitly initialized by the supplied RTL. Store to a location before loading it if a known value is required.
- The loader uses `0xFFFFFFFF` as an end marker; `HLT` is a separate source-level instruction with encoding `0xFC000000`.

## Troubleshooting

| Error or symptom | What to check |
|---|---|
| `Vivado project not found: ...` | Check the `.xpr` path in both the BAT and Tcl files. Confirm the project exists at that exact path. |
| `Vivado not found: ...\vivado.bat` | Check `set "VIVADO=..."`; it must be the folder that contains `vivado.bat`. The configured example is `D:\2025.1\Vivado\bin`. |
| `program.hex not found` or testbench cannot open HEX | Save the `.asm` in `D:\cpu_32bit`, assemble again, and update `CPU_PROGRAM_HEX_PATH` in `cpu_sim_tb.v`. |
| Simulation completes but JSON is missing | Check `CPU_RESULT_JSON_PATH`, the Tcl result path, and the BAT `RESULT` path all use `D:/cpu_32bit/simulation_result.json` (or the same alternative path). Review Build Output and `vivado.log`. |
| `Simulation failed with exit code 1` | Read the preceding XSim/Build Output error. Exit code 1 is a wrapper failure; it does not identify the root cause on its own. |
| GUI will not launch | Run from the project folder; confirm Python 3 and Tkinter are available. |
| No COM port is visible | Check board power, USB cable and driver, then refresh COM ports. |
| No UART debug packets | Confirm the bitstream/top/XDC, baud `921600`, correct COM port and board reset state. Close other serial tools using the same port. |
| Program times out | Check control flow, branch labels, load/use behavior and that the program reaches `HLT`. |

## Repository notes

- Keep the active RTL sources, constraints, testbenches, `.xpr`, assembler, GUI, simulation scripts and this documentation in the repository.
- Generated Vivado cache/build/simulation files are often unnecessary for a source-focused GitHub repository; `.gitignore` excludes common generated outputs. Do not delete a file that your project specifically relies on without checking the `.xpr` first.
- The filenames `immidiate_generator.v` and `debug_moniter.v` are spelled this way in the source tree and are documented as-is.
- The paths `D:\cpu_32bit` and `D:\2025.1\Vivado\bin` are the reference setup only. Anyone cloning/extracting the repository to another folder or using another Vivado installation must replace them with their own actual paths in `run_simulation_fresh.bat`, `run_simulation_fresh.tcl`, and the two path macros in `cpu_sim_tb.v` before running simulation.
