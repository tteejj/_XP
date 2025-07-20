# LazyGit Phase 2 - Working Demonstration
# Shows the LazyGit-style layout system in action

Write-Host "=== LazyGit-Style Phase 2 Demonstration ===" -ForegroundColor Cyan
Write-Host "Live preview of multi-panel LazyGit-style interface" -ForegroundColor Yellow
Write-Host

# Load the core components
. "$PSScriptRoot/Core/LazyGitLayout.ps1"
. "$PSScriptRoot/Core/LazyGitRenderer.ps1"

# Create the layout system
Write-Host "Creating LazyGit-style layout..." -ForegroundColor Green
$layout = [LazyGitLayout]::new()
$renderer = [LazyGitRenderer]::new(8192)

# Display layout information
$stats = $layout.GetLayoutStats()
Write-Host "Terminal: $($stats.TerminalSize)" -ForegroundColor Gray
Write-Host "Layout Mode: $($stats.LayoutMode)" -ForegroundColor Gray
Write-Host "Left Panels: $($stats.LeftPanelCount)" -ForegroundColor Gray
Write-Host "Panel Width: $($stats.LeftPanelWidth)" -ForegroundColor Gray
Write-Host "Main Panel: $($stats.MainPanelWidth) wide" -ForegroundColor Gray
Write-Host

# Get panel configurations
$leftConfigs = $layout.GetLeftPanelConfigs()
$mainConfig = $layout.GetMainPanelConfig()
$cmdConfig = $layout.GetCommandPaletteConfig()

# Demo data for panels
$panelData = @{
    0 = @{
        Title = "FILTERS"
        Items = @("● All Tasks", "○ Active", "○ Completed", "○ High Priority", "○ Due Today", "○ Overdue")
    }
    1 = @{
        Title = "PROJECTS"
        Items = @("📂 ALCAR", "  📋 LazyGit Interface", "  📋 Command Palette", "📁 Phoenix TUI", "📂 Personal Tasks")
    }
    2 = @{
        Title = "TASKS"
        Items = @("🔄 Implement LazyGit UI", "📋 Fix render performance", "📋 Add command palette", "✅ Update documentation")
    }
    3 = @{
        Title = "RECENT"
        Items = @("📄 TaskScreen.ps1", "📄 LazyGitPanel.ps1", "📄 test-phase2.ps1", "📄 ALCAR_ANALYSIS.md")
    }
    4 = @{
        Title = "BOOKMARKS"
        Items = @("⭐ Project Dashboard", "⭐ Critical Tasks", "⭐ Recent Commits", "⭐ Performance Metrics")
    }
    5 = @{
        Title = "ACTIONS"
        Items = @("➕ New Task", "➕ New Project", "📤 Export Data", "⚙️ Settings", "🔄 Refresh All")
    }
}

# Create visual representation
Write-Host "Generating LazyGit-style interface preview..." -ForegroundColor Green
Write-Host

# Clear screen and position cursor
[Console]::Clear()
$buffer = $renderer.BeginFrame()

# Helper function to render a panel
function Render-Panel {
    param($config, $title, $items, $isActive = $false, $selectedIndex = 0)
    
    $lines = @()
    
    # Title with LazyGit style
    $titleColor = if ($isActive) { "`e[38;2;120;160;200m" } else { "`e[38;2;100;100;100m" }
    $lines += "$titleColor$title`e[0m"
    $lines += ""
    
    # Items
    for ($i = 0; $i -lt [Math]::Min($items.Count, $config.Height - 3); $i++) {
        $item = $items[$i]
        if ($i -eq $selectedIndex -and $isActive) {
            $lines += "`e[48;2;60;80;120m  $item  `e[0m"
        } else {
            $lines += "`e[38;2;180;180;180m  $item`e[0m"
        }
    }
    
    return $lines
}

# Render left panels
for ($i = 0; $i -lt $leftConfigs.Count; $i++) {
    $config = $leftConfigs[$i]
    $data = $panelData[$i]
    $isActive = ($i -eq 1)  # Make projects panel active
    
    $panelLines = Render-Panel $config $data.Title $data.Items $isActive 1
    
    for ($j = 0; $j -lt $panelLines.Count; $j++) {
        [void]$buffer.Append($renderer.MoveTo($config.X + 1, $config.Y + $j + 1))
        [void]$buffer.Append($panelLines[$j])
    }
}

# Render main panel (task details)
$mainPanelLines = @(
    "`e[38;2;180;180;180mDETAILS`e[0m",
    "",
    "`e[38;2;220;220;220mTask:`e[0m LazyGit Interface",
    "",
    "`e[38;2;180;180;180mStatus:`e[0m Active",
    "`e[38;2;180;180;180mPriority:`e[0m High",
    "`e[38;2;180;180;180mProject:`e[0m ALCAR",
    "",
    "`e[38;2;180;180;180mDescription:`e[0m",
    "Implement a LazyGit-style multi-panel interface",
    "with responsive layout, focus management, and",
    "high-performance rendering using StringBuilder",
    "double buffering.",
    "",
    "`e[38;2;100;100;100mActions:`e[0m",
    "  e - Edit task",
    "  d - Delete task", 
    "  Space - Toggle status",
    "  t - Add time entry"
)

for ($i = 0; $i -lt [Math]::Min($mainPanelLines.Count, $mainConfig.Height); $i++) {
    [void]$buffer.Append($renderer.MoveTo($mainConfig.X + 1, $mainConfig.Y + $i + 1))
    [void]$buffer.Append($mainPanelLines[$i])
}

# Render command palette
[void]$buffer.Append($renderer.MoveTo($cmdConfig.X + 1, $cmdConfig.Y + 1))
[void]$buffer.Append("`e[38;2;120;200;120m❯`e[0m `e[38;2;180;180;180mnew task`e[0m   `e[48;2;60;80;120m New Task `e[0m │ `e[38;2;150;150;150m New Project `e[0m │ `e[38;2;150;150;150m Find Task `e[0m")

# Render status line
[void]$buffer.Append($renderer.MoveTo(1, $cmdConfig.Y))
[void]$buffer.Append("`e[38;2;100;100;100mPanel: Projects | Layout: $($stats.LayoutMode) | Ctrl+Tab=Next Panel Ctrl+P=Command F1=Help Q=Quit`e[0m")

# Display the result
[Console]::Write($buffer.ToString())

# Position cursor at bottom
[Console]::SetCursorPosition(0, [Console]::WindowHeight - 1)
Write-Host

Write-Host "=== LazyGit-Style Interface Demo Complete ===" -ForegroundColor Cyan
Write-Host "Key Features Demonstrated:" -ForegroundColor Yellow
Write-Host "✓ Responsive multi-panel layout ($($stats.LeftPanelCount) left panels + main panel)" -ForegroundColor Green
Write-Host "✓ LazyGit-style minimal borders and clean design" -ForegroundColor Green
Write-Host "✓ Active panel highlighting (Projects panel shown active)" -ForegroundColor Green
Write-Host "✓ Command palette with fuzzy search preview" -ForegroundColor Green
Write-Host "✓ Context-sensitive main panel (task details)" -ForegroundColor Green
Write-Host "✓ Status bar with navigation hints" -ForegroundColor Green
Write-Host "✓ High-performance StringBuilder rendering" -ForegroundColor Green

Write-Host "`nNext: Phase 3 - Enhanced Command Palette & Real Views" -ForegroundColor Cyan

# Show layout export for debugging
Write-Host "`n=== Layout Configuration ===" -ForegroundColor Yellow
Write-Host $layout.ExportLayout() -ForegroundColor Gray