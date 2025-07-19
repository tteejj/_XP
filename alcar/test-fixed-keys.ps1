#!/usr/bin/env pwsh
# Test the fixed key handling

Write-Host @"
BOLT-AXIOM Key Test
==================

FIXED BEHAVIORS:
- 'a' = Opens detail screen for new task (not inline)
- 'E' = Opens detail screen for editing (uppercase E)
- 'd' = Shows red delete confirmation dialog
- 'e' = Inline edit (lowercase e) - yellow background

Make sure you're in the TASKS pane (Tab to switch)

"@ -ForegroundColor Cyan

# Load and run
. ./bolt.ps1