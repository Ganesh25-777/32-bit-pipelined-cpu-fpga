@echo off
setlocal

echo ========================================
echo   CPU 32-bit Simulation
echo ========================================

set VIVADO=D:\2025.1\Vivado\bin
set PROJECT=D:\assembler\cpu_32bit.xpr

echo Vivado: %VIVADO%
echo Project: %PROJECT%
echo.

if not exist "%VIVADO%\vivado.bat" (
    echo ERROR: Vivado not found!
    echo Expected:
    echo %VIVADO%\vivado.bat
    pause
    exit /b 1
)

if not exist "%PROJECT%" (
    echo ERROR: Project not found!
    echo %PROJECT%
    pause
    exit /b 1
)

cd /d D:\assembler

echo Starting Vivado simulation...
echo.

"%VIVADO%\vivado.bat" -mode batch -source "D:\assembler\run_simulation.tcl"

if errorlevel 1 (
    echo.
    echo Simulation failed.
    pause
    exit /b 1
)

echo.
echo Simulation completed successfully.

if exist "D:\assembler\simulation_result.json" (
    echo Result file created successfully.
    echo D:\assembler\simulation_result.json
) else (
    echo WARNING: simulation_result.json was not created.
)

exit /b 0