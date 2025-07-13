# Run this in PowerShell to test Panel class specifically
Write-Host "=== QUICK PANEL TEST ===" -ForegroundColor Cyan

# Test if Panel class exists
try {
    $panelType = [Panel]
    Write-Host "✓ Panel class found" -ForegroundColor Green
    
    # Test Panel constructor  
    try {
        $panel = [Panel]::new("TestPanel")
        Write-Host "✓ Panel constructor works" -ForegroundColor Green
        
        # Test BorderStyle property
        $borderProp = $panel | Get-Member -Name "BorderStyle" -MemberType Property
        if ($borderProp) {
            Write-Host "✓ BorderStyle property exists" -ForegroundColor Green
            try {
                $panel.BorderStyle = "Double"
                Write-Host "✓ BorderStyle assignment works" -ForegroundColor Green
            } catch {
                Write-Host "✗ BorderStyle assignment failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "✗ BorderStyle property missing" -ForegroundColor Red
            Write-Host "Available properties:" -ForegroundColor Yellow
            $panel | Get-Member -MemberType Property | Select-Object Name | Format-Table -AutoSize
        }
    } catch {
        Write-Host "✗ Panel constructor failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Panel class not found: $($_.Exception.Message)" -ForegroundColor Red
}
