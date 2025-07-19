#!/usr/bin/env pwsh
# Test the navigation system

Write-Host @"
BOLT-AXIOM Navigation Test
=========================

You should see a main menu with:
- Task Manager
- Projects  
- Dashboard
- Settings
- Exit

Navigation:
- Use arrow keys to move
- Press Enter to select
- Press 't' for tasks, 'p' for projects, etc.
- Press Esc or Backspace to go back
- Ctrl+Q to quit from anywhere

"@ -ForegroundColor Cyan

Write-Host "Starting in 3 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

. ./bolt.ps1