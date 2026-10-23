@echo off
setlocal

set "VIVADO=D:\2025.1\Vivado\bin"
set "PROJECT=D:\assembler\cpu_32bit.xpr"
set "TCL=D:\assembler\run_simulation_fresh.tcl"
set "RESULT=D:\assembler\simulation_result.json"

cd /d D:\assembler

echo ============================================================
echo CPU GUI SIMULATION: program.hex -^> UART -^> CPU -^> JSON
echo ============================================================

if not exist "%VIVADO%\vivado.bat" (
    echo ERROR: Vivado not found: %VIVADO%\vivado.bat
    exit /b 1
)
if not exist "%PROJECT%" (
    echo ERROR: Vivado project not found: %PROJECT%
    exit /b 1
)
if not exist "D:\assembler\program.hex" (
    echo ERROR: program.hex not found. Assemble your program in the GUI first.
    exit /b 1
)

if exist "%RESULT%" del /q "%RESULT%"
echo Starting Vivado batch simulation...
call "%VIVADO%\vivado.bat" -mode batch -source "%TCL%"
if errorlevel 1 (
    echo ERROR: Vivado simulation failed. Check vivado.log and Build Output.
    exit /b 1
)
if not exist "%RESULT%" (
    echo ERROR: simulation_result.json was not created.
    exit /b 1
)

echo.
echo Simulation JSON created at:
echo %RESULT%
echo.
type "%RESULT%"
echo.
exit /b 0
