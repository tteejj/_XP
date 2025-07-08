# Diagnostic test - minimal reproduction
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Test 1: Direct class instantiation" -ForegroundColor Cyan
    
    # Define a simple Logger class inline
    class TestLogger {
        [string]$LogPath = "test.log"
        TestLogger() {
            Write-Host "TestLogger constructor called"
        }
    }
    
    # Try to create it
    $testLogger = [TestLogger]::new()
    Write-Host "✓ TestLogger created" -ForegroundColor Green
    
    # Define a simple container
    class TestContainer {
        [hashtable]$_services = @{}
        
        [void] Register([string]$name, [object]$instance) {
            Write-Host "Register called with name: $name"
            $this._services[$name] = $instance
        }
    }
    
    $testContainer = [TestContainer]::new()
    Write-Host "✓ TestContainer created" -ForegroundColor Green
    
    # Try to register
    $testContainer.Register("Logger", $testLogger)
    Write-Host "✓ Registration successful" -ForegroundColor Green
    
} catch {
    Write-Host "`n✗ Error:" -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Yellow
    Write-Host "Target Site: $($_.Exception.TargetSite)" -ForegroundColor Yellow
    Write-Host "Stack Trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}

Write-Host "`nPress any key..."
[Console]::ReadKey($true) | Out-Null
