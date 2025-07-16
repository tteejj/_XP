#!/usr/bin/env pwsh

# Debug script to isolate the initialization issue
$scriptDir = $PSScriptRoot

# Load essential files
. "$scriptDir/Functions/AFU.006a_FileLogger.ps1"
. "$scriptDir/Runtime/ART.001_GlobalState.ps1"
. "$scriptDir/Base/ABC.002_TuiCell.ps1"
. "$scriptDir/Base/ABC.003_TuiBuffer.ps1"
. "$scriptDir/Functions/AFU.003_ThemeHelpers.ps1"
. "$scriptDir/Functions/AFU.004_LoggingHelpers.ps1"

Write-Host "Step 1: Console access test"
Write-Host "Console dimensions: $([Console]::WindowWidth)x$([Console]::WindowHeight)"

Write-Host "Step 2: Global state test"
Write-Host "TuiState type: $($global:TuiState.GetType().Name)"

Write-Host "Step 3: Console encoding test"
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Host "Output encoding set successfully"
} catch {
    Write-Host "Error setting output encoding: $_"
}

Write-Host "Step 4: Console input encoding test"
try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    Write-Host "Input encoding set successfully"
} catch {
    Write-Host "Error setting input encoding: $_"
}

Write-Host "Step 5: Console cursor test"
try {
    [Console]::CursorVisible = $false
    Write-Host "Cursor visibility set successfully"
} catch {
    Write-Host "Error setting cursor visibility: $_"
}

Write-Host "Step 6: TreatControlCAsInput test"
try {
    [Console]::TreatControlCAsInput = $true
    Write-Host "TreatControlCAsInput set successfully"
} catch {
    Write-Host "Error setting TreatControlCAsInput: $_"
}

Write-Host "Step 7: Window title test"
try {
    $Host.UI.RawUI.WindowTitle = "Test Title"
    Write-Host "Window title set successfully"
} catch {
    Write-Host "Error setting window title: $_"
}

Write-Host "Step 8: Clear Host test"
try {
    Clear-Host
    Write-Host "Clear-Host completed successfully"
} catch {
    Write-Host "Error with Clear-Host: $_"
}

Write-Host "Step 9: SetCursorPosition test"
try {
    [Console]::SetCursorPosition(0, 0)
    Write-Host "SetCursorPosition completed successfully"
} catch {
    Write-Host "Error with SetCursorPosition: $_"
}

Write-Host "All tests completed successfully!"