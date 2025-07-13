# ==============================================================================
# ROOT CAUSE DIAGNOSTIC - Find the exact Panel issue
# ==============================================================================

Write-Host "=== FINDING THE ROOT CAUSE ===" -ForegroundColor Cyan

# Test 1: Basic PowerShell syntax check of Panel file
Write-Host "`n1. Testing Panel file syntax..." -ForegroundColor Yellow
$panelFile = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AxiomPhoenix_v4_Split\Components\ACO.011_Panel.ps1"
try {
    $null = Get-Content $panelFile | Out-String
    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($panelFile, [ref]$tokens, [ref]$parseErrors)
    
    if ($parseErrors.Count -gt 0) {
        Write-Host "   ✗ SYNTAX ERRORS FOUND in Panel file:" -ForegroundColor Red
        foreach ($error in $parseErrors) {
            Write-Host "     Line $($error.Extent.StartLineNumber): $($error.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "   ✓ Panel file syntax is valid" -ForegroundColor Green
    }
} catch {
    Write-Host "   ✗ Failed to parse Panel file: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Load and test Panel class in isolation
Write-Host "`n2. Testing Panel class loading in isolation..." -ForegroundColor Yellow
try {
    # Clear any existing definitions
    Remove-Variable -Name Panel -ErrorAction SilentlyContinue -Force
    
    # Load required dependencies first
    $basePath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AxiomPhoenix_v4_Split"
    . "$basePath\Base\ABC.001_TuiAnsiHelper.ps1"
    . "$basePath\Base\ABC.002_TuiCell.ps1"
    . "$basePath\Base\ABC.003_TuiBuffer.ps1"
    . "$basePath\Base\ABC.004_UIElement.ps1"
    . "$basePath\Functions\AFU.004_ThemeFunctions.ps1"
    
    # Now load Panel
    . $panelFile
    
    Write-Host "   ✓ Panel class loaded successfully" -ForegroundColor Green
    
    # Test Panel type
    $panelType = [Panel]
    Write-Host "   ✓ Panel type exists: $($panelType.FullName)" -ForegroundColor Green
    
    # Test Panel constructor
    $panel = [Panel]::new("TestPanel")
    Write-Host "   ✓ Panel constructor works" -ForegroundColor Green
    Write-Host "     Panel object type: $($panel.GetType().FullName)" -ForegroundColor Gray
    
    # Test BorderStyle property existence
    $borderProperty = $panel.PSObject.Properties['BorderStyle']
    if ($borderProperty) {
        Write-Host "   ✓ BorderStyle property exists" -ForegroundColor Green
        Write-Host "     Current value: '$($panel.BorderStyle)'" -ForegroundColor Gray
        Write-Host "     Property type: $($borderProperty.TypeNameOfValue)" -ForegroundColor Gray
    } else {
        Write-Host "   ✗ BorderStyle property NOT FOUND" -ForegroundColor Red
        Write-Host "   Available properties:" -ForegroundColor Yellow
        $panel.PSObject.Properties | ForEach-Object { 
            Write-Host "     - $($_.Name) ($($_.TypeNameOfValue))" -ForegroundColor Gray 
        }
    }
    
    # Test BorderStyle assignment
    try {
        $panel.BorderStyle = "Double"
        Write-Host "   ✓ BorderStyle assignment works: '$($panel.BorderStyle)'" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ BorderStyle assignment failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "   ✗ Panel class loading failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

# Test 3: Compare with working component
Write-Host "`n3. Testing working component for comparison..." -ForegroundColor Yellow
try {
    $label = [LabelComponent]::new("TestLabel")
    Write-Host "   ✓ LabelComponent works: $($label.GetType().FullName)" -ForegroundColor Green
    Write-Host "   ✓ LabelComponent inherits from: $($label.GetType().BaseType.FullName)" -ForegroundColor Green
} catch {
    Write-Host "   ✗ LabelComponent failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== DIAGNOSIS COMPLETE ===" -ForegroundColor Cyan
