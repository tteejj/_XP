# TUI Component Validation Framework
# Provides visual snapshot testing and performance benchmarking

using namespace System.Management.Automation
using namespace System.Diagnostics

function Test-TuiComponent {
    param(
        [string]$ComponentFile,
        [string]$ComponentClass,
        [scriptblock]$TestSetup,
        [scriptblock]$TestScenario
    )
    
    $result = @{
        Component = "$ComponentFile::$ComponentClass"
        Passed = $false
        Errors = @()
        Performance = @{}
        Snapshot = $null
    }
    
    try {
        # Load component
        Import-Module $ComponentFile -Force
        
        # Create test buffer
        $testWidth = 80
        $testHeight = 24
        $testBuffer = New-Object 'TuiCell[,]' $testHeight, $testWidth
        
        # Initialize with clear cells
        $clearCell = [TuiCell]::new()
        for ($y = 0; $y -lt $testHeight; $y++) {
            for ($x = 0; $x -lt $testWidth; $x++) {
                $testBuffer[$y, $x] = $clearCell
            }
        }
        
        # Mock the global Write-Buffer functions to write to our test buffer
        $global:TestBuffer = $testBuffer
        $global:TestBufferWidth = $testWidth
        $global:TestBufferHeight = $testHeight
        
        # Run test setup
        if ($TestSetup) {
            & $TestSetup
        }
        
        # Measure performance
        $stopwatch = [Stopwatch]::StartNew()
        
        # Run test scenario
        & $TestScenario
        
        $stopwatch.Stop()
        $result.Performance.RenderTimeMs = $stopwatch.ElapsedMilliseconds
        
        # Capture visual snapshot
        $snapshot = ""
        for ($y = 0; $y -lt $testHeight; $y++) {
            for ($x = 0; $x -lt $testWidth; $x++) {
                $snapshot += $testBuffer[$y, $x].Char
            }
            $snapshot += "`n"
        }
        $result.Snapshot = $snapshot
        
        $result.Passed = $true
    }
    catch {
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

function Compare-TuiSnapshots {
    param(
        [string]$Before,
        [string]$After
    )
    
    if ($Before -eq $After) {
        return @{ Identical = $true; Differences = @() }
    }
    
    $differences = @()
    $beforeLines = $Before -split "`n"
    $afterLines = $After -split "`n"
    
    for ($i = 0; $i -lt [Math]::Max($beforeLines.Count, $afterLines.Count); $i++) {
        if ($i -lt $beforeLines.Count -and $i -lt $afterLines.Count) {
            if ($beforeLines[$i] -ne $afterLines[$i]) {
                $differences += "Line $i differs"
            }
        }
        else {
            $differences += "Line count mismatch at line $i"
        }
    }
    
    return @{ Identical = $false; Differences = $differences }
}

function Measure-TuiPerformance {
    param(
        [scriptblock]$Scenario,
        [int]$Iterations = 100
    )
    
    $measurements = @()
    
    for ($i = 0; $i -lt $Iterations; $i++) {
        $stopwatch = [Stopwatch]::StartNew()
        & $Scenario
        $stopwatch.Stop()
        $measurements += $stopwatch.ElapsedMilliseconds
    }
    
    $sorted = $measurements | Sort-Object
    
    return @{
        Min = $sorted[0]
        Max = $sorted[-1]
        Average = ($measurements | Measure-Object -Average).Average
        Median = $sorted[[Math]::Floor($sorted.Count / 2)]
        P95 = $sorted[[Math]::Floor($sorted.Count * 0.95)]
    }
}

function Save-TuiTestResults {
    param(
        [object]$Results,
        [string]$Phase
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $resultsPath = ".\test_results\phase_${Phase}_${timestamp}.json"
    
    New-Item -ItemType Directory -Path ".\test_results" -Force | Out-Null
    
    $Results | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsPath
    
    Write-Host "Test results saved: $resultsPath" -ForegroundColor Green
    
    # Update manifest with test results
    $manifest = Get-Content -Path ".\refactor-manifest.json" | ConvertFrom-Json
    
    foreach ($result in $Results) {
        # Find component in manifest and update test status
        foreach ($category in $manifest.refactor.components.PSObject.Properties) {
            foreach ($component in $category.Value) {
                if ("$($component.file)::$($component.class)" -eq $result.Component) {
                    $component.tests += @{
                        Phase = $Phase
                        Timestamp = $timestamp
                        Passed = $result.Passed
                        Performance = $result.Performance
                    }
                }
            }
        }
    }
    
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path ".\refactor-manifest.json"
}

Export-ModuleMember -Function Test-TuiComponent, Compare-TuiSnapshots, Measure-TuiPerformance, Save-TuiTestResults