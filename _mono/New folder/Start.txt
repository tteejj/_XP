# ==============================================================================
# Axiom-Phoenix v4.0 - Enhanced Application Startup
# Beautiful splash screen and smooth initialization
# ==============================================================================

param(
    [string]$Theme = "Synthwave",
    [switch]$NoSplash,
    [switch]$Debug
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# ==============================================================================
# FUNCTION: Show-SplashScreen
#
# DEPENDENCIES:
#   - None (Uses direct .NET and Host APIs, runs before framework is loaded)
#
# PURPOSE:
#   Displays an animated, themed splash screen to provide a professional user
#   experience while the main framework files are being loaded and parsed.
#
# KEY LOGIC:
#   - Hides the cursor and clears the host.
#   - Uses direct Host UI calls (`$host.UI.RawUI`) for precise cursor placement
#     and color control, as the TUI engine is not yet available.
#   - Renders ASCII art and other text elements in calculated, centered positions.
#   - Animates the display in a loop, showing a progress bar and cycling through
#     loading messages to give a sense of progress.
#   - Restores the cursor and clears the host upon completion.
# ==============================================================================
function Show-SplashScreen {
    param([int]$Duration = 3000)
    
    try {
        Clear-Host
        $originalCursorSize = $host.UI.RawUI.CursorSize
        $host.UI.RawUI.CursorSize = 0
        
        $width = $host.UI.RawUI.WindowSize.Width
        $height = $host.UI.RawUI.WindowSize.Height
        
        $logo = @"
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                   ║
    ║      ___   _  _  _  ___  __  __     ___  _  _  ___  ___  _  _  _ ║
    ║     / _ \ | \/ || |/ _ \|  \/  |   | _ \| || |/ _ \| __|| \| || |║
    ║    | |_| | >  < | | (_) | |\/| |   |  _/| __ | (_) | _| | .  || |║
    ║    |_| |_|/_/\_\|_|\___/|_|  |_|   |_|  |_||_|\___/|___||_|\_||_|║
    ║                                                                   ║
    ║                        v4.0 ENHANCED EDITION                      ║
    ║                                                                   ║
    ╚═══════════════════════════════════════════════════════════════════╝
"@
        
        $logoLines = $logo -split "`n"
        $logoWidth = ($logoLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
        $startX = [Math]::Max(0, [Math]::Floor(($width - $logoWidth) / 2))
        $startY = [Math]::Max(0, [Math]::Floor(($height - $logoLines.Count - 5) / 2))
        
        $steps = 20
        $stepDelay = [Math]::Max(10, $Duration / $steps)
        
        for ($i = 0; $i -lt $steps; $i++) {
            $progress = ($i + 1) / $steps
            Clear-Host
            
            # Draw logo
            $y = $startY
            foreach ($line in $logoLines) {
                $host.UI.RawUI.CursorPosition = @{X=$startX; Y=$y}
                Write-Host $line -NoNewline -ForegroundColor Magenta
                $y++
            }
            
            # Draw tagline and credits
            if ($progress -ge 0.6) {
                $tagline = "The Future of Terminal User Interfaces"
                $taglineX = [Math]::Floor(($width - $tagline.Length) / 2)
                $host.UI.RawUI.CursorPosition = @{X=$taglineX; Y=$startY + $logoLines.Count + 1}
                Write-Host $tagline -ForegroundColor Cyan
            }
            
            # Progress bar
            $progressY = $height - 3
            $progressWidth = 60
            $progressX = [Math]::Floor(($width - $progressWidth) / 2)
            $progressChars = [Math]::Floor($progress * $progressWidth)
            
            $host.UI.RawUI.CursorPosition = @{X=$progressX; Y=$progressY}
            Write-Host "[" -NoNewline -ForegroundColor DarkGray
            Write-Host ("█" * $progressChars) -NoNewline -ForegroundColor Green
            Write-Host ("░" * ($progressWidth - $progressChars)) -NoNewline -ForegroundColor DarkGray
            Write-Host "]" -ForegroundColor DarkGray
            
            Start-Sleep -Milliseconds $stepDelay
        }
    }
    finally {
        # Restore console state
        $host.UI.RawUI.ForegroundColor = [ConsoleColor]::Gray
        if ($originalCursorSize) { $host.UI.RawUI.CursorSize = $originalCursorSize }
        Clear-Host
    }
}

# Main startup sequence
try {
    if (-not $NoSplash) {
        Show-SplashScreen -Duration 1500
    }
    
    # --- Framework Loading ---
    Write-Host "Loading Axiom-Phoenix v4.0 Framework..." -ForegroundColor Cyan
    
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = Get-Location }
    
    $files = @(
        @{ File = "AllBaseClasses.ps1"; Description = "Core Framework" },
        @{ File = "AllModels.ps1"; Description = "Data Models" },
        @{ File = "AllFunctions.ps1"; Description = "Utility Functions" },
        @{ File = "AllComponents.ps1"; Description = "UI Components" },
        @{ File = "AllScreens.ps1"; Description = "Application Screens" },
        @{ File = "AllServices.ps1"; Description = "Business Services" },
        @{ File = "AllRuntime.ps1"; Description = "Runtime Engine" }
    )
    
    foreach ($fileInfo in $files) {
        Write-Host "  • Loading $($fileInfo.Description)..." -NoNewline -ForegroundColor Gray
        $filePath = Join-Path $scriptDir $fileInfo.File
        if (-not (Test-Path $filePath)) { throw "FATAL: Framework file not found: $filePath" }
        . $filePath
        Write-Host " ✓" -ForegroundColor Green
    }
    
    # --- Service Initialization (Now we can use Write-Log) ---
    Write-Log -Level Info -Message "Framework files loaded. Initializing services."
    $container = [ServiceContainer]::new()
    
    $servicesToRegister = @(
        @{ Name = "Logger"; Factory = { [Logger]::new((Join-Path $env:TEMP "axiom-phoenix.log")) } },
        @{ Name = "EventManager"; Factory = { [EventManager]::new() } },
        @{ Name = "ThemeManager"; Factory = { [ThemeManager]::new() } },
        @{ Name = "DataManager"; Factory = { param($c) New-Object DataManager -ArgumentList (Join-Path $env:TEMP "axiom-data.json"), ($c.GetService('EventManager')) } },
        @{ Name = "ActionService"; Factory = { param($c) New-Object ActionService -ArgumentList ($c.GetService('EventManager')) } },
        @{ Name = "KeybindingService"; Factory = { param($c) New-Object KeybindingService -ArgumentList ($c.GetService('ActionService')) } },
        @{ Name = "FocusManager"; Factory = { param($c) New-Object FocusManager -ArgumentList ($c.GetService('EventManager')) } },
        @{ Name = "DialogManager"; Factory = { param($c) New-Object DialogManager -ArgumentList ($c.GetService('EventManager')), ($c.GetService('FocusManager')) } },
        @{ Name = "NavigationService"; Factory = { param($c) New-Object NavigationService -ArgumentList $c } }
    )

    foreach ($serviceInfo in $servicesToRegister) {
        Write-Log -Level Info -Message "Registering service factory: $($serviceInfo.Name)"
        $container.RegisterFactory($serviceInfo.Name, $serviceInfo.Factory)
    }

    # Force immediate creation of the logger to use it for subsequent messages
    $logger = $container.GetService("Logger")
    Write-Log -Level Info -Message "Logger service initialized. Subsequent logs will be routed."

    # Initialize other core services
    Write-Log -Level Info -Message "Initializing core application services..."
    $actionService = $container.GetService("ActionService")
    $dataManager = $container.GetService("DataManager")
    $themeManager = $container.GetService("ThemeManager")
    
    # Set theme
    if ($themeManager -and $Theme) {
        $themeManager.LoadTheme($Theme)
        Write-Log -Level Info -Message "Theme '$Theme' activated."
    }

    # Load data and actions
    $actionService.RegisterDefaultActions()
    $dataManager.LoadData()

    Write-Log -Level Info -Message "Services initialized and data loaded."
    
    # --- Application Launch ---
    Write-Host "`nFramework loaded. Press any key to launch..." -ForegroundColor Green
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Create the initial screen instance
    $dashboardScreen = [DashboardScreen]::new($container)
    
    # Launch the application
    Start-AxiomPhoenix -ServiceContainer $container -InitialScreen $dashboardScreen
}
catch {
    # Final panic handler
    [Console]::ResetColor()
    Clear-Host
    Write-Host "[CRITICAL ERROR]" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host "A fatal error occurred during startup." -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Location: $($_.TargetSite)" -ForegroundColor Yellow
    Write-Host "Stack Trace:" -ForegroundColor DarkGray
    Write-Host $_.ScriptStackTrace
    
    Write-Host "`nPress any key to exit."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}