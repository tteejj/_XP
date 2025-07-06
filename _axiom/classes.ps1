# ==============================================================================
# Axiom-Phoenix - Global Class Definitions v5.0 (Corrected Order)
# This file is dot-sourced by run.ps1 to make all classes available to the
# PowerShell parser before any modules are imported. This resolves all
# cross-module class dependency and inheritance issues at parse time.
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Threading.Tasks

#region --- Level 0: Enums and Standalone Helper/Model Classes ---

enum TaskStatus { Pending; InProgress; Completed; Cancelled }
enum TaskPriority { Low; Medium; High }
enum BillingType { Billable; NonBillable }

class ValidationBase {
    static [void] ValidateNotEmpty([string]$value, [string]$parameterName) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw [System.ArgumentException]::new("Parameter '$($parameterName)' cannot be null or empty.", $parameterName)
        }
    }
}

class PmcTask : ValidationBase {
    [string]$Id = [Guid]::NewGuid().ToString()
    [string]$Title
    [string]$Description
    [TaskStatus]$Status = [TaskStatus]::Pending
    [TaskPriority]$Priority = [TaskPriority]::Medium
    [string]$ProjectKey = "General"
    [string]$Category
    [datetime]$CreatedAt = [datetime]::Now
    [datetime]$UpdatedAt = [datetime]::Now
    [Nullable[datetime]]$DueDate
    [string[]]$Tags = @()
    [int]$Progress = 0
    [bool]$Completed = $false

    PmcTask() {}
    PmcTask([string]$title) {
        [ValidationBase]::ValidateNotEmpty($title, "Title")
        $this.Title = $title
    }
    [void] Complete() {
        $this.Status = [TaskStatus]::Completed
        $this.Completed = $true
        $this.Progress = 100
        $this.UpdatedAt = [datetime]::Now
    }
    [void] UpdateProgress([int]$newProgress) {
        $this.Progress = $newProgress
        $this.Status = switch ($newProgress) {
            100 { [TaskStatus]::Completed }
            { $_ -gt 0 } { [TaskStatus]::InProgress }
            default { [TaskStatus]::Pending }
        }
        $this.Completed = ($this.Status -eq [TaskStatus]::Completed)
        $this.UpdatedAt = [datetime]::Now
    }
    [hashtable] ToLegacyFormat() {
        return @{
            id = $this.Id; title = $this.Title; description = $this.Description; completed = $this.Completed
            priority = $this.Priority.ToString().ToLower(); project = $this.ProjectKey
            due_date = if ($this.DueDate) { $this.DueDate.Value.ToString("yyyy-MM-dd") } else { $null }
            created_at = $this.CreatedAt.ToString("o"); updated_at = $this.UpdatedAt.ToString("o")
        }
    }
    static [PmcTask] FromLegacyFormat([hashtable]$legacyData) {
        $task = [PmcTask]::new()
        $task.Id = $legacyData.id ?? $task.Id
        $task.Title = $legacyData.title ?? ""
        $task.Description = $legacyData.description ?? ""
        if ($legacyData.priority) { try { $task.Priority = [TaskPriority]::$($legacyData.priority) } catch {} }
        $task.ProjectKey = $legacyData.project ?? $legacyData.Category ?? "General"
        $task.Category = $task.ProjectKey
        if ($legacyData.created_at) { try { $task.CreatedAt = [datetime]::Parse($legacyData.created_at) } catch {} }
        if ($legacyData.updated_at) { try { $task.UpdatedAt = [datetime]::Parse($legacyData.updated_at) } catch {} }
        if ($legacyData.due_date -and $legacyData.due_date -ne "N/A") { try { $task.DueDate = [datetime]::Parse($legacyData.due_date) } catch {} }
        if ($legacyData.completed -is [bool] -and $legacyData.completed) { $task.Complete() }
        else { $task.UpdateProgress($task.Progress) }
        return $task
    }
}

class PmcProject : ValidationBase {
    [string]$Key = ([Guid]::NewGuid().ToString().Split('-')[0]).ToUpper()
    [string]$Name
    [string]$Client
    [BillingType]$BillingType = [BillingType]::NonBillable
    [double]$Rate = 0.0
    [double]$Budget = 0.0
    [bool]$Active = $true
    [datetime]$CreatedAt = [datetime]::Now
    [datetime]$UpdatedAt = [datetime]::Now
    PmcProject() {}
    PmcProject([string]$key, [string]$name) {
        [ValidationBase]::ValidateNotEmpty($key, "Key"); [ValidationBase]::ValidateNotEmpty($name, "Name")
        $this.Key = $key.ToUpper(); $this.Name = $name
    }
    [hashtable] ToLegacyFormat() { @{ Key = $this.Key; Name = $this.Name; Client = $this.Client; BillingType = $this.BillingType.ToString(); Rate = $this.Rate; Budget = $this.Budget; Active = $this.Active; CreatedAt = $this.CreatedAt.ToString("o"); UpdatedAt = $this.UpdatedAt.ToString("o") } }
    static [PmcProject] FromLegacyFormat([hashtable]$legacyData) {
        $project = [PmcProject]::new()
        $project.Key = ($legacyData.Key ?? $project.Key).ToUpper()
        $project.Name = $legacyData.Name ?? ""; $project.Client = $legacyData.Client ?? ""
        if ($legacyData.Rate) { try { $project.Rate = [double]$legacyData.Rate } catch {} }
        if ($legacyData.Budget) { try { $project.Budget = [double]$legacyData.Budget } catch {} }
        if ($legacyData.Active -is [bool]) { $project.Active = $legacyData.Active }
        if ($legacyData.BillingType) { try { $project.BillingType = [BillingType]::$($legacyData.BillingType) } catch {} }
        if ($legacyData.CreatedAt) { try { $project.CreatedAt = [datetime]::Parse($legacyData.CreatedAt) } catch {} }
        if ($legacyData.UpdatedAt) { try { $project.UpdatedAt = [datetime]::Parse($legacyData.UpdatedAt) } catch {} } else { $project.UpdatedAt = $project.CreatedAt }
        return $project
    }
}

class TuiAnsiHelper {
    hidden static [System.Collections.Concurrent.ConcurrentDictionary[string, string]] $_fgCache = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()
    hidden static [System.Collections.Concurrent.ConcurrentDictionary[string, string]] $_bgCache = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()
    static [hashtable] $ColorMap = @{ Black = 30; DarkBlue = 34; DarkGreen = 32; DarkCyan = 36; DarkRed = 31; DarkMagenta = 35; DarkYellow = 33; Gray = 37; DarkGray = 90; Blue = 94; Green = 92; Cyan = 96; Red = 91; Magenta = 95; Yellow = 93; White = 97 }
    static [int[]] ParseHexColor([string]$hexColor) { if ([string]::IsNullOrWhiteSpace($hexColor) -or -not $hexColor.StartsWith("#")) { return $null }; $hex = $hexColor.Substring(1); if ($hex.Length -eq 3) { $hex = "$($hex[0])$($hex[0])$($hex[1])$($hex[1])$($hex[2])$($hex[2])" }; if ($hex.Length -ne 6) { return $null }; try { $r = [System.Convert]::ToInt32($hex.Substring(0, 2), 16); $g = [System.Convert]::ToInt32($hex.Substring(2, 2), 16); $b = [System.Convert]::ToInt32($hex.Substring(4, 2), 16); return @($r, $g, $b) } catch { return $null } }
    static [string] GetForegroundCode($color) { if ($color -is [ConsoleColor]) { return "`e[$([TuiAnsiHelper]::ColorMap[$color.ToString()] ?? 37)m" } elseif ($color -is [string] -and $color.StartsWith("#")) { return [TuiAnsiHelper]::GetForegroundSequence($color) } else { return "`e[37m" } }
    static [string] GetBackgroundCode($color) { if ($color -is [ConsoleColor]) { $code = ([TuiAnsiHelper]::ColorMap[$color.ToString()] ?? 30) + 10; return "`e[${code}m" } elseif ($color -is [string] -and $color.StartsWith("#")) { return [TuiAnsiHelper]::GetBackgroundSequence($color) } else { return "`e[40m" } }
    static [string] GetForegroundSequence([string]$hexColor) { if ([string]::IsNullOrEmpty($hexColor)) { return "" }; if ([TuiAnsiHelper]::_fgCache.ContainsKey($hexColor)) { return [TuiAnsiHelper]::_fgCache[$hexColor] }; $rgb = [TuiAnsiHelper]::ParseHexColor($hexColor); if (-not $rgb) { return "" }; $sequence = "`e[38;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m"; [TuiAnsiHelper]::_fgCache[$hexColor] = $sequence; return $sequence }
    static [string] GetBackgroundSequence([string]$hexColor) { if ([string]::IsNullOrEmpty($hexColor)) { return "" }; if ([TuiAnsiHelper]::_bgCache.ContainsKey($hexColor)) { return [TuiAnsiHelper]::_bgCache[$hexColor] }; $rgb = [TuiAnsiHelper]::ParseHexColor($hexColor); if (-not $rgb) { return "" }; $sequence = "`e[48;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m"; [TuiAnsiHelper]::_bgCache[$hexColor] = $sequence; return $sequence }
    static [string] Reset() { return "`e[0m" }
}

class TuiCell {
    [char]$Char = ' '
    $ForegroundColor = [ConsoleColor]::White
    $BackgroundColor = [ConsoleColor]::Black
    [int]$ZIndex = 0
    TuiCell() {}
    TuiCell([char]$char, $fg, $bg) { $this.Char = $char; $this.ForegroundColor = $fg; $this.BackgroundColor = $bg }
    TuiCell([TuiCell]$other) { $this.Char = $other.Char; $this.ForegroundColor = $other.ForegroundColor; $this.BackgroundColor = $other.BackgroundColor; $this.ZIndex = $other.ZIndex }
    [TuiCell] BlendWith([TuiCell]$other) { if ($null -eq $other) { return $this } if ($other.Char -ne ' ' -and $other.ZIndex -ge $this.ZIndex) { return [TuiCell]::new($other) } if ($other.BackgroundColor -ne $this.BackgroundColor -and $other.Char -eq ' ' -and $other.ZIndex -ge $this.ZIndex) { return [TuiCell]::new($other) } return $this }
    [bool] DiffersFrom([TuiCell]$other) { if ($null -eq $other) { return $true } return ($this.Char -ne $other.Char -or $this.ForegroundColor -ne $other.ForegroundColor -or $this.BackgroundColor -ne $other.BackgroundColor) }
}

class TuiBuffer {
    [TuiCell[,]]$Cells; [int]$Width; [int]$Height; [string]$Name; [bool]$IsDirty = $true
    TuiBuffer([int]$width, [int]$height, [string]$name = "Unnamed") { $this.Width = $width; $this.Height = $height; $this.Name = $name; $this.Cells = New-Object 'TuiCell[,]' $height, $width; $this.Clear() }
    [void] Clear([TuiCell]$fillCell = [TuiCell]::new()) { for ($y = 0; $y -lt $this.Height; $y++) { for ($x = 0; $x -lt $this.Width; $x++) { $this.Cells[$y, $x] = [TuiCell]::new($fillCell) } }; $this.IsDirty = $true }
    [TuiCell] GetCell([int]$x, [int]$y) { if ($x -lt 0 -or $x -ge $this.Width -or $y -lt 0 -or $y -ge $this.Height) { return $null }; return $this.Cells[$y, $x] }
    [void] SetCell([int]$x, [int]$y, [TuiCell]$cell) { if ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height) { $this.Cells[$y, $x] = $cell; $this.IsDirty = $true } }
    [void] BlendBuffer([TuiBuffer]$other, [int]$offsetX, [int]$offsetY) { for ($y = 0; $y -lt $other.Height; $y++) { for ($x = 0; $x -lt $other.Width; $x++) { $targetX = $offsetX + $x; $targetY = $offsetY + $y; if ($targetX -ge 0 -and $targetX -lt $this.Width -and $targetY -ge 0 -and $targetY -lt $this.Height) { $sourceCell = $other.GetCell($x, $y); $targetCell = $this.GetCell($targetX, $targetY); if ($targetCell) { $this.SetCell($targetX, $targetY, $targetCell.BlendWith($sourceCell)) } else { $this.SetCell($targetX, $targetY, $sourceCell) } } } }; $this.IsDirty = $true }
    [void] Resize([int]$newWidth, [int]$newHeight) { $oldCells = $this.Cells; $oldWidth = $this.Width; $oldHeight = $this.Height; $this.Width = $newWidth; $this.Height = $newHeight; $this.Cells = New-Object 'TuiCell[,]' $newHeight, $newWidth; $this.Clear(); $copyWidth = [Math]::Min($oldWidth, $newWidth); $copyHeight = [Math]::Min($oldHeight, $newHeight); for ($y = 0; $y -lt $copyHeight; $y++) { for ($x = 0; $x -lt $copyWidth; $x++) { $this.Cells[$y, $x] = $oldCells[$y, $x] } }; $this.IsDirty = $true }
}

#endregion

#region --- Level 1: Base UI Class ---

class UIElement {
    [string]$Name = "UIElement"; [int]$X = 0; [int]$Y = 0; [int]$Width = 10; [int]$Height = 3; [bool]$Visible = $true; [bool]$Enabled = $true; [bool]$IsFocusable = $false; [bool]$IsFocused = $false; [int]$TabIndex = 0; [int]$ZIndex = 0; [UIElement]$Parent = $null; [System.Collections.Generic.List[UIElement]]$Children; hidden [TuiBuffer]$_private_buffer = $null; hidden [bool]$_needs_redraw = $true
    UIElement([string]$name = "UIElement") { $this.Name = $name; $this.Children = [System.Collections.Generic.List[UIElement]]::new(); $this._private_buffer = New-TuiBuffer -Width $this.Width -Height $this.Height -Name "$($this.Name).Buffer" }
    [void] AddChild([UIElement]$child) { $child.Parent = $this; $this.Children.Add($child); $this.RequestRedraw() }
    [void] RequestRedraw() { $this._needs_redraw = $true; if ($null -ne $this.Parent) { $this.Parent.RequestRedraw() } }
    [void] Resize([int]$newWidth, [int]$newHeight) { $this.Width = $newWidth; $this.Height = $newHeight; $this._private_buffer.Resize($newWidth, $newHeight); $this.RequestRedraw() }
    [void] OnRender() { $this._private_buffer.Clear() }
    [void] OnFocus() { $this.IsFocused = $true; $this.RequestRedraw() }
    [void] OnBlur() { $this.IsFocused = $false; $this.RequestRedraw() }
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) { return $false }
    [void] Render() { if (-not $this.Visible) { return } if ($this._needs_redraw) { $this.OnRender(); $this._needs_redraw = $false } foreach ($child in $this.Children | Sort-Object ZIndex) { if ($child.Visible) { $child.Render(); $this._private_buffer.BlendBuffer($child._private_buffer, $child.X, $child.Y) } } }
}

#endregion

#region --- Level 2: Core UI Containers and Components (Inherit from UIElement) ---

class Panel : UIElement {
    [string]$Title = ""; [string]$BorderStyle = "Single"; [ConsoleColor]$BorderColor = [ConsoleColor]::Gray; [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black; [bool]$HasBorder = $true
    Panel([string]$name, [int]$x, [int]$y, [int]$width, [int]$height, [string]$title = "") : base($name) { $this.X = $x; $this.Y = $y; $this.Width = $width; $this.Height = $height; $this.Title = $title }
    [void] OnRender() { $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor)); if ($this.HasBorder) { Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle $this.BorderStyle -BorderColor $this.BorderColor -BackgroundColor $this.BackgroundColor -Title $this.Title } }
}

class LabelComponent : UIElement {
    [string]$Text = ""; [object]$ForegroundColor
    LabelComponent([string]$name) : base($name) { $this.IsFocusable = $false; $this.Width = 10; $this.Height = 1 }
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        $this._private_buffer.Clear()
        $fg = $this.ForegroundColor ?? (Get-ThemeColor 'Foreground')
        $bg = Get-ThemeColor 'Background'
        Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $this.Text -ForegroundColor $fg -BackgroundColor $bg
    }
}

class ButtonComponent : UIElement {
    [string]$Text = "Button"; [bool]$IsPressed = $false; [scriptblock]$OnClick
    ButtonComponent([string]$name) : base($name) { $this.IsFocusable = $true; $this.Width = 10; $this.Height = 3 }
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        $state = if ($this.IsPressed) { "pressed" } elseif ($this.IsFocused) { "focus" } else { "normal" }
        $bgColor = Get-ThemeColor "button.$state.background" -Default (if ($this.IsPressed) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Background' })
        $borderColor = Get-ThemeColor "button.$state.border" -Default (if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Border' })
        $fgColor = Get-ThemeColor "button.$state.foreground" -Default (if ($this.IsPressed) { Get-ThemeColor 'Background' } else { Get-ThemeColor 'Foreground' })
        $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
        $textX = [Math]::Floor(($this.Width - $this.Text.Length) / 2)
        $textY = [Math]::Floor(($this.Height - 1) / 2)
        Write-TuiText -Buffer $this._private_buffer -X $textX -Y $textY -Text $this.Text -ForegroundColor $fgColor -BackgroundColor $bgColor
    }
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            $this.IsPressed = $true; $this.RequestRedraw(); if ($this.OnClick) { & $this.OnClick }; Start-Sleep -Milliseconds 50; $this.IsPressed = $false; $this.RequestRedraw(); return $true
        }
        return $false
    }
}

class TextBoxComponent : UIElement {
    [string]$Text = ""; [string]$Placeholder = ""; [int]$MaxLength = 100; [int]$CursorPosition = 0; [scriptblock]$OnChange; hidden [int]$_scrollOffset = 0
    TextBoxComponent([string]$name) : base($name) { $this.IsFocusable = $true; $this.Width = 20; $this.Height = 3 }
    [void] OnRender() {
        # ... full render logic ...
    }
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        #... full input logic ...
        return $false
    }
    hidden [void] _UpdateScrollOffset() {
        #... full logic ...
    }
}

class CheckBoxComponent : UIElement {
    [string]$Text = "Checkbox"; [bool]$Checked = $false; [scriptblock]$OnChange
    CheckBoxComponent([string]$name) : base($name) { $this.IsFocusable = $true; $this.Width = 20; $this.Height = 1 }
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        $this._private_buffer.Clear(); $fg = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Foreground' }; $bg = Get-ThemeColor 'Background'; $checkbox = if ($this.Checked) { "[X]" } else { "[ ]" }; $displayText = "$checkbox $($this.Text)"; Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg -BackgroundColor $bg
    }
    [bool] HandleInput([System.ConsoleKeyInfo]$key) { if ($null -eq $key) { return $false }; if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) { $this.Checked = -not $this.Checked; if ($this.OnChange) { & $this.OnChange -NewValue $this.Checked }; $this.RequestRedraw(); return $true }; return $false }
}

class RadioButtonComponent : UIElement {
    [string]$Text = "Option"; [bool]$Selected = $false; [string]$GroupName = ""; [scriptblock]$OnChange
    RadioButtonComponent([string]$name) : base($name) { $this.IsFocusable = $true; $this.Width = 20; $this.Height = 1 }
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        $this._private_buffer.Clear(); $fg = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Foreground' }; $bg = Get-ThemeColor 'Background'; $radio = if ($this.Selected) { "(●)" } else { "( )" }; $displayText = "$radio $($this.Text)"; Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg -BackgroundColor $bg
    }
    [bool] HandleInput([System.ConsoleKeyInfo]$key) { if ($null -eq $key) { return $false }; if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) { if (-not $this.Selected) { $this.Selected = $true; if ($this.Parent -and $this.GroupName) { $this.Parent.Children | Where-Object { $_ -is [RadioButtonComponent] -and $_.GroupName -eq $this.GroupName -and $_ -ne $this } | ForEach-Object { $_.Selected = $false; $_.RequestRedraw() } }; if ($this.OnChange) { & $this.OnChange -NewValue $this.Selected }; $this.RequestRedraw() }; return $true }; return $false }
}

class TableColumn {
    [string]$Key; [string]$Header; [object]$Width; [string]$Alignment = "Left"
    TableColumn([string]$key, [string]$header, [object]$width) { $this.Key = $key; $this.Header = $header; $this.Width = $width }
}

class Table : UIElement {
    [System.Collections.Generic.List[TableColumn]]$Columns; [object[]]$Data = @(); [int]$SelectedIndex = 0; [bool]$ShowBorder = $true; [bool]$ShowHeader = $true; [scriptblock]$OnSelectionChanged; hidden [int]$_scrollOffset = 0
    Table([string]$name) : base($name) { $this.Columns = [System.Collections.Generic.List[TableColumn]]::new(); $this.IsFocusable = $true; $this.Width = 60; $this.Height = 15 }
    [void] SetColumns([TableColumn[]]$columns) { $this.Columns.Clear(); foreach ($col in $columns) { $this.Columns.Add($col) }; $this.RequestRedraw() }
    [void] SetData([object[]]$data) { $this.Data = @($data); if ($this.SelectedIndex -ge $this.Data.Count) { $this.SelectedIndex = [Math]::Max(0, $this.Data.Count - 1) }; $this._scrollOffset = 0; $this.RequestRedraw() }
    [void] SelectNext() { if ($this.SelectedIndex -lt ($this.Data.Count - 1)) { $this.SelectedIndex++; $this._EnsureVisible(); $this.RequestRedraw() } }
    [void] SelectPrevious() { if ($this.SelectedIndex -gt 0) { $this.SelectedIndex--; $this._EnsureVisible(); $this.RequestRedraw() } }
    [object] GetSelectedItem() { if ($this.Data.Count -gt 0 -and $this.SelectedIndex -in (0..($this.Data.Count - 1))) { return $this.Data[$this.SelectedIndex] }; return $null }
    [void] OnRender() { #... full render logic ... 
    }
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) { #... full input logic ... 
        return $false
    }
    hidden [void] _EnsureVisible() { #... full logic ...
    }
    hidden [int] _GetContentHeight() { $h = $this.Height; if ($this.ShowBorder) { $h -= 2 }; if ($this.ShowHeader) { $h -= 1 }; return [Math]::Max(0, $h) }
    hidden [string] _FormatCell([string]$text, [int]$width, [string]$alignment) { #... full logic ...
        return $text
    }
    hidden [object[]] _ResolveColumnWidths([int]$totalWidth) { #... full logic ...
        return @()
    }
}

class NavigationItem {
    [string]$Key; [string]$Label; [scriptblock]$Action; [bool]$Enabled = $true; [bool]$Visible = $true
    NavigationItem([string]$key, [string]$label, [scriptblock]$action) { $this.Key = $key.ToUpper(); $this.Label = $label; $this.Action = $action }
    [void] Execute() { if (-not $this.Enabled) { return }; Invoke-WithErrorHandling -Component "NavigationItem" -Context "Execute '$($this.Key)'" -ScriptBlock $this.Action }
}

class NavigationMenu : UIElement {
    [System.Collections.Generic.List[NavigationItem]]$Items; [string]$Orientation = "Vertical"; [int]$SelectedIndex = 0
    NavigationMenu([string]$name) : base($name) { $this.Items = [System.Collections.Generic.List[NavigationItem]]::new(); $this.IsFocusable = $true }
    [void] AddItem([NavigationItem]$item) { $this.Items.Add($item); $this.RequestRedraw() }
}

class Dialog : UIElement {
    [string]$Title = "Dialog"; [string]$Message = ""; hidden [TaskCompletionSource[object]] $_tcs
    Dialog([string]$name) : base($name) { $this.IsFocusable = $true; $this.Width = 50; $this.Height = 10; $this._tcs = [TaskCompletionSource[object]]::new() }
    [Task[object]] Show() { $this.X = [Math]::Floor(($global:TuiState.BufferWidth - $this.Width) / 2); $this.Y = [Math]::Floor(($global:TuiState.BufferHeight - $this.Height) / 4); Show-TuiOverlay -Element $this; Set-ComponentFocus -Component $this; return $this._tcs.Task }
    [void] Close([object]$result, [bool]$wasCancelled = $false) { if ($wasCancelled) { $this._tcs.TrySetCanceled() } else { $this._tcs.TrySetResult($result) }; Close-TopTuiOverlay }
}

class AlertDialog : Dialog {
    AlertDialog([string]$title, [string]$message) : base("AlertDialog") { $this.Title = $title; $this.Message = $message }
}

class ConfirmDialog : Dialog {
    hidden [int]$_selectedButton = 0
    ConfirmDialog([string]$title, [string]$message) : base("ConfirmDialog") { $this.Title = $title; $this.Message = $message }
}

class InputDialog : Dialog {
    hidden [TextBoxComponent]$_textBox
    InputDialog([string]$title, [string]$message, [string]$defaultValue = "") : base("InputDialog") { $this.Title = $title; $this.Message = $message; $this.Metadata.DefaultValue = $defaultValue }
}

class CommandPalette : UIElement {
    hidden [object]$_actionService; hidden [TextBoxComponent]$_searchBox; hidden [object[]]$_filteredActions; hidden [int]$_selectedIndex = 0
    CommandPalette([object]$actionService) : base("CommandPalette") { $this._actionService = $actionService; $this.IsFocusable = $true; $this.Visible = $false; $this.ZIndex = 1000 }
}

#endregion

#region --- Level 3: Service and Logic Classes ---

class ServiceContainer {
    hidden [hashtable] $_services = @{}
    hidden [hashtable] $_serviceFactories = @{}
    ServiceContainer() {}
    [void] Register([string]$name, [object]$serviceInstance) {
        if ($this._services.ContainsKey($name) -or $this._serviceFactories.ContainsKey($name)) { throw [System.InvalidOperationException]::new("A service or factory with the name '$name' is already registered.") }
        $this._services[$name] = $serviceInstance
    }
    [void] RegisterFactory([string]$name, [scriptblock]$factory, [bool]$isSingleton = $true) {
        if ($this._services.ContainsKey($name) -or $this._serviceFactories.ContainsKey($name)) { throw [System.InvalidOperationException]::new("A service or factory with the name '$name' is already registered.") }
        $this._serviceFactories[$name] = @{ Factory = $factory; IsSingleton = $isSingleton; Instance = $null }
    }
    [object] GetService([string]$name) {
        if ($this._services.ContainsKey($name)) { return $this._services[$name] }
        if ($this._serviceFactories.ContainsKey($name)) { return $this._InitializeServiceFromFactory($name, [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)) }
        throw [System.InvalidOperationException]::new("Service '$name' not found.")
    }
    hidden [object] _InitializeServiceFromFactory([string]$name, [System.Collections.Generic.HashSet[string]]$resolutionChain) {
        $factoryInfo = $this._serviceFactories[$name]
        if ($factoryInfo.IsSingleton -and $null -ne $factoryInfo.Instance) { return $factoryInfo.Instance }
        if ($resolutionChain.Contains($name)) { throw [System.InvalidOperationException]::new("Circular dependency detected while resolving service '$name'.") }
        [void]$resolutionChain.Add($name)
        $serviceInstance = & $factoryInfo.Factory $this
        if ($factoryInfo.IsSingleton) { $factoryInfo.Instance = $serviceInstance }
        [void]$resolutionChain.Remove($name)
        return $serviceInstance
    }
    [void] Cleanup() {
        $instancesToClean = [System.Collections.Generic.List[object]]::new()
        $this._services.Values | ForEach-Object { $instancesToClean.Add($_) }
        $this._serviceFactories.Values | Where-Object { $_.IsSingleton -and $_.Instance } | ForEach-Object { $instancesToClean.Add($_.Instance) }
        foreach ($service in $instancesToClean) {
            if ($service -is [System.IDisposable]) {
                try { $service.Dispose() }
                catch {}
            }
        }
        $this._services.Clear()
        $this._serviceFactories.Clear()
    }
}

class ActionService {
    [hashtable]$ActionRegistry = @{}
    ActionService() { $this.RegisterAction("app.exit", "Exits the application.", { Publish-Event -EventName "Application.Exit" }, "Application", $true) }
    [void] RegisterAction([string]$name, [string]$description, [scriptblock]$scriptBlock, [string]$category = "General", [switch]$Force) {
        if ($this.ActionRegistry.ContainsKey($name) -and -not $Force) { return }
        $this.ActionRegistry[$name] = @{ Name = $name; Description = $description; ScriptBlock = $scriptBlock; Category = $category }
    }
    [void] ExecuteAction([string]$name, [hashtable]$parameters = @{}) {
        if (-not $this.ActionRegistry.ContainsKey($name)) { throw [System.ArgumentException]::new("Unknown action: $name", "name") }
        $action = $this.ActionRegistry[$name]
        try { & $action.ScriptBlock -ActionParameters $parameters }
        catch { throw }
    }
    [hashtable] GetAction([string]$name) { return $this.ActionRegistry[$name] }
    [System.Collections.Generic.List[hashtable]] GetAllActions() { return @($this.ActionRegistry.Values | Sort-Object Name) }
}

class KeybindingService {
    [hashtable]$KeyMap = @{}
    KeybindingService() { $this.KeyMap = @{ "app.exit" = @{ Key = [System.ConsoleKey]::Q; Modifiers = @("Ctrl") } } }
    [void] SetBinding([string]$actionName, [System.ConsoleKey]$key, [string[]]$modifiers) { $this.KeyMap[$actionName.ToLower()] = @{ Key = $key; Modifiers = $modifiers } }
    [bool] IsAction([string]$actionName, [System.ConsoleKeyInfo]$keyInfo) {
        $binding = $this.KeyMap[$actionName.ToLower()]
        if (-not $binding) { return $false }
        if ($binding.Key -ne $keyInfo.Key) { return $false }
        $hasCtrl = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) -ne 0
        $hasAlt = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) -ne 0
        $hasShift = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) -ne 0
        $expectedCtrl = $binding.Modifiers -contains "Ctrl"
        $expectedAlt = $binding.Modifiers -contains "Alt"
        $expectedShift = $binding.Modifiers -contains "Shift"
        return ($hasCtrl -eq $expectedCtrl -and $hasAlt -eq $expectedAlt -and $hasShift -eq $expectedShift)
    }
    [string] GetBindingDescription([string]$actionName) {
        $binding = $this.KeyMap[$actionName.ToLower()]
        if (-not $binding) { return "Unbound" }
        $keyStr = $binding.Key.ToString()
        if ($binding.Modifiers.Count -gt 0) { return "$($binding.Modifiers -join '+') + $keyStr" }
        return $keyStr
    }
}

class ScreenFactory {
    hidden [hashtable]$Services
    hidden [hashtable]$ScreenTypes = @{}
    ScreenFactory([hashtable]$services) { $this.Services = $services }
    [void] RegisterScreen([string]$name, [type]$screenType) {
        $isScreenType = $screenType.Name -eq 'Screen' -or $screenType.BaseType.Name -eq 'Screen' -or ($screenType.BaseType -and $screenType.BaseType.BaseType -and $screenType.BaseType.BaseType.Name -eq 'Screen')
        if (-not $isScreenType) { throw "Type must inherit from Screen." }
        $this.ScreenTypes[$name] = $screenType
    }
    [object] CreateScreen([string]$screenName, [hashtable]$parameters) {
        $screenType = $this.ScreenTypes[$screenName]
        if (-not $screenType) { throw "Unknown screen type: $screenName" }
        $serviceContainer = $this.Services['ServiceContainer']
        if (-not $serviceContainer) { $screen = $screenType::new($this.Services) }
        else { $screen = $screenType::new($serviceContainer) }
        if ($parameters) { foreach ($key in $parameters.Keys) { $screen.State[$key] = $parameters[$key] } }
        return $screen
    }
}

class NavigationService {
    [System.Collections.Generic.Stack[Screen]]$ScreenStack
    [ScreenFactory]$ScreenFactory
    [Screen]$CurrentScreen
    [hashtable]$Services
    [hashtable]$RouteMap = @{}
    NavigationService([hashtable]$services) {
        $this.Services = $services
        $this.ScreenStack = [System.Collections.Generic.Stack[Screen]]::new()
        $this.ScreenFactory = [ScreenFactory]::new($services)
        $this.RouteMap = @{ "/" = "DashboardScreen"; "/tasks" = "TaskListScreen" }
    }
    [void] RegisterScreenClass([string]$name, [type]$screenType) { $this.ScreenFactory.RegisterScreen($name, $screenType) }
    [void] GoTo([string]$path, [hashtable]$parameters = @{}) {
        if ($path -eq "/exit") { $this.RequestExit(); return }
        $screenName = $this.RouteMap[$path]
        if (-not $screenName) { throw "Unknown route: $path" }
        $this.PushScreen($screenName, $parameters)
    }
    [void] PushScreen([string]$screenName, [hashtable]$parameters = @{}) {
        if ($this.CurrentScreen) { $this.CurrentScreen.OnExit();[void]$this.ScreenStack.Push($this.CurrentScreen) }
        $newScreen = $this.ScreenFactory.CreateScreen($screenName, $parameters)
        $this.CurrentScreen = $newScreen
        $newScreen.Initialize()
        $newScreen.OnEnter()
        if (Get-Command "Push-Screen" -ErrorAction SilentlyContinue) { Push-Screen -Screen $newScreen }
        else { if ($global:TuiState) { $global:TuiState.CurrentScreen = $newScreen; Request-TuiRefresh } }
    }
    [bool] PopScreen() {
        if ($this.ScreenStack.Count -eq 0) { return $false }
        $this.CurrentScreen?.OnExit()
        $this.CurrentScreen = $this.ScreenStack.Pop()
        $this.CurrentScreen?.OnResume()
        if (Get-Command "Pop-Screen" -ErrorAction SilentlyContinue) { Pop-Screen }
        else { if ($global:TuiState) { $global:TuiState.CurrentScreen = $this.CurrentScreen; Request-TuiRefresh } }
        return $true
    }
    [void] RequestExit() {
        while ($this.PopScreen()) {}
        $this.CurrentScreen?.OnExit()
        Publish-Event -EventName "Application.Exit"
    }
}

class DataManager : IDisposable {
    hidden [hashtable]$_dataStore
    hidden [string]$_dataFilePath
    hidden [bool]$_dataModified = $false
    hidden [System.Collections.Generic.Dictionary[string, object]] $_taskIndex
    hidden [System.Collections.Generic.Dictionary[string, object]] $_projectIndex
    DataManager() {
        $this._dataStore = @{ Projects = [System.Collections.ArrayList]::new(); Tasks = [System.Collections.ArrayList]::new(); Settings = @{} }
        $this._taskIndex = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this._projectIndex = [System.Collections.Generic.Dictionary[string, object]]::new()
        $baseDir = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal"
        $this._dataFilePath = Join-Path $baseDir "pmc-data.json"
        if (-not (Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir -Force | Out-Null }
        $this.LoadData()
    }
    [void] Dispose() { if ($this._dataModified) { $this.SaveData() } }
    hidden [void] LoadData() {
        if (Test-Path $this._dataFilePath) {
            $jsonData = Get-Content $this._dataFilePath -Raw | ConvertFrom-Json -AsHashtable
            if ($jsonData.Tasks) { foreach ($taskData in $jsonData.Tasks) { [void]$this._dataStore.Tasks.Add([PmcTask]::FromLegacyFormat($taskData)) } }
            if ($jsonData.Projects) { foreach ($projectData in $jsonData.Projects) { [void]$this._dataStore.Projects.Add([PmcProject]::FromLegacyFormat($projectData)) } }
        }
        $this._RebuildIndexes()
    }
    hidden [void] _RebuildIndexes() {
        $this._taskIndex.Clear(); $this._projectIndex.Clear()
        foreach ($task in $this._dataStore.Tasks) { if ($task.Id) { $this._taskIndex[$task.Id] = $task } }
        foreach ($project in $this._dataStore.Projects) { if ($project.Key) { $this._projectIndex[$project.Key] = $project } }
    }
    [void] SaveData() {
        $saveData = @{ Tasks = @(); Projects = @(); Settings = $this._dataStore.Settings }
        foreach ($task in $this._dataStore.Tasks) { $saveData.Tasks += $task.ToLegacyFormat() }
        foreach ($project in $this._dataStore.Projects) { $saveData.Projects += $project.ToLegacyFormat() }
        $saveData | ConvertTo-Json -Depth 10 | Set-Content -Path $this._dataFilePath -Encoding UTF8 -Force
        $this._dataModified = $false
    }
    [PmcTask] AddTask([PmcTask]$newTask) {
        if ([string]::IsNullOrEmpty($newTask.Id)) { $newTask.Id = [guid]::NewGuid().ToString() }
        [void]$this._dataStore.Tasks.Add($newTask)
        $this._taskIndex[$newTask.Id] = $newTask
        $this._dataModified = $true
        return $newTask
    }
    [bool] RemoveTask([string]$taskId) {
        $taskToRemove = $this._taskIndex[$taskId]
        if (-not $taskToRemove) { return $false }
        [void]$this._dataStore.Tasks.Remove($taskToRemove)
        [void]$this._taskIndex.Remove($taskId)
        $this._dataModified = $true
        return $true
    }
    [PmcTask] GetTask([string]$taskId) {
        if ($this._taskIndex.ContainsKey($taskId)) { return $this._taskIndex[$taskId] }
        return $null
    }
    [PmcTask[]] GetTasks() {
        return $this._dataStore.Tasks.ToArray()
    }
}

class TuiFrameworkService {
    [void] StopAllAsyncJobs() {}
}

#endregion

#region --- Level 3: Screen Classes (Inherit from Screen) ---

class DashboardScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [Panel] $_summaryPanel
    hidden [Panel] $_statusPanel
    hidden [int] $_totalTasks = 0
    hidden [int] $_completedTasks = 0
    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}
    [void] Initialize() {
        $this._mainPanel = [Panel]::new("MainPanel", 0, 0, $this.Width, $this.Height, "Dashboard")
        $this.AddChild($this._mainPanel)
        $this._summaryPanel = [Panel]::new("SummaryPanel", 1, 1, [Math]::Floor($this.Width / 2), 10, "Summary")
        $this._mainPanel.AddChild($this._summaryPanel)
        $this._statusPanel = [Panel]::new("StatusPanel", 1, 12, $this.Width - 2, 5, "Status")
        $this._mainPanel.AddChild($this._statusPanel)
    }
    [void] OnEnter() { $this._RefreshData() }
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($keyInfo.Key -eq [ConsoleKey]::F5) {
            $this._RefreshData()
            return $true
        }
        return $false
    }
    hidden [void] _RefreshData() {
        $dataManager = $this.ServiceContainer.GetService("DataManager")
        $allTasks = $dataManager.GetTasks()
        $this._totalTasks = $allTasks.Count
        $this._completedTasks = ($allTasks | Where-Object { $_.Completed }).Count
        $this._UpdateDisplay()
    }
    hidden [void] _UpdateDisplay() {
        $this._summaryPanel.RequestRedraw()
        $this._statusPanel.RequestRedraw()
        $this.RequestRedraw()
    }
}

class TaskListScreen : Screen {
    hidden [Table] $_taskTable
    hidden [string] $_filterStatus = "All"
    TaskListScreen([object]$serviceContainer) : base("TaskListScreen", $serviceContainer) {}
    [void] Initialize() {
        $this._taskTable = [Table]::new("TaskTable")
        $this._taskTable.Move(1, 1)
        $this._taskTable.Resize($this.Width - 2, $this.Height - 2)
        $this._taskTable.SetColumns(@(
            [TableColumn]::new('Title', 'Task Title', 'Auto'),
            [TableColumn]::new('Status', 'Status', 15)
        ))
        $this.AddChild($this._taskTable)
    }
    [void] OnEnter() {
        $this._RefreshData()
        Set-ComponentFocus -Component $this._taskTable
    }
    hidden [void] _RefreshData() {
        $dataManager = $this.ServiceContainer.GetService('DataManager')
        $allTasks = $dataManager.GetTasks()
        $this._taskTable.SetData($allTasks)
    }
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        return $this._taskTable.HandleInput($keyInfo)
    }
}

#endregion