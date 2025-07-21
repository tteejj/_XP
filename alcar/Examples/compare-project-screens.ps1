#!/usr/bin/env pwsh
# Compare different ProjectContext screen implementations

Clear-Host
Write-Host "ALCAR Project Context Screen Comparison" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "V2 - Original Implementation:" -ForegroundColor Yellow
Write-Host "  ✓ Basic two-pane layout" -ForegroundColor Green
Write-Host "  ✓ Tab navigation" -ForegroundColor Green
Write-Host "  ✓ Simple project/task view" -ForegroundColor Green
Write-Host "  ✗ No command system" -ForegroundColor Red
Write-Host "  ✗ Fixed layout only" -ForegroundColor Red
Write-Host ""

Write-Host "V3 - Ranger-Style:" -ForegroundColor Yellow
Write-Host "  ✓ Three-column layout" -ForegroundColor Green
Write-Host "  ✓ Miller columns navigation" -ForegroundColor Green
Write-Host "  ✓ File browser integration" -ForegroundColor Green
Write-Host "  ✓ Quick preview pane" -ForegroundColor Green
Write-Host "  ✗ No command line" -ForegroundColor Red
Write-Host "  ✗ Limited customization" -ForegroundColor Red
Write-Host ""

Write-Host "V3 Enhanced - Full Command System:" -ForegroundColor Yellow
Write-Host "  ✓ Visual command line with borders" -ForegroundColor Green
Write-Host "  ✓ Command suggestions & autocomplete" -ForegroundColor Green
Write-Host "  ✓ Command history (↑↓ navigation)" -ForegroundColor Green
Write-Host "  ✓ Context-aware commands" -ForegroundColor Green
Write-Host "  ✓ Command palette (Ctrl+P)" -ForegroundColor Green
Write-Host "  ✓ Toggle 2/3 pane layouts (V key)" -ForegroundColor Green
Write-Host "  ✓ Configurable split ratios" -ForegroundColor Green
Write-Host "  ✓ Better alignment & borders" -ForegroundColor Green
Write-Host ""

Write-Host "Command Examples in V3 Enhanced:" -ForegroundColor Magenta
Write-Host "  / new task                    Create new task in current project" -ForegroundColor White
Write-Host "  / edit task login            Edit task containing 'login'" -ForegroundColor White
Write-Host "  / goto files                 Navigate to files tab" -ForegroundColor White
Write-Host "  / open project web           Open project containing 'web'" -ForegroundColor White
Write-Host "  / filter                     Toggle active/all projects" -ForegroundColor White
Write-Host ""

Write-Host "Key Differences:" -ForegroundColor Cyan
Write-Host "┌─────────────┬──────────────┬─────────────┬──────────────┐"
Write-Host "│ Feature     │ V2           │ V3          │ V3 Enhanced  │"
Write-Host "├─────────────┼──────────────┼─────────────┼──────────────┤"
Write-Host "│ Layout      │ 2-pane fixed │ 3-column    │ 2/3 toggle   │"
Write-Host "│ Commands    │ Menu keys    │ Menu keys   │ Full CLI     │"
Write-Host "│ Navigation  │ Tab/Arrow    │ Miller cols │ Both styles  │"
Write-Host "│ Flexibility │ Low          │ Medium      │ High         │"
Write-Host "│ Learning    │ Easy         │ Medium      │ Advanced     │"
Write-Host "└─────────────┴──────────────┴─────────────┴──────────────┘"
Write-Host ""

Write-Host "Which version would you like to try?" -ForegroundColor Yellow
Write-Host "  [2] V2 - Original" -ForegroundColor White
Write-Host "  [3] V3 - Ranger-style" -ForegroundColor White
Write-Host "  [E] V3 Enhanced - Full command system" -ForegroundColor White
Write-Host "  [Q] Quit" -ForegroundColor White
Write-Host ""
Write-Host "Choice: " -NoNewline

$choice = Read-Host

switch ($choice.ToUpper()) {
    "2" {
        Write-Host "Launching V2..." -ForegroundColor Green
        & "$PSScriptRoot/bolt.ps1"
        # Then press X in main menu
    }
    "3" {
        Write-Host "Launching V3..." -ForegroundColor Green
        & "$PSScriptRoot/bolt.ps1"
        # Then press R in main menu
    }
    "E" {
        Write-Host "Launching V3 Enhanced..." -ForegroundColor Green
        & "$PSScriptRoot/bolt.ps1"
        # Then press V in main menu
    }
    "Q" {
        Write-Host "Exiting..." -ForegroundColor Yellow
    }
    default {
        Write-Host "Invalid choice" -ForegroundColor Red
    }
}