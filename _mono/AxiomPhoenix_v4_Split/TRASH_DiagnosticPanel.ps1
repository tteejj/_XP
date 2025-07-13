# ==============================================================================
# DIAGNOSTIC SCRIPT - Panel Class Investigation
# Run this to identify the Panel class loading issue
# ==============================================================================

Write-Host "=== PANEL CLASS DIAGNOSTICS ===" -ForegroundColor Cyan

# Test 1: Check if Panel class exists
Write-Host "`n1. Testing Panel class existence..." -ForegroundColor Yellow
try {
    $panelType = [Panel]
    Write-Host "   ✓ Panel class found: $panelType" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Panel class NOT FOUND: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   This is the root cause of the problem!" -ForegroundColor Red
}

# Test 2: Check Panel constructor
Write-Host "`n2. Testing Panel constructor..." -ForegroundColor Yellow
try {
    $panel = [Panel]::new("TestPanel")
    Write-Host "   ✓ Panel constructor works" -ForegroundColor Green
    Write-Host "   Panel type: $($panel.GetType().FullName)" -ForegroundColor Gray
    
    # Test 3: Check Panel properties
    Write-Host "`n3. Testing Panel properties..." -ForegroundColor Yellow
    $members = $panel | Get-Member -MemberType Property | Where-Object { $_.Name -eq "BorderStyle" }
    if ($members) {
        Write-Host "   ✓ BorderStyle property found" -ForegroundColor Green
        Write-Host "   Current value: '$($panel.BorderStyle)'" -ForegroundColor Gray
        
        # Test 4: Try setting BorderStyle
        Write-Host "`n4. Testing BorderStyle assignment..." -ForegroundColor Yellow
        try {
            $panel.BorderStyle = "Double"
            Write-Host "   ✓ BorderStyle assignment successful" -ForegroundColor Green
            Write-Host "   New value: '$($panel.BorderStyle)'" -ForegroundColor Gray
        } catch {
            Write-Host "   ✗ BorderStyle assignment failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "   ✗ BorderStyle property NOT FOUND" -ForegroundColor Red
        Write-Host "   Available properties:" -ForegroundColor Gray
        $panel | Get-Member -MemberType Property | ForEach-Object { 
            Write-Host "     - $($_.Name)" -ForegroundColor Gray 
        }
    }
} catch {
    Write-Host "   ✗ Panel constructor failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Check UIElement base class
Write-Host "`n5. Testing UIElement base class..." -ForegroundColor Yellow
try {
    $uiElement = [UIElement]::new("TestElement")
    Write-Host "   ✓ UIElement constructor works" -ForegroundColor Green
} catch {
    Write-Host "   ✗ UIElement constructor failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Check file loading order
Write-Host "`n6. Checking loaded types..." -ForegroundColor Yellow
$loadedTypes = @()
try { $loadedTypes += [UIElement] } catch { }
try { $loadedTypes += [Panel] } catch { }
try { $loadedTypes += [Component] } catch { }
try { $loadedTypes += [Screen] } catch { }

Write-Host "   Loaded framework types:" -ForegroundColor Gray
$loadedTypes | ForEach-Object { Write-Host "     - $($_.Name)" -ForegroundColor Gray }

Write-Host "`n=== DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan
Write-Host "If Panel class is not found, the Components folder wasn't loaded properly." -ForegroundColor Yellow
Write-Host "If BorderStyle is missing, there's a class definition issue." -ForegroundColor Yellow
