#!/usr/bin/env pwsh
# Quick test runner

Write-Host @"
BOLT-AXIOM Visual Test
=====================

KEYS TO TEST:
- 'e' = Edit mode (should see YELLOW background)
- 's' = Add subtask (should see "EDITING SUBTASK" in yellow)
- 'd' = Delete (should see RED dialog)
- 'E' = Detail edit (should open new screen)

Starting in 3 seconds...
"@ -ForegroundColor Cyan

Start-Sleep -Seconds 3

. ./bolt.ps1