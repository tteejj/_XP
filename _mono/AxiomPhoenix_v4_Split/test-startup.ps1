#!/usr/bin/env pwsh

Write-Host "=== Testing Axiom-Phoenix startup sequence ===" -ForegroundColor Cyan

try {
    $scriptDir = $PSScriptRoot
    
    Write-Host "1. Loading essential files..." -ForegroundColor Green
    
    # Load the file logger FIRST
    $fileLoggerPath = Join-Path $scriptDir "Functions\AFU.006a_FileLogger.ps1"
    if (Test-Path $fileLoggerPath) {
        . $fileLoggerPath
        Write-Host "   ✓ File logger loaded" -ForegroundColor Gray
    } else {
        Write-Host "   ✗ File logger not found" -ForegroundColor Red
    }
    
    # Load globals
    . "$scriptDir/Runtime/ART.001_GlobalState.ps1"
    Write-Host "   ✓ Global state loaded" -ForegroundColor Gray
    
    # Load basic classes
    . "$scriptDir/Base/ABC.001_TuiAnsiHelper.ps1"
    . "$scriptDir/Base/ABC.001a_ServiceContainer.ps1"
    . "$scriptDir/Base/ABC.002_TuiCell.ps1"
    . "$scriptDir/Base/ABC.003_TuiBuffer.ps1"
    Write-Host "   ✓ Base classes loaded" -ForegroundColor Gray
    
    # Load Logger class
    . "$scriptDir/Services/ASE.001_Logger.ps1"
    Write-Host "   ✓ Logger class loaded" -ForegroundColor Gray
    
    Write-Host "2. Testing service container..." -ForegroundColor Green
    $container = [ServiceContainer]::new()
    Write-Host "   ✓ Service container created" -ForegroundColor Gray
    
    Write-Host "3. Testing logger creation..." -ForegroundColor Green
    $logPath = "/tmp/test-axiom.log"
    $logger = [Logger]::new($logPath)
    $logger.EnableFileLogging = $true
    $logger.MinimumLevel = "Debug"
    Write-Host "   ✓ Logger created at $logPath" -ForegroundColor Gray
    
    Write-Host "4. Testing initial log entry..." -ForegroundColor Green
    $logger.Log("Test startup sequence", "Info")
    Write-Host "   ✓ Log entry written" -ForegroundColor Gray
    
    Write-Host "5. Testing TuiState initialization..." -ForegroundColor Green
    Write-Host "   TuiState type: $($global:TuiState.GetType().Name)" -ForegroundColor Gray
    Write-Host "   Buffer size: $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight)" -ForegroundColor Gray
    
    Write-Host "6. Testing basic TUI buffer creation..." -ForegroundColor Green
    $testBuffer = [TuiBuffer]::new(80, 24, "Test")
    Write-Host "   ✓ TUI buffer created: $($testBuffer.Width)x$($testBuffer.Height)" -ForegroundColor Gray
    
    Write-Host "7. Testing console operations..." -ForegroundColor Green
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::CursorVisible = $false
    Write-Host "   ✓ Console configured" -ForegroundColor Gray
    
    Write-Host "✅ All startup tests passed!" -ForegroundColor Green
    
    Write-Host "8. Testing Start-AxiomPhoenix call simulation..." -ForegroundColor Green
    Write-Host "   This is where the program would normally call Start-AxiomPhoenix" -ForegroundColor Gray
    Write-Host "   Instead, we'll exit cleanly" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Error in startup test: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host "=== Startup test completed ===" -ForegroundColor Cyan