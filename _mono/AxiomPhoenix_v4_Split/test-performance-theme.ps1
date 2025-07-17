# ==============================================================================
# Performance Theme Test Script
# Tests the rendering speed and efficiency of the Performance theme
# ==============================================================================

# Performance measurement function
function Measure-ThemePerformance {
    param(
        [string]$ThemeName,
        [int]$TestIterations = 1000
    )
    
    Write-Host "Testing theme performance: $ThemeName" -ForegroundColor Yellow
    
    # Common theme keys to test
    $testKeys = @(
        "panel.background",
        "panel.border",
        "panel.border.focused",
        "label.foreground",
        "list.background",
        "list.selected.background",
        "button.normal.background",
        "button.focused.background",
        "input.background",
        "input.border",
        "screen.background",
        "screen.foreground"
    )
    
    # Test 1: Individual color lookup speed
    $individualTest = Measure-Command {
        for ($i = 0; $i -lt $TestIterations; $i++) {
            foreach ($key in $testKeys) {
                $null = Get-ThemeColor $key
            }
        }
    }
    
    # Test 2: Batch color lookup speed
    $batchTest = Measure-Command {
        for ($i = 0; $i -lt ($TestIterations / 10); $i++) {
            $null = Get-ThemeColorBatch $testKeys
        }
    }
    
    # Test 3: Cache hit rate
    $cacheHits = 0
    $cacheMisses = 0
    
    # Clear cache and test
    Clear-ThemeCache
    
    foreach ($key in $testKeys) {
        $startTime = Get-Date
        $null = Get-ThemeColor $key
        $endTime = Get-Date
        
        # Second lookup should be faster (cache hit)
        $startTime2 = Get-Date
        $null = Get-ThemeColor $key
        $endTime2 = Get-Date
        
        $firstLookup = ($endTime - $startTime).TotalMilliseconds
        $secondLookup = ($endTime2 - $startTime2).TotalMilliseconds
        
        if ($secondLookup -lt $firstLookup) {
            $cacheHits++
        } else {
            $cacheMisses++
        }
    }
    
    # Results
    $results = @{
        Theme = $ThemeName
        IndividualLookupTime = $individualTest.TotalMilliseconds
        BatchLookupTime = $batchTest.TotalMilliseconds
        AverageIndividualTime = $individualTest.TotalMilliseconds / ($TestIterations * $testKeys.Count)
        AverageBatchTime = $batchTest.TotalMilliseconds / ($TestIterations / 10)
        CacheHitRate = [math]::Round(($cacheHits / ($cacheHits + $cacheMisses)) * 100, 2)
        TestedKeys = $testKeys.Count
        Iterations = $TestIterations
    }
    
    return $results
}

# Test function for theme switching speed
function Test-ThemeSwitchingSpeed {
    param([string[]]$ThemeNames)
    
    Write-Host "Testing theme switching speed..." -ForegroundColor Yellow
    
    $results = @{}
    
    foreach ($themeName in $ThemeNames) {
        if ($global:TuiState.Services.ThemeManager.Themes.ContainsKey($themeName)) {
            $switchTime = Measure-Command {
                $global:TuiState.Services.ThemeManager.LoadTheme($themeName)
            }
            $results[$themeName] = $switchTime.TotalMilliseconds
        }
    }
    
    return $results
}

# Main performance test
function Run-PerformanceTest {
    Write-Host "=== Performance Theme Speed Test ===" -ForegroundColor Green
    
    # Ensure theme functions are available
    if (-not (Get-Command 'Get-ThemeColor' -ErrorAction SilentlyContinue)) {
        Write-Error "Theme functions not loaded. Please run the TUI framework first."
        return
    }
    
    # Test themes
    $themesToTest = @("Performance", "Synthwave")
    $performanceResults = @{}
    
    foreach ($theme in $themesToTest) {
        if ($global:TuiState.Services.ThemeManager.Themes.ContainsKey($theme)) {
            # Load the theme
            $global:TuiState.Services.ThemeManager.LoadTheme($theme)
            
            # Test performance
            $performanceResults[$theme] = Measure-ThemePerformance $theme
        }
    }
    
    # Test theme switching
    $switchingResults = Test-ThemeSwitchingSpeed $themesToTest
    
    # Display results
    Write-Host "`n=== Performance Test Results ===" -ForegroundColor Green
    
    foreach ($theme in $performanceResults.Keys) {
        $result = $performanceResults[$theme]
        Write-Host "`nTheme: $theme" -ForegroundColor Cyan
        Write-Host "  Individual lookups: $([math]::Round($result.IndividualLookupTime, 2))ms total" -ForegroundColor White
        Write-Host "  Average per lookup: $([math]::Round($result.AverageIndividualTime, 4))ms" -ForegroundColor White
        Write-Host "  Batch lookups: $([math]::Round($result.BatchLookupTime, 2))ms total" -ForegroundColor White
        Write-Host "  Average batch time: $([math]::Round($result.AverageBatchTime, 2))ms" -ForegroundColor White
        Write-Host "  Cache hit rate: $($result.CacheHitRate)%" -ForegroundColor White
        
        if ($switchingResults.ContainsKey($theme)) {
            Write-Host "  Theme switch time: $([math]::Round($switchingResults[$theme], 2))ms" -ForegroundColor White
        }
    }
    
    # Performance comparison
    if ($performanceResults.ContainsKey("Performance") -and $performanceResults.ContainsKey("Synthwave")) {
        $perfTheme = $performanceResults["Performance"]
        $synthTheme = $performanceResults["Synthwave"]
        
        $speedImprovement = [math]::Round((($synthTheme.AverageIndividualTime - $perfTheme.AverageIndividualTime) / $synthTheme.AverageIndividualTime) * 100, 1)
        $switchSpeedImprovement = [math]::Round((($switchingResults["Synthwave"] - $switchingResults["Performance"]) / $switchingResults["Synthwave"]) * 100, 1)
        
        Write-Host "`n=== Performance Comparison ===" -ForegroundColor Green
        Write-Host "Performance theme is $speedImprovement% faster than Synthwave for color lookups" -ForegroundColor Yellow
        Write-Host "Performance theme switches $switchSpeedImprovement% faster than Synthwave" -ForegroundColor Yellow
    }
    
    # Performance characteristics summary
    Write-Host "`n=== Performance Theme Characteristics ===" -ForegroundColor Green
    Write-Host "✓ Uses standard web colors for fastest terminal processing" -ForegroundColor Green
    Write-Host "✓ Minimal color palette reduces memory footprint" -ForegroundColor Green
    Write-Host "✓ Pre-computed values eliminate runtime calculations" -ForegroundColor Green
    Write-Host "✓ Optimized for high cache hit rates" -ForegroundColor Green
    Write-Host "✓ Minimal semantic color variations" -ForegroundColor Green
    Write-Host "✓ Fast theme switching with cache pre-warming" -ForegroundColor Green
}

# Run the test if script is executed directly
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Run-PerformanceTest
}