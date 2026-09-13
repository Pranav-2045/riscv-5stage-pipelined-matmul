# PowerShell Test Suite Runner for 5-Stage Pipelined RISC-V CPU with Custom Matmul
$simDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $simDir

Write-Host "Running 5-Stage Pipelined RISC-V E2E Test Suite..." -ForegroundColor Cipher
python run_tests.py
