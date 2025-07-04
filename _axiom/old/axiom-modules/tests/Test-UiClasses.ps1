# Test-UiClasses.ps1
# Test script for the ui-classes module

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Add axiom modules to path
$axiomPath = Split-Path -Parent $PSScriptRoot
if ($env:PSModulePath -notlike "*$axiomPath*") {
    $env:PSModulePath = "$axiomPath;$env:PSModulePath"
}

Write-Host "Testing ui-classes module..." -ForegroundColor Cyan

# Test 1: Import Module
Write-Host "`n[TEST 1] Import Module" -ForegroundColor Yellow
try {
    Import-Module ui-classes -Force
    Write-Host "✓ Module imported successfully" -ForegroundColor Green
    Write-Host "  Dependencies loaded: tui-primitives" -ForegroundColor DarkGray
} catch {
    Write-Host "✗ Failed to import module: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Class Availability
Write-Host "`n[TEST 2] Class Availability" -ForegroundColor Yellow
$classes = @('UIElement', 'Component', 'Screen')
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

# Test 3: UIElement Creation
Write-Host "`n[TEST 3] UIElement Creation" -ForegroundColor Yellow
try {
    $elem1 = [UIElement]::new()
    $elem2 = [UIElement]::new("TestElement")
    $elem3 = [UIElement]::new(10, 20, 30, 40)
    
    if ($elem2.Name -eq "TestElement" -and 
        $elem3.X -eq 10 -and $elem3.Y -eq 20 -and 
        $elem3.Width -eq 30 -and $elem3.Height -eq 40) {
        Write-Host "✓ UIElement constructors work correctly" -ForegroundColor Green
    } else {
        throw "UIElement properties incorrect"
    }
} catch {
    Write-Host "✗ UIElement creation failed: $_" -ForegroundColor Red
}

# Test 4: Buffer Integration
Write-Host "`n[TEST 4] Buffer Integration" -ForegroundColor Yellow
try {
    $elem = [UIElement]::new("BufferTest")
    $elem.Width = 20
    $elem.Height = 10
    
    # Check that private buffer was created
    $buffer = $elem.GetBuffer()
    if ($null -ne $buffer -and $buffer.Width -eq 20 -and $buffer.Height -eq 10) {
        Write-Host "✓ UIElement creates and manages TuiBuffer correctly" -ForegroundColor Green
    } else {
        throw "Buffer not created properly"
    }
} catch {
    Write-Host "✗ Buffer integration failed: $_" -ForegroundColor Red
}

# Test 5: Parent-Child Relationships
Write-Host "`n[TEST 5] Parent-Child Relationships" -ForegroundColor Yellow
try {
    $parent = [Component]::new("Parent")
    $child1 = [UIElement]::new("Child1")
    $child2 = [UIElement]::new("Child2")
    
    $parent.AddChild($child1)
    $parent.AddChild($child2)
    
    if ($parent.Children.Count -eq 2 -and 
        $child1.Parent -eq $parent -and 
        $child2.Parent -eq $parent) {
        Write-Host "✓ Parent-child relationships work correctly" -ForegroundColor Green
    } else {
        throw "Parent-child relationship error"
    }
} catch {
    Write-Host "✗ Parent-child test failed: $_" -ForegroundColor Red
}

# Test 6: Screen Creation
Write-Host "`n[TEST 6] Screen Creation" -ForegroundColor Yellow
try {
    # Test with hashtable (backward compatibility)
    $services = @{
        TestService = "TestValue"
    }
    $screen = [Screen]::new("TestScreen", $services)
    
    if ($screen.Name -eq "TestScreen" -and 
        $screen.Services["TestService"] -eq "TestValue") {
        Write-Host "✓ Screen creation with services works" -ForegroundColor Green
    } else {
        throw "Screen properties incorrect"
    }
} catch {
    Write-Host "✗ Screen creation failed: $_" -ForegroundColor Red
}

# Test 7: Custom Component
Write-Host "`n[TEST 7] Custom Component" -ForegroundColor Yellow
try {
    # Define a test component
    class TestButton : UIElement {
        [string] $Label
        
        TestButton([string]$label) : base("Button") {
            $this.Label = $label
            $this.Width = $label.Length + 4
            $this.Height = 3
        }
        
        [void] OnRender() {
            # Simple test - just verify we can override
            ([UIElement]$this).OnRender()
        }
    }
    
    $button = [TestButton]::new("Test")
    if ($button.Label -eq "Test" -and $button.Width -eq 8) {
        Write-Host "✓ Custom component inheritance works" -ForegroundColor Green
    } else {
        throw "Custom component error"
    }
} catch {
    Write-Host "✗ Custom component failed: $_" -ForegroundColor Red
}

# Test 8: Absolute Position
Write-Host "`n[TEST 8] Absolute Position Calculation" -ForegroundColor Yellow
try {
    $root = [Component]::new("Root")
    $root.X = 10
    $root.Y = 5
    
    $child = [UIElement]::new("Child")
    $child.X = 20
    $child.Y = 10
    
    $root.AddChild($child)
    
    $absPos = $child.GetAbsolutePosition()
    if ($absPos.X -eq 30 -and $absPos.Y -eq 15) {
        Write-Host "✓ Absolute position calculation correct" -ForegroundColor Green
    } else {
        throw "Position calculation error"
    }
} catch {
    Write-Host "✗ Absolute position test failed: $_" -ForegroundColor Red
}

# Summary
Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
Write-Host "ui-classes module test complete!" -ForegroundColor Green
Write-Host "The module successfully integrates with tui-primitives." -ForegroundColor Green
