# Additional fixes for JSON serialization depth warnings

Write-Host "Applying additional fixes for JSON serialization issues..." -ForegroundColor Yellow

# 1. Add null output to any method that might accidentally output objects
$files = @{
    "AllServices.ps1" = @(
        # FocusManager.SetFocus - ensure it doesn't output anything
        @{
            Find = '$this.EventManager.Publish("Focus.Changed", @{ ComponentName = $component.Name; Component = $component })'
            Replace = '$this.EventManager.Publish("Focus.Changed", @{ ComponentName = $component.Name; Component = $component }) | Out-Null'
        }
    )
    "AllComponents.ps1" = @(
        # CommandPalette.Show - ensure no output
        @{
            Find = '$global:TuiState.OverlayStack.Add($this)'
            Replace = '$global:TuiState.OverlayStack.Add($this) | Out-Null'
        },
        # CommandPalette.Hide - ensure no output  
        @{
            Find = '$global:TuiState.OverlayStack.Remove($this)'
            Replace = '$global:TuiState.OverlayStack.Remove($this) | Out-Null'
        }
    )
}

foreach ($file in $files.Keys) {
    $filePath = Join-Path "C:\Users\jhnhe\Documents\GitHub\_XP\_mono" $file
    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw
        $modified = $false
        
        foreach ($fix in $files[$file]) {
            if ($content -match [regex]::Escape($fix.Find)) {
                $content = $content -replace [regex]::Escape($fix.Find), $fix.Replace
                $modified = $true
                Write-Host "  Fixed: $($fix.Find -replace '\s+', ' ') in $file" -ForegroundColor Green
            }
        }
        
        if ($modified) {
            Set-Content $filePath $content -NoNewline
        }
    }
}

# 2. Create a wrapper for Write-Verbose that filters out complex objects
$wrapperPath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\fix-verbose-output.ps1"
$wrapperContent = @'
# Add this to the beginning of Start.ps1 to prevent verbose output of complex objects

# Override Write-Verbose to prevent serialization of complex objects
$global:OriginalWriteVerbose = Get-Command Write-Verbose -CommandType Cmdlet
function global:Write-Verbose {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [string]$Message
    )
    
    # Filter out messages that might contain serialized objects
    if ($Message -notmatch '\[UIElement:' -and 
        $Message -notmatch 'System\.Collections' -and
        $Message -notmatch '@{') {
        & $global:OriginalWriteVerbose $Message
    }
}
'@

Set-Content $wrapperPath $wrapperContent

Write-Host "`nCreated fix-verbose-output.ps1 - consider adding this to Start.ps1 if verbose output still causes issues" -ForegroundColor Cyan
Write-Host "`nDone! The JSON serialization warnings should be resolved." -ForegroundColor Green
