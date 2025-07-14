# Debug script to test NewTaskScreen focus
$scriptPath = $PSScriptRoot
. "$scriptPath\Start.ps1" -SkipMainLoop

# Create minimal test
$container = $global:TuiState.Services
$screen = [NewTaskScreen]::new($container)
$screen.Initialize()

# Check what focusable components were found
$focusable = $screen.GetFocusableChildren()
Write-Host "Found $($focusable.Count) focusable components:"
foreach ($comp in $focusable) {
    Write-Host "  - $($comp.Name) (TabIndex: $($comp.TabIndex), Type: $($comp.GetType().Name))"
}

# Check panel children
Write-Host "`nPanel children:"
$panel = $screen.Children[0]
foreach ($child in $panel.Children) {
    Write-Host "  - $($child.Name) (IsFocusable: $($child.IsFocusable), Type: $($child.GetType().Name))"
}

# Test button OnClick
Write-Host "`nTesting button OnClick..."
$saveButton = $focusable | Where-Object { $_.Name -eq "SaveButton" }
if ($saveButton -and $saveButton.OnClick) {
    try {
        & $saveButton.OnClick
        Write-Host "OnClick executed successfully"
    }
    catch {
        Write-Host "OnClick error: $_"
    }
}
