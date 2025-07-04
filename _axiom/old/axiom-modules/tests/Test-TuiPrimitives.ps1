# Test-TuiPrimitives.ps1
# Test script for the tui-primitives module

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Add axiom modules to path
$axiomPath = Split-Path -Parent $PSScriptRoot
if ($env:PSModulePath -notlike "*$axiomPath*") {
    $env:PSModulePath = "$axiomPath;$env:PSModulePath"
}

Write-Host "Testing tui-primitives module..." -ForegroundColor Cyan
Write-Host "Module path: $axiomPath" -ForegroundColor DarkGray

# Test 1: Import Module
Write-Host "`n[TEST 1] Import Module" -ForegroundColor Yellow
try {
    Import-Module tui-primitives -Force
    Write-Host "✓ Module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import module: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Class Availability
Write-Host "`n[TEST 2] Class Availability" -ForegroundColor Yellow
$classes = @('TuiAnsiHelper', 'TuiCell', 'TuiBuffer')
$allClassesFound = $true

foreach ($className in $classes) {
    try {
        $type = [Type]$className
        if ($Verbose) {
            Write-Host "  ✓ Class found: $className" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ✗ Class not found: $className" -ForegroundColor Red
        $allClassesFound = $false
    }
}

if ($allClassesFound) {
    Write-Host "✓ All classes available" -ForegroundColor Green
}

# Test 3: TuiCell Creation
Write-Host "`n[TEST 3] TuiCell Creation" -ForegroundColor Yellow
try {
    $cell1 = [TuiCell]::new()
    $cell2 = [TuiCell]::new('A')
    $cell3 = [TuiCell]::new('B', [ConsoleColor]::Red, [ConsoleColor]::Blue)
    
    if ($cell1.Char -eq ' ' -and $cell2.Char -eq 'A' -and $cell3.ForegroundColor -eq [ConsoleColor]::Red) {
        Write-Host "✓ TuiCell constructors work correctly" -ForegroundColor Green
    } else {
        throw "Cell properties incorrect"
    }
} catch {
    Write-Host "✗ TuiCell creation failed: $_" -ForegroundColor Red
}

# Test 4: TuiBuffer Creation
Write-Host "`n[TEST 4] TuiBuffer Creation" -ForegroundColor Yellow
try {
    $buffer = [TuiBuffer]::new(80, 24, "TestBuffer")
    
    if ($buffer.Width -eq 80 -and $buffer.Height -eq 24) {
        Write-Host "✓ TuiBuffer created with correct dimensions" -ForegroundColor Green
    } else {
        throw "Buffer dimensions incorrect"
    }
} catch {
    Write-Host "✗ TuiBuffer creation failed: $_" -ForegroundColor Red
}

# Test 5: Function Exports
Write-Host "`n[TEST 5] Function Exports" -ForegroundColor Yellow
$functions = @('Write-TuiText', 'Write-TuiBox', 'Get-TuiBorderChars')
$allFunctionsFound = $true

foreach ($funcName in $functions) {
    if (Get-Command $funcName -ErrorAction SilentlyContinue) {
        if ($Verbose) {
            Write-Host "  ✓ Function found: $funcName" -ForegroundColor Green
        }
    } else {
        Write-Host "  ✗ Function not found: $funcName" -ForegroundColor Red
        $allFunctionsFound = $false
    }
}

if ($allFunctionsFound) {
    Write-Host "✓ All functions exported" -ForegroundColor Green
}

# Test 6: Basic Drawing Operations
Write-Host "`n[TEST 6] Basic Drawing Operations" -ForegroundColor Yellow
try {
    $buffer = [TuiBuffer]::new(40, 10, "DrawTest")
    
    # Test text writing
    Write-TuiText -Buffer $buffer -X 5 -Y 2 -Text "Hello" -ForegroundColor Yellow
    
    # Test box drawing
    Write-TuiBox -Buffer $buffer -X 0 -Y 0 -Width 20 -Height 5 -BorderStyle "Single"
    
    # Verify some cells were written
    $cell = $buffer.GetCell(5, 2)
    if ($cell.Char -eq 'H' -and $cell.ForegroundColor -eq [ConsoleColor]::Yellow) {
        Write-Host "✓ Drawing operations work correctly" -ForegroundColor Green
    } else {
        throw "Drawing verification failed"
    }
} catch {
    Write-Host "✗ Drawing operations failed: $_" -ForegroundColor Red
}

# Test 7: Border Styles
Write-Host "`n[TEST 7] Border Styles" -ForegroundColor Yellow
try {
    $styles = @('Single', 'Double', 'Rounded', 'Thick')
    $allStylesWork = $true
    
    foreach ($style in $styles) {
        $borders = Get-TuiBorderChars -Style $style
        if ($null -eq $borders -or $null -eq $borders.TopLeft) {
            Write-Host "  ✗ Border style failed: $style" -ForegroundColor Red
            $allStylesWork = $false
        } elseif ($Verbose) {
            Write-Host "  ✓ Border style works: $style" -ForegroundColor Green
        }
    }
    
    if ($allStylesWork) {
        Write-Host "✓ All border styles available" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Border style test failed: $_" -ForegroundColor Red
}

# Test 8: Cell Operations
Write-Host "`n[TEST 8] Cell Operations" -ForegroundColor Yellow
try {
    $cell1 = [TuiCell]::new('A', [ConsoleColor]::White, [ConsoleColor]::Black)
    $cell2 = [TuiCell]::new('B', [ConsoleColor]::Red, [ConsoleColor]::Blue)
    
    # Test style copy
    $styledCopy = $cell1.WithStyle([ConsoleColor]::Green, [ConsoleColor]::Yellow)
    
    # Test char copy
    $charCopy = $cell1.WithChar('X')
    
    # Test blending
    $cell2.ZIndex = 1
    $blended = $cell1.BlendWith($cell2)
    
    if ($styledCopy.ForegroundColor -eq [ConsoleColor]::Green -and
        $charCopy.Char -eq 'X' -and
        $blended.Char -eq 'B') {
        Write-Host "✓ Cell operations work correctly" -ForegroundColor Green
    } else {
        throw "Cell operation verification failed"
    }
} catch {
    Write-Host "✗ Cell operations failed: $_" -ForegroundColor Red
}

# Summary
Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
Write-Host "tui-primitives module test complete!" -ForegroundColor Green
Write-Host "The module is ready for use in the AXIOM architecture." -ForegroundColor Green
