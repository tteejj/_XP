#!/usr/bin/env pwsh

# Test script to verify if Process-TuiInput is being called and logging

Write-Host "=== Testing Input Processing Function ===" -ForegroundColor Yellow

# Source the required files in order
try {
    # Source the logging functions first
    . "/home/teej/projects/github/_XP/_mono/AxiomPhoenix_v4_Split/Functions/AFU.006a_FileLogger.ps1"
    
    # Source the input processing function
    . "/home/teej/projects/github/_XP/_mono/AxiomPhoenix_v4_Split/Runtime/ART.004_InputProcessing.ps1"
    
    Write-Host "Successfully sourced input processing function" -ForegroundColor Green
    
    # Test with a mock key info
    $testKeyInfo = [System.ConsoleKeyInfo]::new([char]9, [ConsoleKey]::Tab, $false, $false, $false)
    
    Write-Host "`nTesting Process-TuiInput function with Tab key..." -ForegroundColor Cyan
    
    # Initialize minimal global state 
    $global:TuiState = @{
        Services = @{}
        Running = $true
        IsDirty = $false
    }
    
    # Call the function
    Process-TuiInput -KeyInfo $testKeyInfo
    
    Write-Host "Process-TuiInput completed" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Yellow