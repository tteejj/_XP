#!/usr/bin/env pwsh
# Test ALCAR LazyGit menu selection

Write-Host "Starting ALCAR with LazyGit test..." -ForegroundColor Cyan

# Create a temporary script that will send 'G' key after a delay
$testScript = @'
Start-Sleep -Milliseconds 500
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class KeySender {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    
    public static void SendKey(byte key) {
        keybd_event(key, 0, 0, UIntPtr.Zero);
        keybd_event(key, 0, 2, UIntPtr.Zero);
    }
}
"@
[KeySender]::SendKey(0x47) # G key
'@

# Start ALCAR in a new process
Write-Host "Launching ALCAR..." -ForegroundColor Green
Start-Process pwsh -ArgumentList "-NoProfile", "-File", "./bolt.ps1" -PassThru

Write-Host @"

To test the ALCAR LazyGit Interface:
1. The ALCAR main menu should be displayed
2. Press 'G' to launch the LazyGit interface
3. Use Ctrl+Tab to switch between panels
4. Press Ctrl+P for command palette
5. Press Esc or Q to return to main menu

"@ -ForegroundColor Yellow

Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")