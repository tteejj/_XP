#!/usr/bin/env pwsh
# ==============================================================================
# Axiom-Phoenix v4.0 - Test Runner
# Comprehensive test execution with reporting and filtering
# ==============================================================================

param(
    [ValidateSet("All", "Unit", "Integration", "Performance", "E2E")]
    [string]$TestType = "All",
    
    [ValidateSet("NUnitXml", "JUnitXml", "Console", "Detailed")]
    [string]$OutputFormat = "Detailed",
    
    [string]$OutputFile = "",
    
    [string]$TestPattern = "*",
    
    [switch]$FailFast,
    
    [switch]$ShowProgress,
    
    [switch]$GenerateReport,
    
    [ValidateSet("Silent", "Minimal", "Normal", "Detailed", "Diagnostic")]
    [string]$Verbosity = "Normal",
    
    [switch]$Parallel,
    
    [string]$Tag = "",
    
    [switch]$WhatIf
)

# Ensure we're in the right directory
$scriptDir = $PSScriptRoot
if (-not (Test-Path (Join-Path $scriptDir "Tests"))) {
    Write-Error "Tests directory not found. Please run this script from the Axiom-Phoenix root directory."
    exit 1
}

# Check for Pester
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Warning "Pester module not found. Installing Pester..."
    try {
        Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion 5.0
    } catch {
        Write-Error "Failed to install Pester: $($_.Exception.Message)"
        exit 1
    }
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0

# Configure Pester
$config = [PesterConfiguration]::Default

# Set verbosity
switch ($Verbosity) {
    "Silent" { $config.Output.Verbosity = "None" }
    "Minimal" { $config.Output.Verbosity = "Minimal" }
    "Normal" { $config.Output.Verbosity = "Normal" }
    "Detailed" { $config.Output.Verbosity = "Detailed" }
    "Diagnostic" { $config.Output.Verbosity = "Diagnostic" }
}

# Configure test discovery
$testPaths = @()
switch ($TestType) {
    "Unit" { 
        $testPaths += Join-Path $scriptDir "Tests\Unit"
    }
    "Integration" { 
        $testPaths += Join-Path $scriptDir "Tests\Integration"
    }
    "Performance" { 
        $testPaths += Join-Path $scriptDir "Tests\Performance"
    }
    "E2E" { 
        $testPaths += Join-Path $scriptDir "Tests\E2E"
    }
    "All" { 
        $testPaths += Join-Path $scriptDir "Tests"
    }
}

$config.Run.Path = $testPaths
$config.Run.PassThru = $true

# Configure test filtering
if ($TestPattern -ne "*") {
    $config.Filter.FullName = $TestPattern
}

if ($Tag) {
    $config.Filter.Tag = $Tag
}

# Configure failure behavior
if ($FailFast) {
    $config.Run.Exit = $true
}

# Configure output
if ($OutputFile) {
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = $OutputFile
    
    switch ($OutputFormat) {
        "NUnitXml" { $config.TestResult.OutputFormat = "NUnitXml" }
        "JUnitXml" { $config.TestResult.OutputFormat = "JUnitXml" }
        default { $config.TestResult.OutputFormat = "NUnitXml" }
    }
} else {
    $config.TestResult.Enabled = $false
}

# Configure code coverage if requested
$config.CodeCoverage.Enabled = $false

# Configure parallelization
if ($Parallel) {
    $config.Run.Parallel = $true
    $config.Run.PassThru = $true
}

# Display configuration
Write-Host "Axiom-Phoenix Test Runner" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host "Test Type: $TestType" -ForegroundColor Gray
Write-Host "Output Format: $OutputFormat" -ForegroundColor Gray
Write-Host "Verbosity: $Verbosity" -ForegroundColor Gray
if ($OutputFile) {
    Write-Host "Output File: $OutputFile" -ForegroundColor Gray
}
if ($TestPattern -ne "*") {
    Write-Host "Test Pattern: $TestPattern" -ForegroundColor Gray
}
if ($Tag) {
    Write-Host "Tag Filter: $Tag" -ForegroundColor Gray
}
if ($Parallel) {
    Write-Host "Parallel Execution: Enabled" -ForegroundColor Gray
}
Write-Host ""

# Show what would run if WhatIf
if ($WhatIf) {
    Write-Host "What-If Mode: The following tests would be executed:" -ForegroundColor Yellow
    
    foreach ($path in $testPaths) {
        if (Test-Path $path) {
            $testFiles = Get-ChildItem -Path $path -Recurse -Filter "*.Tests.ps1"
            foreach ($file in $testFiles) {
                Write-Host "  $($file.FullName)" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "`nNo tests were actually executed." -ForegroundColor Yellow
    exit 0
}

# Pre-test validation
Write-Host "Validating test environment..." -ForegroundColor Yellow

# Check that test files exist
$testFilesFound = 0
foreach ($path in $testPaths) {
    if (Test-Path $path) {
        $files = Get-ChildItem -Path $path -Recurse -Filter "*.Tests.ps1"
        $testFilesFound += $files.Count
        Write-Host "Found $($files.Count) test files in $path" -ForegroundColor Gray
    } else {
        Write-Warning "Test path not found: $path"
    }
}

if ($testFilesFound -eq 0) {
    Write-Error "No test files found matching the criteria."
    exit 1
}

Write-Host "Found $testFilesFound test files total" -ForegroundColor Green
Write-Host ""

# Execute tests
Write-Host "Executing tests..." -ForegroundColor Yellow
$startTime = Get-Date

try {
    $result = Invoke-Pester -Configuration $config
} catch {
    Write-Error "Test execution failed: $($_.Exception.Message)"
    exit 1
}

$endTime = Get-Date
$duration = $endTime - $startTime

# Display results
Write-Host ""
Write-Host "Test Execution Complete" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host "Duration: $($duration.ToString('mm\:ss\.fff'))" -ForegroundColor Gray
Write-Host ""

if ($result) {
    # Test summary
    Write-Host "Test Summary:" -ForegroundColor White
    Write-Host "  Total Tests: $($result.TotalCount)" -ForegroundColor Gray
    Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { "Red" } else { "Gray" })
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Not Run: $($result.NotRunCount)" -ForegroundColor Gray
    
    # Performance metrics
    if ($result.TotalCount -gt 0) {
        $avgTestTime = $duration.TotalMilliseconds / $result.TotalCount
        Write-Host "  Average Test Time: $([Math]::Round($avgTestTime, 2))ms" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Failed tests details
    if ($result.FailedCount -gt 0) {
        Write-Host "Failed Tests:" -ForegroundColor Red
        foreach ($test in $result.Tests | Where-Object { $_.Result -eq "Failed" }) {
            Write-Host "  ❌ $($test.ExpandedName)" -ForegroundColor Red
            if ($test.ErrorRecord) {
                Write-Host "     $($test.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
            }
        }
        Write-Host ""
    }
    
    # Performance test results
    if ($TestType -eq "Performance" -or $TestType -eq "All") {
        Write-Host "Performance Test Results:" -ForegroundColor Cyan
        $performanceTests = $result.Tests | Where-Object { 
            $_.Path -like "*Performance*" -and $_.Result -eq "Passed" 
        }
        
        if ($performanceTests) {
            foreach ($test in $performanceTests) {
                $time = if ($test.Duration) { 
                    "$([Math]::Round($test.Duration.TotalMilliseconds, 2))ms" 
                } else { 
                    "N/A" 
                }
                Write-Host "  ⚡ $($test.Name): $time" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  No performance tests found or all failed" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Generate detailed report if requested
    if ($GenerateReport) {
        $reportPath = Join-Path $scriptDir "TestReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        Write-Host "Generating detailed report: $reportPath" -ForegroundColor Yellow
        
        $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Axiom-Phoenix Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { color: #2E8B57; border-bottom: 2px solid #2E8B57; padding-bottom: 10px; }
        .summary { background-color: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .passed { color: green; }
        .failed { color: red; }
        .skipped { color: orange; }
        .test-list { margin: 20px 0; }
        .test-item { margin: 5px 0; padding: 8px; border-left: 4px solid #ddd; }
        .test-passed { border-left-color: green; }
        .test-failed { border-left-color: red; background-color: #ffe6e6; }
        .test-skipped { border-left-color: orange; }
        .error-details { font-family: monospace; background-color: #f8f8f8; padding: 10px; margin: 5px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Axiom-Phoenix Test Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Test Type: $TestType | Duration: $($duration.ToString('mm\:ss\.fff'))</p>
    </div>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Tests:</strong> $($result.TotalCount)</p>
        <p><strong class="passed">Passed:</strong> $($result.PassedCount)</p>
        <p><strong class="failed">Failed:</strong> $($result.FailedCount)</p>
        <p><strong class="skipped">Skipped:</strong> $($result.SkippedCount)</p>
    </div>
    
    <div class="test-list">
        <h2>Test Results</h2>
"@
        
        foreach ($test in $result.Tests) {
            $cssClass = switch ($test.Result) {
                "Passed" { "test-passed" }
                "Failed" { "test-failed" }
                "Skipped" { "test-skipped" }
                default { "" }
            }
            
            $htmlReport += @"
        <div class="test-item $cssClass">
            <strong>$($test.ExpandedName)</strong> - $($test.Result)
"@
            
            if ($test.ErrorRecord) {
                $htmlReport += @"
            <div class="error-details">$($test.ErrorRecord.Exception.Message -replace '<', '&lt;' -replace '>', '&gt;')</div>
"@
            }
            
            $htmlReport += "</div>`n"
        }
        
        $htmlReport += @"
    </div>
</body>
</html>
"@
        
        $htmlReport | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Host "Report generated: $reportPath" -ForegroundColor Green
    }
    
    # Exit with appropriate code
    if ($result.FailedCount -gt 0) {
        Write-Host "❌ Tests failed!" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✅ All tests passed!" -ForegroundColor Green
        exit 0
    }
} else {
    Write-Error "No test results returned from Pester"
    exit 1
}