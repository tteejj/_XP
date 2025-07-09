# ==============================================================================
# Fix-CommandPalette.ps1
# Complete fix for CommandPalette class in AllComponents.ps1
# ==============================================================================

Write-Host "Starting CommandPalette fix..." -ForegroundColor Green

# Load the current AllComponents.ps1 file
$filePath = Join-Path $PSScriptRoot "AllComponents.ps1"
$content = Get-Content -Path $filePath -Raw

if (-not $content) {
    Write-Error "Could not read AllComponents.ps1"
    exit 1
}

# Find the CommandPalette class section
$startMarker = "#<!-- PAGE: ACO.016 - CommandPalette Class -->"
$endMarker = "#<!-- END_PAGE: ACO.016 -->"

$startIndex = $content.IndexOf($startMarker)
$endIndex = $content.IndexOf($endMarker)

if ($startIndex -eq -1 -or $endIndex -eq -1) {
    Write-Error "Could not find CommandPalette class markers in AllComponents.ps1"
    exit 1
}

Write-Host "Found CommandPalette class section" -ForegroundColor Yellow

# Create the fixed CommandPalette class
$fixedCommandPalette = @'
#<!-- PAGE: ACO.016 - CommandPalette Class -->
# ===== CLASS: CommandPalette =====
# Module: command-palette
# Dependencies: UIElement, Panel, ListBox, TextBox
# Purpose: Searchable command interface - FIXED VERSION
class CommandPalette : UIElement {
    hidden [ListBox]$_listBox
    hidden [TextBoxComponent]$_searchBox
    hidden [Panel]$_panel
    hidden [List[object]]$_allActions
    hidden [List[object]]$_filteredActions
    hidden [object]$_actionService
    hidden [scriptblock]$OnCancel
    hidden [scriptblock]$OnSelect

    CommandPalette([string]$name, [object]$actionService) : base($name) {
        $this.IsFocusable = $true
        $this.Visible = $false
        $this.IsOverlay = $true
        $this.Width = 60
        $this.Height = 20
        $this._actionService = $actionService
        
        $this.Initialize()
    }

    hidden [void] Initialize() {
        # Create main panel
        $this._panel = [Panel]::new("CommandPalette_Panel")
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
        $this._panel.BorderColor = "#00FFFF"
        $this._panel.BackgroundColor = "#000000"
        $this._panel.Title = " Command Palette "
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height
        $this._panel.X = 0
        $this._panel.Y = 0
        $this.AddChild($this._panel)

        # Create search box - use TextBoxComponent directly for better control
        $this._searchBox = [TextBoxComponent]::new("CommandPalette_Search")
        $this._searchBox.X = 2
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 3
        $this._searchBox.Placeholder = "Type to search commands..."
        
        # Set up search handler with proper context
        $paletteRef = $this
        $this._searchBox.OnChange = {
            param($sender, $text)
            try {
                $paletteRef.FilterActionsImmediate($text)
            }
            catch {
                Write-Host "CommandPalette OnChange error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        $this._panel.AddChild($this._searchBox)

        # Create list box
        $this._listBox = [ListBox]::new("CommandPalette_List")
        $this._listBox.X = 2
        $this._listBox.Y = 4
        $this._listBox.Width = $this.Width - 4
        $this._listBox.Height = $this.Height - 6
        $this._panel.AddChild($this._listBox)

        # Initialize action lists
        $this._allActions = [List[object]]::new()
        $this._filteredActions = [List[object]]::new()
    }

    [void] Show() {
        try {
            # Center the command palette on screen
            $consoleWidth = $global:TuiState.BufferWidth
            $consoleHeight = $global:TuiState.BufferHeight
            $this.X = [Math]::Max(0, [Math]::Floor(($consoleWidth - $this.Width) / 2))
            $this.Y = [Math]::Max(0, [Math]::Floor(($consoleHeight - $this.Height) / 2))
            
            Write-Host "CommandPalette: Showing at ($($this.X), $($this.Y))" -ForegroundColor Cyan
            
            $this.RefreshActions()
            $this._searchBox.Text = ""
            $this._searchBox.CursorPosition = 0
            $this.FilterActionsImmediate("")
            $this.Visible = $true
            
            # Set focus to search box
            $focusManager