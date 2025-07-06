# ==============================================================================
# Axiom-Phoenix v5.0 - MONOLITH SCRIPT
#
# This script is a fully self-contained version of the application, created by
# analyzing all source modules and assembling them in the correct order to
# resolve class dependencies. All functions and classes are defined globally
# within this script's scope.
#
# Generated: 07/05/2025
# ==============================================================================

# --- Global Using Statements ---
# All required namespaces are consolidated here for the entire script.
using namespace System.Collections.Concurrent
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Text
using namespace System.Threading
using namespace System.Threading.Tasks

# --- Top-Level Parameters ---
# These parameters control the application's runtime behavior.
param(
    [switch]$Debug,
    [switch]$SkipLogo
)

# --- Global Settings ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ==============================================================================
# --- STAGE 1: ALL CLASS & ENUM DEFINITIONS ---
# All classes are defined here in a specific order to satisfy inheritance
# dependencies, resolving all cross-module type resolution errors.
# ==============================================================================

#region --- Level 0: Enums and Standalone Helper Classes ---

enum TaskStatus {
    Pending
    InProgress
    Completed
    Cancelled
}

enum TaskPriority {
    Low
    Medium
    High
}

enum BillingType {
    Billable
    NonBillable
}

class ValidationBase {
    static [void] ValidateNotEmpty([string]$value, [string]$parameterName) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw [System.ArgumentException]::new("Parameter '$($parameterName)' cannot be null or empty.", $parameterName)
        }
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
    static [string] Bold() { return "`e[1m" }
    static [string] Underline() { return "`e[4m" }
    static [string] Italic() { return "`e[3m" }
}

class TuiCell {
    [char]$Char = ' '; $ForegroundColor = [ConsoleColor]::White; $BackgroundColor = [ConsoleColor]::Black; [bool]$Bold = $false; [bool]$Underline = $false; [bool]$Italic = $false; [string]$StyleFlags = ""; [int]$ZIndex = 0; [object]$Metadata = $null
    TuiCell() {}
    TuiCell([char]$char) { $this.Char = $char }
    TuiCell([char]$char, $fg, $bg) { $this.Char = $char; $this.ForegroundColor = $fg; $this.BackgroundColor = $bg }
    TuiCell([char]$char, $fg, $bg, [bool]$bold, [bool]$underline) { $this.Char = $char; $this.ForegroundColor = $fg; $this.BackgroundColor = $bg; $this.Bold = $bold; $this.Underline = $underline }
    TuiCell([object]$other) { $this.Char = $other.Char; $this.ForegroundColor = $other.ForegroundColor; $this.BackgroundColor = $other.BackgroundColor; $this.Bold = $other.Bold; $this.Underline = $other.Underline; $this.Italic = $other.Italic; $this.StyleFlags = $other.StyleFlags; $this.ZIndex = $other.ZIndex; $this.Metadata = $other.Metadata }
    [TuiCell] BlendWith([object]$other) { if ($null -eq $other) { return $this }; if ($other.ZIndex -gt $this.ZIndex) { return [TuiCell]::new($other) }; if ($other.ZIndex -eq $this.ZIndex) { if ($other.Char -ne ' ' -or $other.Bold -or $other.Underline -or $other.Italic) { return [TuiCell]::new($other) }; if ($other.BackgroundColor -ne $this.BackgroundColor) { return [TuiCell]::new($other) } }; return $this }
    [bool] DiffersFrom([object]$other) { if ($null -eq $other) { return $true }; return ($this.Char -ne $other.Char -or $this.ForegroundColor -ne $other.ForegroundColor -or $this.BackgroundColor -ne $other.BackgroundColor -or $this.Bold -ne $other.Bold -or $this.Underline -ne $other.Underline -or $this.Italic -ne $other.Italic -or $this.ZIndex -ne $other.ZIndex) }
}

class TuiBuffer {
    [TuiCell[,]]$Cells; [int]$Width; [int]$Height; [string]$Name; [bool]$IsDirty = $true
    TuiBuffer([int]$width, [int]$height, [string]$name = "Unnamed") { if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }; if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }; $this.Width = $width; $this.Height = $height; $this.Name = $name; $this.Cells = New-Object 'TuiCell[,]' $height, $width; $this.Clear() }
    [void] Clear([TuiCell]$fillCell = [TuiCell]::new()) { for ($y = 0; $y -lt $this.Height; $y++) { for ($x = 0; $x -lt $this.Width; $x++) { $this.Cells[$y, $x] = [TuiCell]::new($fillCell) } }; $this.IsDirty = $true }
    [TuiCell] GetCell([int]$x, [int]$y) { if ($x -lt 0 -or $x -ge $this.Width -or $y -lt 0 -or $y -ge $this.Height) { return [TuiCell]::new() }; return $this.Cells[$y, $x] }
    [void] SetCell([int]$x, [int]$y, [TuiCell]$cell) { if ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height) { $this.Cells[$y, $x] = $cell; $this.IsDirty = $true } }
    [void] BlendBuffer([object]$other, [int]$offsetX, [int]$offsetY) { for ($y = 0; $y -lt $other.Height; $y++) { for ($x = 0; $x -lt $other.Width; $x++) { $targetX = $offsetX + $x; $targetY = $offsetY + $y; if ($targetX -ge 0 -and $targetX -lt $this.Width -and $targetY -ge 0 -and $targetY -lt $this.Height) { $sourceCell = $other.GetCell($x, $y); $targetCell = $this.GetCell($targetX, $targetY); $blendedCell = $targetCell.BlendWith($sourceCell); $this.SetCell($targetX, $targetY, $blendedCell) } } }; $this.IsDirty = $true }
    [void] Resize([int]$newWidth, [int]$newHeight) { if ($newWidth -le 0) { throw [System.ArgumentOutOfRangeException]::new("newWidth", "New width must be positive.") }; if ($newHeight -le 0) { throw [System.ArgumentOutOfRangeException]::new("newHeight", "New height must be positive.") }; $oldCells = $this.Cells; $oldWidth = $this.Width; $oldHeight = $this.Height; $this.Width = $newWidth; $this.Height = $newHeight; $this.Cells = New-Object 'TuiCell[,]' $newHeight, $newWidth; $this.Clear(); $copyWidth = [Math]::Min($oldWidth, $newWidth); $copyHeight = [Math]::Min($oldHeight, $newHeight); for ($y = 0; $y -lt $copyHeight; $y++) { for ($x = 0; $x -lt $copyWidth; $x++) { $this.Cells[$y, $x] = $oldCells[$y, $x] } }; $this.IsDirty = $true }
}

class TableColumn {
    [string]$Key; [string]$Header; [object]$Width; [string]$Alignment = "Left"
    TableColumn([string]$key, [string]$header, [object]$width) { if ([string]::IsNullOrWhiteSpace($key)) { throw [System.ArgumentException]::new("Parameter 'key' cannot be null or empty.") }; if ([string]::IsNullOrWhiteSpace($header)) { throw [System.ArgumentException]::new("Parameter 'header' cannot be null or empty.") }; if ($null -eq $width) { throw [System.ArgumentNullException]::new("width") }; $this.Key = $key; $this.Header = $header; $this.Width = $width }
}

class NavigationItem {
    [string]$Key; [string]$Label; [scriptblock]$Action; [bool]$Enabled = $true; [bool]$Visible = $true; [string]$Description = ""
    NavigationItem([string]$key, [string]$label, [scriptblock]$action) { if ([string]::IsNullOrWhiteSpace($key)) { throw [System.ArgumentException]::new("Navigation key cannot be null or empty") }; if ([string]::IsNullOrWhiteSpace($label)) { throw [System.ArgumentException]::new("Navigation label cannot be null or empty") }; if (-not $action) { throw [System.ArgumentNullException]::new("action", "Navigation action cannot be null") }; $this.Key = $key.ToUpper(); $this.Label = $label; $this.Action = $action }
    [void] Execute() { if (-not $this.Enabled) { return }; Invoke-WithErrorHandling -Component "NavigationItem" -Context "Execute '$($this.Key)'" -ScriptBlock $this.Action }
}
#endregion

#region --- Level 1: Core Data Models & Base UI Class ---

class PmcTask : ValidationBase {
    [string]$Id = [Guid]::NewGuid().ToString(); [string]$Title; [string]$Description; [TaskStatus]$Status = [TaskStatus]::Pending; [TaskPriority]$Priority = [TaskPriority]::Medium; [string]$ProjectKey = "General"; [string]$Category; [datetime]$CreatedAt = [datetime]::Now; [datetime]$UpdatedAt = [datetime]::Now; [Nullable[datetime]]$DueDate; [string[]]$Tags = @(); [int]$Progress = 0; [bool]$Completed = $false
    PmcTask() {}
    PmcTask([string]$title) { [ValidationBase]::ValidateNotEmpty($title, "Title"); $this.Title = $title }
    PmcTask([string]$title, [string]$description, [TaskPriority]$priority, [string]$projectKey) { [ValidationBase]::ValidateNotEmpty($title, "Title"); [ValidationBase]::ValidateNotEmpty($projectKey, "ProjectKey"); $this.Title = $title; $this.Description = $description; $this.Priority = $priority; $this.ProjectKey = $projectKey; $this.Category = $projectKey }
    [void] Complete() { $this.Status = [TaskStatus]::Completed; $this.Completed = $true; $this.Progress = 100; $this.UpdatedAt = [datetime]::Now }
    [void] UpdateProgress([int]$newProgress) { if ($newProgress -lt 0 -or $newProgress -gt 100) { throw [System.ArgumentOutOfRangeException]::new("newProgress", $newProgress, "Progress must be between 0 and 100.") }; $this.Progress = $newProgress; $this.Status = switch ($newProgress) { 100 { [TaskStatus]::Completed } { $_ -gt 0 } { [TaskStatus]::InProgress } default { [TaskStatus]::Pending } }; $this.Completed = ($this.Status -eq [TaskStatus]::Completed); $this.UpdatedAt = [datetime]::Now }
    [hashtable] ToLegacyFormat() { return @{ id = $this.Id; title = $this.Title; description = $this.Description; completed = $this.Completed; priority = $this.Priority.ToString().ToLower(); project = $this.ProjectKey; due_date = if ($this.DueDate) { $this.DueDate.Value.ToString("yyyy-MM-dd") } else { $null }; created_at = $this.CreatedAt.ToString("o"); updated_at = $this.UpdatedAt.ToString("o") } }
    static [PmcTask] FromLegacyFormat([hashtable]$legacyData) { $task = [PmcTask]::new(); $task.Id = $legacyData.id ?? $task.Id; $task.Title = $legacyData.title ?? ""; $task.Description = $legacyData.description ?? ""; if ($legacyData.priority) { try { $task.Priority = [TaskPriority]::$($legacyData.priority) } catch { $task.Priority = [TaskPriority]::Medium } }; $task.ProjectKey = $legacyData.project ?? $legacyData.Category ?? "General"; $task.Category = $task.ProjectKey; if ($legacyData.created_at) { try { $task.CreatedAt = [datetime]::Parse($legacyData.created_at) } catch { $task.CreatedAt = [datetime]::Now } }; if ($legacyData.updated_at) { try { $task.UpdatedAt = [datetime]::Parse($legacyData.updated_at) } catch { $task.UpdatedAt = $task.CreatedAt } }; if ($legacyData.due_date -and $legacyData.due_date -ne "N/A") { try { $task.DueDate = [datetime]::Parse($legacyData.due_date) } catch { $task.DueDate = $null } }; if ($legacyData.completed -is [bool] -and $legacyData.completed) { $task.Complete() } else { $task.UpdateProgress($task.Progress) }; return $task }
}

class PmcProject : ValidationBase {
    [string]$Key = ([Guid]::NewGuid().ToString().Split('-')[0]).ToUpper(); [string]$Name; [string]$Client; [BillingType]$BillingType = [BillingType]::NonBillable; [double]$Rate = 0.0; [double]$Budget = 0.0; [bool]$Active = $true; [datetime]$CreatedAt = [datetime]::Now; [datetime]$UpdatedAt = [datetime]::Now
    PmcProject() {}
    PmcProject([string]$key, [string]$name) { [ValidationBase]::ValidateNotEmpty($key, "Key"); [ValidationBase]::ValidateNotEmpty($name, "Name"); $this.Key = $key.ToUpper(); $this.Name = $name }
    [hashtable] ToLegacyFormat() { return @{ Key = $this.Key; Name = $this.Name; Client = $this.Client; BillingType = $this.BillingType.ToString(); Rate = $this.Rate; Budget = $this.Budget; Active = $this.Active; CreatedAt = $this.CreatedAt.ToString("o"); UpdatedAt = $this.UpdatedAt.ToString("o") } }
    static [PmcProject] FromLegacyFormat([hashtable]$legacyData) { $project = [PmcProject]::new(); $project.Key = ($legacyData.Key ?? $project.Key).ToUpper(); $project.Name = $legacyData.Name ?? ""; $project.Client = $legacyData.Client ?? ""; if ($legacyData.Rate) { try { $project.Rate = [double]$legacyData.Rate } catch {} }; if ($legacyData.Budget) { try { $project.Budget = [double]$legacyData.Budget } catch {} }; if ($legacyData.Active -is [bool]) { $project.Active = $legacyData.Active }; if ($legacyData.BillingType) { try { $project.BillingType = [BillingType]::$($legacyData.BillingType) } catch { $project.BillingType = [BillingType]::NonBillable } }; if ($legacyData.CreatedAt) { try { $project.CreatedAt = [datetime]::Parse($legacyData.CreatedAt) } catch { $project.CreatedAt = [datetime]::Now } }; if ($legacyData.UpdatedAt) { try { $project.UpdatedAt = [datetime]::Parse($legacyData.UpdatedAt) } catch { $project.UpdatedAt = $project.CreatedAt } } else { $project.UpdatedAt = $project.CreatedAt }; return $project }
}

class UIElement {
    [string]$Name = "UIElement"; [int]$X = 0; [int]$Y = 0; [int]$Width = 10; [int]$Height = 3; [bool]$Visible = $true; [bool]$Enabled = $true; [bool]$IsFocusable = $false; [bool]$IsFocused = $false; [int]$TabIndex = 0; [int]$ZIndex = 0; [UIElement]$Parent = $null; [System.Collections.Generic.List[UIElement]]$Children; hidden [object]$_private_buffer = $null; hidden [bool]$_needs_redraw = $true; [hashtable]$Metadata = @{}
    UIElement() { $this.Children = [System.Collections.Generic.List[UIElement]]::new(); $this._private_buffer = New-TuiBuffer -Width $this.Width -Height $this.Height -Name "$($this.Name).Buffer" }
    UIElement([string]$name) { $this.Name = $name; $this.Children = [System.Collections.Generic.List[UIElement]]::new(); $this._private_buffer = New-TuiBuffer -Width $this.Width -Height $this.Height -Name "$($this.Name).Buffer" }
    UIElement([int]$x, [int]$y, [int]$width, [int]$height) { if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }; if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }; $this.X = $x; $this.Y = $y; $this.Width = $width; $this.Height = $height; $this.Children = [System.Collections.Generic.List[UIElement]]::new(); $this._private_buffer = New-TuiBuffer -Width $width -Height $height -Name "Unnamed.Buffer" }
    [void] AddChild([object]$child) { if ($child -eq $this) { throw [System.ArgumentException]::new("Cannot add an element as its own child.") }; if ($this.Children.Contains($child)) { return }; $child.Parent = $this; $this.Children.Add($child); $this.RequestRedraw() }
    [void] RemoveChild([object]$child) { if ($this.Children.Remove($child)) { $child.Parent = $null; $this.RequestRedraw() } }
    [void] RequestRedraw() { $this._needs_redraw = $true; if ($null -ne $this.Parent) { $this.Parent.RequestRedraw() } }
    [void] Resize([int]$newWidth, [int]$newHeight) { if ($newWidth -le 0) { throw [System.ArgumentOutOfRangeException]::new("newWidth", "New width must be positive.") }; if ($newHeight -le 0) { throw [System.ArgumentOutOfRangeException]::new("newHeight", "New height must be positive.") }; if ($this.Width -eq $newWidth -and $this.Height -eq $newHeight) { return }; $this.Width = $newWidth; $this.Height = $newHeight; if ($null -ne $this._private_buffer) { $this._private_buffer.Resize($newWidth, $newHeight) } else { $this._private_buffer = New-TuiBuffer -Width $newWidth -Height $newHeight -Name "$($this.Name).Buffer" }; $this.RequestRedraw(); $this.OnResize($newWidth, $newHeight) }
    [void] Move([int]$newX, [int]$newY) { if ($this.X -eq $newX -and $this.Y -eq $newY) { return }; $this.X = $newX; $this.Y = $newY; $this.RequestRedraw(); $this.OnMove($newX, $newY) }
    [void] OnRender() { if ($null -ne $this._private_buffer) { $this._private_buffer.Clear() } }
    [void] OnResize([int]$newWidth, [int]$newHeight) {}
    [void] OnMove([int]$newX, [int]$newY) {}
    [void] OnFocus() {}
    [void] OnBlur() {}
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) { return $false }
    [void] Render() { if (-not $this.Visible) { return }; $this._RenderContent() }
    hidden [void] _RenderContent() { if (-not $this.Visible) { return }; if ($this._needs_redraw -or ($null -eq $this._private_buffer)) { if ($null -eq $this._private_buffer -or $this._private_buffer.Width -ne $this.Width -or $this._private_buffer.Height -ne $this.Height) { $bufferWidth = [Math]::Max(1, $this.Width); $bufferHeight = [Math]::Max(1, $this.Height); $this._private_buffer = New-TuiBuffer -Width $bufferWidth -Height $bufferHeight -Name "$($this.Name).Buffer" }; $this.OnRender(); $this._needs_redraw = $false }; foreach ($child in $this.Children | Sort-Object ZIndex) { if ($child.Visible) { $child.Render(); if ($null -ne $child._private_buffer) { $this._private_buffer.BlendBuffer($child._private_buffer, $child.X, $child.Y) } } } }
    [object] GetBuffer() { return $this._private_buffer }
}
#endregion

#region --- Level 2: UI Containers and Components (Inherit from UIElement) ---

class Panel : UIElement {
    [string]$Title = ""; [string]$BorderStyle = "Single"; [ConsoleColor]$BorderColor = [ConsoleColor]::Gray; [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black; [ConsoleColor]$TitleColor = [ConsoleColor]::White; [bool]$HasBorder = $true; [bool]$CanFocus = $false; [int]$ContentX = 0; [int]$ContentY = 0; [int]$ContentWidth = 0; [int]$ContentHeight = 0; [string]$LayoutType = "Manual"
    Panel() : base() { $this.Name = "Panel_$(Get-Random -Maximum 1000)"; $this.IsFocusable = $false; $this.UpdateContentBounds() }
    Panel([int]$x, [int]$y, [int]$width, [int]$height) : base($x, $y, $width, $height) { $this.Name = "Panel_$(Get-Random -Maximum 1000)"; $this.IsFocusable = $false; $this.UpdateContentBounds() }
    Panel([int]$x, [int]$y, [int]$width, [int]$height, [string]$title) : base($x, $y, $width, $height) { $this.Name = "Panel_$(Get-Random -Maximum 1000)"; $this.Title = $title; $this.IsFocusable = $false; $this.UpdateContentBounds() }
    [void] UpdateContentBounds() { if ($this.HasBorder) { $this.ContentX = 1; $this.ContentY = 1; $this.ContentWidth = [Math]::Max(0, $this.Width - 2); $this.ContentHeight = [Math]::Max(0, $this.Height - 2) } else { $this.ContentX = 0; $this.ContentY = 0; $this.ContentWidth = $this.Width; $this.ContentHeight = $this.Height } }
    [void] OnResize([int]$newWidth, [int]$newHeight) { ([UIElement]$this).OnResize($newWidth, $newHeight); $this.UpdateContentBounds(); $this.PerformLayout() }
    [void] PerformLayout() { if ($this.Children.Count -eq 0) { return }; switch ($this.LayoutType) { "Vertical" { $this.LayoutVertical() } "Horizontal" { $this.LayoutHorizontal() } "Grid" { $this.LayoutGrid() } } }
    hidden [void] LayoutVertical() { if ($this.Children.Count -eq 0) { return }; $currentY = $this.ContentY; $childWidth = $this.ContentWidth; $availableHeight = $this.ContentHeight; $childHeight = [Math]::Max(1, [Math]::Floor($availableHeight / $this.Children.Count)); for ($i = 0; $i -lt $this.Children.Count; $i++) { $child = $this.Children[$i]; $child.X = $this.ContentX; $child.Y = $currentY; if ($i -eq ($this.Children.Count - 1)) { $remainingHeight = $this.ContentY + $this.ContentHeight - $currentY; $child.Resize($childWidth, [Math]::Max(1, $remainingHeight)) } else { $child.Resize($childWidth, $childHeight) }; $currentY += $child.Height } }
    hidden [void] LayoutHorizontal() { if ($this.Children.Count -eq 0) { return }; $currentX = $this.ContentX; $childHeight = $this.ContentHeight; $availableWidth = $this.ContentWidth; $childWidth = [Math]::Max(1, [Math]::Floor($availableWidth / $this.Children.Count)); for ($i = 0; $i -lt $this.Children.Count; $i++) { $child = $this.Children[$i]; $child.X = $currentX; $child.Y = $this.ContentY; if ($i -eq ($this.Children.Count - 1)) { $remainingWidth = $this.ContentX + $this.ContentWidth - $currentX; $child.Resize([Math]::Max(1, $remainingWidth), $childHeight) } else { $child.Resize($childWidth, $childHeight) }; $currentX += $child.Width } }
    hidden [void] LayoutGrid() { if ($this.Children.Count -eq 0) { return }; $childCount = $this.Children.Count; $cols = [Math]::Ceiling([Math]::Sqrt($childCount)); $rows = [Math]::Ceiling($childCount / $cols); $cellWidth = [Math]::Max(1, [Math]::Floor($this.ContentWidth / $cols)); $cellHeight = [Math]::Max(1, [Math]::Floor($this.ContentHeight / $rows)); for ($i = 0; $i -lt $this.Children.Count; $i++) { $child = $this.Children[$i]; $row = [Math]::Floor($i / $cols); $col = $i % $cols; $x = $this.ContentX + ($col * $cellWidth); $y = $this.ContentY + ($row * $cellHeight); $width = if ($col -eq ($cols - 1)) { $this.ContentX + $this.ContentWidth - $x } else { $cellWidth }; $height = if ($row -eq ($rows - 1)) { $this.ContentY + $this.ContentHeight - $y } else { $cellHeight }; $child.Move($x, $y); $child.Resize([Math]::Max(1, $width), [Math]::Max(1, $height)) } }
    [void] OnRender() { if ($null -eq $this._private_buffer) { return }; $bgCell = [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor); $this._private_buffer.Clear($bgCell); if ($this.HasBorder) { Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle $this.BorderStyle -BorderColor $this.BorderColor -BackgroundColor $this.BackgroundColor -Title $this.Title } }
    [void] WriteToBuffer([int]$x, [int]$y, [string]$text, [ConsoleColor]$fg, [ConsoleColor]$bg) { if ($null -eq $this._private_buffer) { return }; Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $text -ForegroundColor $fg -BackgroundColor $bg }
    [void] ClearContent() { if ($null -eq $this._private_buffer) { return }; $clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor); for ($y = $this.ContentY; $y -lt ($this.ContentY + $this.ContentHeight); $y++) { for ($x = $this.ContentX; $x -lt ($this.ContentX + $this.ContentWidth); $x++) { $this._private_buffer.SetCell($x, $y, $clearCell) } }; $this.RequestRedraw() }
}

class LabelComponent : UIElement {
    [string]$Text = ""; [object]$ForegroundColor
    LabelComponent([string]$name) : base($name) { $this.IsFocusable = $false; $this.Width = 10; $this.Height = 1 }
    [void] OnRender() { if (-not $this.Visible -or $null -eq $this._private_buffer) { return }; $this._private_buffer.Clear(); $fg = $this.ForegroundColor ?? (Get-ThemeColor 'Foreground'); $bg = Get-ThemeColor 'Background'; Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $this.Text -ForegroundColor $fg -BackgroundColor $bg }
}

class ButtonComponent : UIElement {
    [string]$Text = "Button"; [bool]$IsPressed = $false; [scriptblock]$OnClick
    ButtonComponent([string]$name) : base($name) { $this.IsFocusable = $true; $this.Width = 10; $this.Height = 3 }
    [void] OnRender() { if (-not $this.Visible -or $null -eq $this._private_buffer) { return }; $state = if ($this.IsPressed) { "pressed" } elseif ($this.IsFocused) { "focus" } else { "normal" }; $bgColor = Get-ThemeColor "button.$state.background" -Default (if ($this.IsPressed) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Background' }); $borderColor = Get-ThemeColor "button.$state.border" -Default (if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Border' }); $fgColor = Get-ThemeColor "button.$state.foreground" -Default (if ($this.IsPressed) { Get-ThemeColor 'Background' } else { Get-ThemeColor 'Foreground' }); $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor)); Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor; $textX = [Math]::Floor(($this.Width - $this.Text.Length) / 2); $textY = [Math]::Floor(($this.Height - 1) / 2); Write-TuiText -Buffer $this._private_buffer -X $textX -Y $textY -Text $this.Text -ForegroundColor $fgColor -BackgroundColor $bgColor }
    [bool] HandleInput([System.ConsoleKeyInfo]$key) { if ($null -eq $key) { return $false }; if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) { $this.IsPressed = $true; $this.RequestRedraw(); if ($this.OnClick) { & $this.OnClick }; Start-Sleep -Milliseconds 50; $this.IsPressed = $false; $this.RequestRedraw(); return $true }; return $false }
}

class TextBoxComponent : UIElement {
    [string]$Text = ""; [string]$Placeholder = ""; [int]$MaxLength = 100; [int]$CursorPosition = 0; [scriptblock]$OnChange; hidden [int]$_scrollOffset = 0
    TextBoxComponent([string]$name) : base($name) { $this.IsFocusable = $true; $this.Width = 20; $this.Height = 3 }
    [void] OnRender() { if (-not $this.Visible -or $null -eq $this._private_buffer) { return }; $bgColor = Get-ThemeColor 'Background'; $borderColor = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Border' }; $textColor = Get-ThemeColor 'Foreground'; $placeholderColor = Get-ThemeColor 'Subtle'; $this._private_buffer.Clear([TuiCell]::new(' ', $textColor, $bgColor)); Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor; $textAreaWidth = $this.Width - 2; $displayText = $this.Text ?? ""; $currentTextColor = $textColor; if ([string]::IsNullOrEmpty($displayText) -and -not $this.IsFocused) { $displayText = $this.Placeholder ?? ""; $currentTextColor = $placeholderColor }; if ($displayText.Length -gt $textAreaWidth) { $displayText = $displayText.Substring($this._scrollOffset, [Math]::Min($textAreaWidth, $displayText.Length - $this._scrollOffset)) }; if (-not [string]::IsNullOrEmpty($displayText)) { Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $displayText -ForegroundColor $currentTextColor -BackgroundColor $bgColor }; if ($this.IsFocused) { $cursorX = 1 + ($this.CursorPosition - $this._scrollOffset); if ($cursorX -ge 1 -and $cursorX -lt ($this.Width - 1)) { $cell = $this._private_buffer.GetCell($cursorX, 1); if ($null -ne $cell) { $cell.BackgroundColor = Get-ThemeColor 'Accent'; $cell.ForegroundColor = Get-ThemeColor 'Background'; $this._private_buffer.SetCell($cursorX, 1, $cell) } } } }
    [bool] HandleInput([System.ConsoleKeyInfo]$key) { if ($null -eq $key) { return $false }; $originalText = $this.Text; switch ($key.Key) { ([ConsoleKey]::Backspace) { if ($this.CursorPosition -gt 0) { $this.Text = $this.Text.Remove($this.CursorPosition - 1, 1); $this.CursorPosition-- } } ([ConsoleKey]::Delete) { if ($this.CursorPosition -lt $this.Text.Length) { $this.Text = $this.Text.Remove($this.CursorPosition, 1) } } ([ConsoleKey]::LeftArrow) { if ($this.CursorPosition -gt 0) { $this.CursorPosition-- } } ([ConsoleKey]::RightArrow) { if ($this.CursorPosition -lt $this.Text.Length) { $this.CursorPosition++ } } ([ConsoleKey]::Home) { $this.CursorPosition = 0 } ([ConsoleKey]::End) { $this.CursorPosition = $this.Text.Length } default { if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar) -and $this.Text.Length -lt $this.MaxLength) { $this.Text = $this.Text.Insert($this.CursorPosition, $key.KeyChar); $this.CursorPosition++ } else { return $false } } }; $this._UpdateScrollOffset(); if ($this.Text -ne $originalText -and $this.OnChange) { & $this.OnChange -NewValue $this.Text }; $this.RequestRedraw(); return $true }
    hidden [void] _UpdateScrollOffset() { $textAreaWidth = $this.Width - 2; if ($this.CursorPosition -gt ($this._scrollOffset + $textAreaWidth - 1)) { $this._scrollOffset = $this.CursorPosition - $textAreaWidth + 1 }; if ($this.CursorPosition -lt $this._scrollOffset) { $this._scrollOffset = $this.CursorPosition }; $maxScroll = [Math]::Max(0, $this.Text.Length - $textAreaWidth); $this._scrollOffset = [Math]::Min($this._scrollOffset, $maxScroll); $this._scrollOffset = [Math]::Max(0, $this._scrollOffset) }
}

class CheckBoxComponent : UIElement {
    [string]$Text = "Checkbox"; [bool]$Checked = $false; [scriptblock]$OnChange
    CheckBoxComponent([string]$name) : base($name) { $this.IsFocusable = $true; $this.Width = 20; $this.Height = 1 }
    [void] OnRender() { if (-not $this.Visible -or $null -eq $this._private_buffer) { return }; $this._private_buffer.Clear(); $fg = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Foreground' }; $bg = Get-ThemeColor 'Background'; $checkbox = if ($this.Checked) { "[X]" } else { "[ ]" }; $displayText = "$checkbox $($this.Text)"; Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg -BackgroundColor $bg }
    [bool] HandleInput([System.ConsoleKeyInfo]$key) { if ($null -eq $key) { return $false }; if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) { $this.Checked = -not $this.Checked; if ($this.OnChange) { & $this.OnChange -NewValue $this.Checked }; $this.RequestRedraw(); return $true }; return $false }
}

class RadioButtonComponent : UIElement {
    [string]$Text = "Option"; [bool]$Selected = $false; [string]$GroupName = ""; [scriptblock]$OnChange
    RadioButtonComponent([string]$name) : base($name) { $this.IsFocusable = $true; $this.Width = 20; $this.Height = 1 }
    [void] OnRender() { if (-not $this.Visible -or $null -eq $this._private_buffer) { return }; $this._private_buffer.Clear(); $fg = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Foreground' }; $bg = Get-ThemeColor 'Background'; $radio = if ($this.Selected) { "(●)" } else { "( )" }; $displayText = "$radio $($this.Text)"; Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg -BackgroundColor $bg }
    [bool] HandleInput([System.ConsoleKeyInfo]$key) { if ($null -eq $key) { return $false }; if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) { if (-not $this.Selected) { $this.Selected = $true; if ($this.Parent -and $this.GroupName) { $this.Parent.Children | Where-Object { $_ -is [RadioButtonComponent] -and $_.GroupName -eq $this.GroupName -and $_ -ne $this } | ForEach-Object { $_.Selected = $false; $_.RequestRedraw() } }; if ($this.OnChange) { & $this.OnChange -NewValue $this.Selected }; $this.RequestRedraw() }; return $true }; return $false }
}
#endregion

#region --- Level 3: Advanced UI Components and Screens ---

class Screen : UIElement {
    [hashtable]$Services; [object]$ServiceContainer; [System.Collections.Generic.Dictionary[string, object]]$State; [System.Collections.Generic.List[UIElement]]$Panels; $LastFocusedComponent; hidden [System.Collections.Generic.Dictionary[string, string]]$EventSubscriptions
    Screen([string]$name, [hashtable]$services) : base($name) { $this.Services = $services; $this.State = [System.Collections.Generic.Dictionary[string, object]]::new(); $this.Panels = [System.Collections.Generic.List[UIElement]]::new(); $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new(); $this.ServiceContainer = $null }
    Screen([string]$name, [object]$serviceContainer) : base($name) { $this.ServiceContainer = $serviceContainer; $this.Services = [hashtable]::new(); if ($this.ServiceContainer.PSObject.Methods['GetAllRegisteredServices'] -and $this.ServiceContainer.PSObject.Methods['GetService']) { try { $registeredServices = $this.ServiceContainer.GetAllRegisteredServices(); foreach ($service in $registeredServices) { try { $this.Services[$service.Name] = $this.ServiceContainer.GetService($service.Name) } catch { Write-Warning "Screen '$($this.Name)': Failed to resolve service '$($service.Name)' from container: $($_.Exception.Message)" } } } catch { Write-Warning "Screen '$($this.Name)': Failed to enumerate services from container: $($_.Exception.Message)" } }; $this.State = [System.Collections.Generic.Dictionary[string, object]]::new(); $this.Panels = [System.Collections.Generic.List[UIElement]]::new(); $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new() }
    [void] Initialize() {}
    [void] OnEnter() {}
    [void] OnExit() {}
    [void] OnResume() {}
    [void] AddPanel([object]$panel) { $this.Panels.Add($panel); $this.AddChild($panel) }
}

class Dialog : UIElement {
    [string]$Title = "Dialog"; [string]$Message = ""; hidden [TaskCompletionSource[object]] $_tcs
    Dialog([string]$name) : base($name) { $this.IsFocusable = $true; $this.Width = 50; $this.Height = 10; $this._tcs = [TaskCompletionSource[object]]::new() }
    [Task[object]] Show() { $this.X = [Math]::Floor(($global:TuiState.BufferWidth - $this.Width) / 2); $this.Y = [Math]::Floor(($global:TuiState.BufferHeight - $this.Height) / 4); Show-TuiOverlay -Element $this; Set-ComponentFocus -Component $this; return $this._tcs.Task }
    [void] Close([object]$result, [bool]$wasCancelled = $false) { if ($wasCancelled) { $this._tcs.TrySetCanceled() } else { $this._tcs.TrySetResult($result) }; Close-TopTuiOverlay }
    [void] OnRender() { if (-not $this._private_buffer) { return }; $bgColor = Get-ThemeColor 'dialog.background' -Default (Get-ThemeColor 'Background'); $borderColor = Get-ThemeColor 'dialog.border' -Default (Get-ThemeColor 'Border'); $titleColor = Get-ThemeColor 'dialog.title' -Default (Get-ThemeColor 'Accent'); $clearCell = [TuiCell]::new(' ', $titleColor, $bgColor); $clearCell.ZIndex = 100; $this._private_buffer.Clear($clearCell); Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -Title " $($this.Title) " -BorderStyle "Double" -BorderColor $borderColor -BackgroundColor $bgColor; if (-not [string]::IsNullOrWhiteSpace($this.Message)) { $this._RenderMessage() }; $this.RenderDialogContent() }
    hidden [void] _RenderMessage() { $messageColor = Get-ThemeColor 'dialog.message' -Default (Get-ThemeColor 'Foreground'); $bgColor = Get-ThemeColor 'dialog.background' -Default (Get-ThemeColor 'Background'); $messageY = 2; $messageX = 2; $maxWidth = $this.Width - 4; $wrappedLines = Get-WordWrappedLines -Text $this.Message -MaxWidth $maxWidth; foreach ($line in $wrappedLines) { if ($messageY -ge ($this.Height - 3)) { break }; Write-TuiText -Buffer $this._private_buffer -X $messageX -Y $messageY -Text $line -ForegroundColor $messageColor -BackgroundColor $bgColor; $messageY++ } }
    [void] RenderDialogContent() {}
    [bool] HandleInput([ConsoleKeyInfo]$key) { if ($key.Key -eq [ConsoleKey]::Escape) { $this.Close($null, $true); return $true }; return $false }
}

class AlertDialog : Dialog {
    AlertDialog([string]$title, [string]$message) : base("AlertDialog") { $this.Title = $title; $this.Message = $message; $this.Height = 8; $this.Width = [Math]::Min(70, [Math]::Max(40, $message.Length + 10)) }
    [void] RenderDialogContent() { $buttonFg = Get-ThemeColor 'dialog.button.focus.foreground' -Default (Get-ThemeColor 'Background'); $buttonBg = Get-ThemeColor 'dialog.button.focus.background' -Default (Get-ThemeColor 'Accent'); $buttonY = $this.Height - 2; $buttonLabel = " [ OK ] "; $buttonX = [Math]::Floor(($this.Width - $buttonLabel.Length) / 2); Write-TuiText -Buffer $this._private_buffer -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor $buttonFg -BackgroundColor $buttonBg }
    [bool] HandleInput([ConsoleKeyInfo]$key) { if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) { $this.Close($true); return $true }; return ([Dialog]$this).HandleInput($key) }
}

class ConfirmDialog : Dialog {
    hidden [int]$_selectedButton = 0
    ConfirmDialog([string]$title, [string]$message) : base("ConfirmDialog") { $this.Title = $title; $this.Message = $message; $this.Height = 8; $this.Width = [Math]::Min(70, [Math]::Max(50, $message.Length + 10)) }
    [void] RenderDialogContent() { $normalFg = Get-ThemeColor 'dialog.button.normal.foreground' -Default (Get-ThemeColor 'Foreground'); $normalBg = Get-ThemeColor 'dialog.button.normal.background' -Default (Get-ThemeColor 'Background'); $focusFg = Get-ThemeColor 'dialog.button.focus.foreground' -Default (Get-ThemeColor 'Background'); $focusBg = Get-ThemeColor 'dialog.button.focus.background' -Default (Get-ThemeColor 'Accent'); $buttonY = $this.Height - 3; $buttons = @("  Yes  ", "  No   "); $startX = [Math]::Floor(($this.Width - 24) / 2); for ($i = 0; $i -lt $buttons.Count; $i++) { $isFocused = ($i -eq $this._selectedButton); $label = if ($isFocused) { "[ $($buttons[$i].Trim()) ]" } else { $buttons[$i] }; $fg = if ($isFocused) { $focusFg } else { $normalFg }; $bg = if ($isFocused) { $focusBg } else { $normalBg }; Write-TuiText -Buffer $this._private_buffer -X ($startX + ($i * 14)) -Y $buttonY -Text $label -ForegroundColor $fg -BackgroundColor $bg } }
    [bool] HandleInput([ConsoleKeyInfo]$key) { switch ($key.Key) { { $_ -in @([ConsoleKey]::LeftArrow, [ConsoleKey]::RightArrow, [ConsoleKey]::Tab) } { $this._selectedButton = ($this._selectedButton + 1) % 2; $this.RequestRedraw(); return $true } ([ConsoleKey]::Enter) { $result = ($this._selectedButton -eq 0); $this.Close($result); return $true } }; return ([Dialog]$this).HandleInput($key) }
}

class InputDialog : Dialog {
    hidden [TextBoxComponent]$_textBox
    InputDialog([string]$title, [string]$message, [string]$defaultValue = "") : base("InputDialog") { $this.Title = $title; $this.Message = $message; $this.Height = 10; $this.Width = [Math]::Min(70, [Math]::Max(50, $message.Length + 20)); $this.Metadata.DefaultValue = $defaultValue }
    [void] OnInitialize() { $this._textBox = New-TuiTextBox -Props @{ Name = 'DialogInput'; Text = $this.Metadata.DefaultValue; Width = $this.Width - 4; Height = 3; X = 2; Y = 4 }; $this.AddChild($this._textBox) }
    [bool] HandleInput([ConsoleKeyInfo]$key) { if ($key.Key -eq [ConsoleKey]::Enter) { $result = $this._textBox ? $this._textBox.Text : ""; $this.Close($result); return $true }; if ($this._textBox -and $this._textBox.HandleInput($key)) { return $true }; return ([Dialog]$this).HandleInput($key) }
}

class DashboardScreen : Screen {
    hidden [Panel] $_mainPanel; hidden [Panel] $_summaryPanel; hidden [Panel] $_statusPanel; hidden [Panel] $_helpPanel; hidden [int] $_totalTasks = 0; hidden [int] $_completedTasks = 0; hidden [int] $_pendingTasks = 0
    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}
    [void] Initialize() { $this._mainPanel = [Panel]::new(0, 0, $this.Width, $this.Height, "Axiom-Phoenix Dashboard"); $this.AddChild($this._mainPanel); $summaryWidth = [Math]::Floor($this.Width * 0.5); $this._summaryPanel = [Panel]::new(1, 1, $summaryWidth, 12, "Task Summary"); $this._mainPanel.AddChild($this._summaryPanel); $helpX = $summaryWidth + 2; $helpWidth = $this.Width - $helpX - 1; $this._helpPanel = [Panel]::new($helpX, 1, $helpWidth, 12, "Quick Start"); $this._mainPanel.AddChild($this._helpPanel); $this._statusPanel = [Panel]::new(1, 14, $this.Width - 2, $this.Height - 15, "System Status"); $this._mainPanel.AddChild($this._statusPanel); if ($this.PSObject.Methods['SubscribeToEvent']) { $this.SubscribeToEvent("Tasks.Changed", { param($EventData); if ($this.ServiceContainer) { $this._RefreshData($this.ServiceContainer.GetService("DataManager")) } }) } }
    [void] OnEnter() { if ($this.ServiceContainer) { $this._RefreshData($this.ServiceContainer.GetService("DataManager")) } else { $this._RefreshData($null) }; $this.RequestRedraw(); if ($this._mainPanel -and (Get-Command Set-ComponentFocus -ErrorAction SilentlyContinue)) { Set-ComponentFocus -Component $this._mainPanel } }
    hidden [void] _RefreshData([object]$dataManager) { if (-not $dataManager) { $this._totalTasks = 0; $this._completedTasks = 0; $this._pendingTasks = 0 } else { $allTasks = $dataManager.GetTasks(); $this._totalTasks = $allTasks.Count; $this._completedTasks = ($allTasks | Where-Object { $_.Completed }).Count; $this._pendingTasks = $this._totalTasks - $this._completedTasks }; $this._UpdateDisplay() }
    hidden [void] _UpdateDisplay() { $this._UpdateSummaryPanel(); $this._UpdateHelpPanel(); $this._UpdateStatusPanel(); $this.RequestRedraw() }
    hidden [void] _UpdateSummaryPanel() { $panel = $this._summaryPanel; if (-not $panel) { return }; $panel.ClearContent(); $panel.OnRender(); $headerColor = Get-ThemeColor 'Header'; $subtleColor = Get-ThemeColor 'Subtle'; $defaultColor = Get-ThemeColor 'Foreground'; $highlightColor = Get-ThemeColor 'Highlight'; $bgColor = Get-ThemeColor 'Background'; $buffer = $panel.GetBuffer(); $contentX = $panel.ContentX; $contentY = $panel.ContentY; Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY) -Text "Task Overview" -ForegroundColor $headerColor -BackgroundColor $bgColor; Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 3) -Text "Total Tasks:    $($this._totalTasks)" -ForegroundColor $defaultColor -BackgroundColor $bgColor; Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 4) -Text "Completed:      $($this._completedTasks)" -ForegroundColor $defaultColor -BackgroundColor $bgColor; Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 5) -Text "Pending:        $($this._pendingTasks)" -ForegroundColor $defaultColor -BackgroundColor $bgColor; $progress = $this._GetProgressBar(); Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 8) -Text $progress -ForegroundColor $highlightColor -BackgroundColor $bgColor; $panel.RequestRedraw() }
    hidden [void] _UpdateHelpPanel() { $panel = $this._helpPanel; if (-not $panel) { return }; $panel.ClearContent(); $panel.OnRender(); $paletteHotkey = "Ctrl+P"; $headerColor = Get-ThemeColor 'Header'; $defaultColor = Get-ThemeColor 'Foreground'; $accentColor = Get-ThemeColor 'Accent'; $bgColor = Get-ThemeColor 'Background'; $buffer = $panel.GetBuffer(); $contentX = $panel.ContentX; $contentY = $panel.ContentY; Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 0) -Text "Welcome to Axiom-Phoenix!" -ForegroundColor $headerColor -BackgroundColor $bgColor; Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 3) -Text "Press " -ForegroundColor $defaultColor -BackgroundColor $bgColor; Write-TuiText -Buffer $buffer -X ($contentX + 7) -Y ($contentY + 3) -Text $paletteHotkey -ForegroundColor $accentColor -BackgroundColor $bgColor; Write-TuiText -Buffer $buffer -X ($contentX + 7 + $paletteHotkey.Length) -Y ($contentY + 3) -Text " to open the Command Palette." -ForegroundColor $defaultColor -BackgroundColor $bgColor; $panel.RequestRedraw() }
    hidden [void] _UpdateStatusPanel() { $panel = $this._statusPanel; if (-not $panel) { return }; $panel.ClearContent(); $panel.OnRender(); $memoryMB = try { [Math]::Round((Get-Process -Id $global:PID).WorkingSet64 / 1MB, 2) } catch { 0 }; $headerColor = Get-ThemeColor 'Header'; $defaultColor = Get-ThemeColor 'Foreground'; $bgColor = Get-ThemeColor 'Background'; $buffer = $panel.GetBuffer(); $contentX = $panel.ContentX; $contentY = $panel.ContentY; Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 3) -Text "PowerShell Version: $($global:PSVersionTable.PSVersion)" -ForegroundColor $defaultColor -BackgroundColor $bgColor; Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 5) -Text "Memory Usage:       $($memoryMB) MB" -ForegroundColor $defaultColor -BackgroundColor $bgColor; $panel.RequestRedraw() }
    hidden [string] _GetProgressBar() { if ($this._totalTasks -eq 0) { return "No tasks defined." }; $percentage = [Math]::Round(($this._completedTasks / $this._totalTasks) * 100); $barLength = $this._summaryPanel.ContentWidth - 6; if ($barLength -lt 1) { $barLength = 1 }; $filledLength = [Math]::Floor(($percentage / 100) * $barLength); $bar = '█' * $filledLength + '░' * ($barLength - $filledLength); return "[$bar] $percentage%" }
}

class TaskListScreen : Screen {
    hidden [Panel] $_mainPanel; hidden [Table] $_taskTable; hidden [string] $_filterStatus = "All"; hidden [PmcTask] $_selectedTask
    TaskListScreen([object]$serviceContainer) : base("TaskListScreen", $serviceContainer) {}
    [void] OnInitialize() { $this._mainPanel = [Panel]::new(0, 0, $this.Width, $this.Height, "Task Management"); $this.AddChild($this._mainPanel); $tablePanel = [Panel]::new(1, 2, $this.Width - 2, $this.Height - 4); $this._mainPanel.AddChild($tablePanel); $this._taskTable = [Table]::new("TaskTable"); $this._taskTable.Move(0, 0); $this._taskTable.Resize($tablePanel.ContentWidth, $tablePanel.ContentHeight); $this._taskTable.ShowBorder = $false; $this._taskTable.SetColumns(@([TableColumn]::new('Title', 'Task Title', 'Auto'), [TableColumn]::new('Status', 'Status', 15), [TableColumn]::new('Priority', 'Priority', 12))); $this._taskTable.OnSelectionChanged = { param($SelectedItem) $this._selectedTask = $SelectedItem }.GetNewClosure(); $tablePanel.AddChild($this._taskTable); $this._RegisterActions(); $this.SubscribeToEvent("Tasks.Changed", { $this._RefreshData() }) }
    [void] OnEnter() { $keybindingService = $this.ServiceContainer.GetService('KeybindingService'); $keybindingService.PushContext('tasklist'); $this._RefreshData(); Set-ComponentFocus -Component $this._taskTable }
    [void] OnExit() { $keybindingService = $this.ServiceContainer.GetService('KeybindingService'); $keybindingService.PopContext() }
    hidden [void] _RegisterActions() { $actionService = $this.ServiceContainer.GetService('ActionService'); $keybindingService = $this.ServiceContainer.GetService('KeybindingService'); $context = 'tasklist'; $withSelectedTask = { param($scriptblock) if ($this._selectedTask) { . $scriptblock $this._selectedTask } else { Show-AlertDialog -Title 'No Task Selected' -Message 'Please select a task first.' | Out-Null } }; $actionService.RegisterAction("task.new", "Create a new task", { $this._ShowNewTaskDialog() }, "Tasks"); $keybindingService.SetBinding("task.new", 'N', $context); $actionService.RegisterAction("task.edit", "Edit selected task", { . $withSelectedTask { param($task) $this._ShowEditTaskDialog($task) } }, "Tasks"); $keybindingService.SetBinding("task.edit", 'E', $context); $actionService.RegisterAction("task.delete", "Delete selected task", { . $withSelectedTask { param($task) $this._ShowDeleteConfirmDialog($task) } }, "Tasks"); $keybindingService.SetBinding("task.delete", 'Delete', $context); $actionService.RegisterAction("task.toggleStatus", "Toggle task status", { . $withSelectedTask { param($task) $this._ToggleTaskStatus($task) } }, "Tasks"); $keybindingService.SetBinding("task.toggleStatus", 'Spacebar', $context); $actionService.RegisterAction("task.cycleFilter", "Cycle task filter", { $this._CycleFilter() }, "Tasks"); $keybindingService.SetBinding("task.cycleFilter", 'F', $context); $actionService.RegisterAction("task.back", "Return to dashboard", { $this.ServiceContainer.GetService('NavigationService').PopScreen() }, "Navigation"); $keybindingService.SetBinding("task.back", 'Escape', $context) }
    hidden [void] _RefreshData() { $dataManager = $this.ServiceContainer.GetService('DataManager'); $allTasks = $dataManager.GetTasks(); $filteredTasks = switch ($this._filterStatus) { "Active" { $allTasks | Where-Object { -not $_.Completed } } "Completed" { $allTasks | Where-Object { $_.Completed } } default { $allTasks } }; $this._taskTable.SetData($filteredTasks) }
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) { return $this._taskTable.HandleInput($keyInfo) }
    hidden [void] _ToggleTaskStatus([PmcTask]$task) { $task.UpdateProgress($task.Completed ? 0 : 100); $this.ServiceContainer.GetService('DataManager').UpdateTask($task) }
    hidden [void] _CycleFilter() { $this._filterStatus = switch ($this._filterStatus) { "All" { "Active" } "Active" { "Completed" } default { "All" } }; $this._RefreshData() }
    hidden [void] _ShowNewTaskDialog() { $title = await Show-InputDialog -Title "New Task" -Message "Enter task title:"; if ($title) { $newTask = [PmcTask]::new($title); $this.ServiceContainer.GetService('DataManager').AddTask($newTask) } }
    hidden [void] _ShowEditTaskDialog([PmcTask]$task) { $newTitle = await Show-InputDialog -Title "Edit Task" -Message "New title:" -DefaultValue $task.Title; if ($newTitle) { $task.Title = $newTitle; $this.ServiceContainer.GetService('DataManager').UpdateTask($task) } }
    hidden [void] _ShowDeleteConfirmDialog([PmcTask]$task) { $confirmed = await Show-ConfirmDialog -Title "Delete Task" -Message "Delete task `"$($task.Title)`"?"; if ($confirmed) { $this.ServiceContainer.GetService('DataManager').RemoveTask($task.Id) } }
}
#endregion

# ==============================================================================
# --- STAGE 2: ALL FUNCTION DEFINITIONS ---
# All functions from the various modules are defined here, becoming globally
# available within the script's scope.
# ==============================================================================

#region ####Functions from modules\dialog-system-class\dialog-system-class.psm1
function Show-AlertDialog { [CmdletBinding()] param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][string]$Message); try { $dialog = [AlertDialog]::new($Title, $Message); return $dialog.Show() } catch { Write-Error "Show-AlertDialog: Error creating alert dialog: $($_.Exception.Message)"; throw } }
function Show-ConfirmDialog { [CmdletBinding()] param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][string]$Message); try { $dialog = [ConfirmDialog]::new($Title, $Message); return $dialog.Show() } catch { Write-Error "Show-ConfirmDialog: Error creating confirm dialog: $($_.Exception.Message)"; throw } }
function Show-InputDialog { [CmdletBinding()] param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][string]$Message, [string]$DefaultValue = ""); try { $dialog = [InputDialog]::new($Title, $Message, $DefaultValue); return $dialog.Show() } catch { Write-Error "Show-InputDialog: Error creating input dialog: $($_.Exception.Message)"; throw } }
function Get-WordWrappedLines { [CmdletBinding()] param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][int]$MaxWidth); if ([string]::IsNullOrWhiteSpace($Text)) { return @() }; $lines = @(); $words = $Text -split '\s+'; $currentLine = ""; foreach ($word in $words) { $testLine = if ($currentLine) { "$currentLine $word" } else { $word }; if ($testLine.Length -le $MaxWidth) { $currentLine = $testLine } else { if ($currentLine) { $lines += $currentLine; $currentLine = $word } else { while ($word.Length -gt $MaxWidth) { $lines += $word.Substring(0, $MaxWidth); $word = $word.Substring($MaxWidth) }; $currentLine = $word } } }; if ($currentLine) { $lines += $currentLine }; return $lines }
#endregion

#region ####Functions from components\advanced-data-components\advanced-data-components.psm1
function New-TuiTable { [CmdletBinding()] param([hashtable]$Props = @{}); try { $tableName = $Props.Name ?? "Table_$([Guid]::NewGuid().ToString('N').Substring(0,8))"; $table = [Table]::new($tableName); $Props.GetEnumerator() | ForEach-Object { if ($table.PSObject.Properties.Match($_.Name)) { $table.($_.Name) = $_.Value } }; if ($Props.Columns) { $table.SetColumns($Props.Columns) }; if ($Props.Data) { $table.SetData($Props.Data) }; return $table } catch { Write-Error "Failed to create table: $($_.Exception.Message)"; throw } }
#endregion

#region ####Functions from components\advanced-input-components\advanced-input-components.psm1
function New-TuiMultilineTextBox { [CmdletBinding()] param([hashtable]$Props = @{}); try { $name = $Props.Name ?? "MultilineTextBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"; $component = [MultilineTextBoxComponent]::new($name); $Props.GetEnumerator() | ForEach-Object { if ($component.PSObject.Properties.Match($_.Name)) { $component.($_.Name) = $_.Value } }; return $component } catch { Write-Error "Failed to create multiline text box: $($_.Exception.Message)"; throw } }
function New-TuiNumericInput { [CmdletBinding()] param([hashtable]$Props = @{}); try { $name = $Props.Name ?? "NumericInput_$([Guid]::NewGuid().ToString('N').Substring(0,8))"; $component = [NumericInputComponent]::new($name); $Props.GetEnumerator() | ForEach-Object { if ($component.PSObject.Properties.Match($_.Name)) { $component.($_.Name) = $_.Value } }; return $component } catch { Write-Error "Failed to create numeric input: $($_.Exception.Message)"; throw } }
function New-TuiDateInput { [CmdletBinding()] param([hashtable]$Props = @{}); try { $name = $Props.Name ?? "DateInput_$([Guid]::NewGuid().ToString('N').Substring(0,8))"; $component = [DateInputComponent]::new($name); $Props.GetEnumerator() | ForEach-Object { if ($component.PSObject.Properties.Match($_.Name)) { $component.($_.Name) = $_.Value } }; return $component } catch { Write-Error "Failed to create date input: $($_.Exception.Message)"; throw } }
function New-TuiComboBox { [CmdletBinding()] param([hashtable]$Props = @{}); try { $name = $Props.Name ?? "ComboBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"; $component = [ComboBoxComponent]::new($name); $Props.GetEnumerator() | ForEach-Object { if ($component.PSObject.Properties.Match($_.Name)) { $component.($_.Name) = $_.Value } }; return $component } catch { Write-Error "Failed to create combo box: $($_.Exception.Message)"; throw } }
#endregion

#region ####Functions from components\tui-components\tui-components.psm1
function New-TuiLabel { [CmdletBinding()] param([hashtable]$Props = @{}); try { $labelName = $Props.Name ?? "Label_$([Guid]::NewGuid().ToString('N').Substring(0,8))"; $label = [LabelComponent]::new($labelName); $Props.GetEnumerator() | ForEach-Object { if ($label.PSObject.Properties.Match($_.Name)) { $label.($_.Name) = $_.Value } }; return $label } catch { Write-Error "Failed to create label: $($_.Exception.Message)"; throw } }
function New-TuiButton { [CmdletBinding()] param([hashtable]$Props = @{}); try { $buttonName = $Props.Name ?? "Button_$([Guid]::NewGuid().ToString('N').Substring(0,8))"; $button = [ButtonComponent]::new($buttonName); $Props.GetEnumerator() | ForEach-Object { if ($button.PSObject.Properties.Match($_.Name)) { $button.($_.Name) = $_.Value } }; return $button } catch { Write-Error "Failed to create button: $($_.Exception.Message)"; throw } }
function New-TuiTextBox { [CmdletBinding()] param([hashtable]$Props = @{}); try { $textBoxName = $Props.Name ?? "TextBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"; $textBox = [TextBoxComponent]::new($textBoxName); $Props.GetEnumerator() | ForEach-Object { if ($textBox.PSObject.Properties.Match($_.Name)) { $textBox.($_.Name) = $_.Value } }; return $textBox } catch { Write-Error "Failed to create textbox: $($_.Exception.Message)"; throw } }
function New-TuiCheckBox { [CmdletBinding()] param([hashtable]$Props = @{}); try { $checkBoxName = $Props.Name ?? "CheckBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"; $checkBox = [CheckBoxComponent]::new($checkBoxName); $Props.GetEnumerator() | ForEach-Object { if ($checkBox.PSObject.Properties.Match($_.Name)) { $checkBox.($_.Name) = $_.Value } }; return $checkBox } catch { Write-Error "Failed to create checkbox: $($_.Exception.Message)"; throw } }
function New-TuiRadioButton { [CmdletBinding()] param([hashtable]$Props = @{}); try { $radioButtonName = $Props.Name ?? "RadioButton_$([Guid]::NewGuid().ToString('N').Substring(0,8))"; $radioButton = [RadioButtonComponent]::new($radioButtonName); $Props.GetEnumerator() | ForEach-Object { if ($radioButton.PSObject.Properties.Match($_.Name)) { $radioButton.($_.Name) = $_.Value } }; return $radioButton } catch { Write-Error "Failed to create radio button: $($_.Exception.Message)"; throw } }
#endregion

#region ####Functions from components\command-palette\command-palette.psm1
function Register-CommandPalette { [CmdletBinding()] param([Parameter(Mandatory)][object]$ActionService, [Parameter(Mandatory)][object]$KeybindingService); try { Write-Log -Level Info -Message "Registering Command Palette"; $palette = [CommandPalette]::new($ActionService); $palette.Initialize(); $ActionService.RegisterAction("app.showCommandPalette", "Show the command palette for quick action access", { Publish-Event -EventName "CommandPalette.Open" }, "Application", $false); $KeybindingService.SetBinding("app.showCommandPalette", [System.ConsoleKey]::P, @('Ctrl')); Write-Log -Level Info -Message "Command Palette registered successfully with Ctrl+P keybinding"; return $palette } catch { Write-Error "Failed to register Command Palette: $($_.Exception.Message)"; throw } }
#endregion

#region ####Functions from modules\data-manager\data-manager.psm1
function Initialize-DataManager { [CmdletBinding()] param(); return Invoke-WithErrorHandling -Component "DataManager.Initialize" -Context "Creating DataManager instance" -ScriptBlock { return [DataManager]::new() } }
#endregion

#region ####Functions from modules\panic-handler\panic-handler.psm1
function Get-DetailedSystemInfo { [CmdletBinding()] param(); try { $process = Get-Process -Id $PID -ErrorAction SilentlyContinue; $systemInfo = [PSCustomObject]@{ Timestamp = (Get-Date -Format "o"); PowerShellVersion = $PSVersionTable.PSVersion.ToString(); OS = $PSVersionTable.OS; HostName = $Host.Name; HostVersion = $Host.Version.ToString(); ProcessId = $PID; ProcessName = $process?.ProcessName; WorkingSetMB = if ($process) { [Math]::Round($process.WorkingSet64 / 1MB, 2) } else { $null }; CommandLine = ([Environment]::CommandLine); CurrentDirectory = (Get-Location).Path; ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId; Culture = [System.Threading.Thread]::CurrentThread.CurrentCulture.Name }; if ($global:TuiState) { $systemInfo | Add-Member -MemberType NoteProperty -Name "TUIState" -Value @{ Running = $global:TuiState.Running; BufferWidth = $global:TuiState.BufferWidth; BufferHeight = $global:TuiState.BufferHeight; CurrentScreen = $global:TuiState.CurrentScreen?.Name; OverlayCount = $global:TuiState.OverlayStack.Count; IsDirty = $global:TuiState.IsDirty; FocusedComponent = $global:TuiState.FocusedComponent?.Name; FrameCount = $global:TuiState.RenderStats.FrameCount; } -Force }; return $systemInfo } catch { Write-Warning "PanicHandler: Failed to collect all system information: $($_.Exception.Message)"; return [PSCustomObject]@{ Timestamp = (Get-Date -Format "o"); Error = "Failed to collect system info: $($_.Exception.Message)" } } }
function Get-TerminalScreenshot { [CmdletBinding()] param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$outputPath); try { if (-not $global:TuiState -or -not $global:TuiState.CompositorBuffer) { return $null }; if (-not (Test-Path $outputPath)) { New-Item -ItemType Directory -Path $outputPath -Force -ErrorAction Stop | Out-Null }; $buffer = $global:TuiState.CompositorBuffer; $screenshotFileName = "screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"; $screenshotPath = Join-Path $outputPath $screenshotFileName; $sb = [System.Text.StringBuilder]::new($buffer.Width * $buffer.Height * 2); for ($y = 0; $y -lt $buffer.Height; $y++) { for ($x = 0; $x -lt $buffer.Width; $x++) { [void]$sb.Append($buffer.GetCell($x, $y).Char) }; [void]$sb.Append("`n") }; $sb.ToString() | Out-File -FilePath $screenshotPath -Encoding UTF8 -Force; return $screenshotPath } catch { Write-Warning "PanicHandler: Failed to capture terminal screenshot: $($_.Exception.Message)"; return $null } }
function Restore-Terminal { [CmdletBinding()] param(); try { [Console]::ResetColor(); [Console]::Clear(); [Console]::CursorVisible = $true; [Console]::TreatControlCAsInput = $false; Write-Host "`n===============================================" -ForegroundColor Red; Write-Host "    A CRITICAL APPLICATION ERROR OCCURRED!   " -ForegroundColor Red; Write-Host "===============================================" -ForegroundColor Red; Write-Host "`nA diagnostic crash report has been generated.`n  Crash Report Path: $($script:CrashLogDirectory)" -ForegroundColor White; Write-Host "`nPress any key to exit..." -ForegroundColor Gray; if ($Host.UI.RawUI) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } } catch { Write-Host "CRITICAL: PanicHandler failed to restore terminal: $($_.Exception.Message)" -ForegroundColor Red } }
function Initialize-PanicHandler { [CmdletBinding()] param([ValidateNotNullOrEmpty()][string]$CrashLogDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\CrashDumps"), [ValidateNotNullOrEmpty()][string]$ScreenshotsDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\Screenshots"), [ValidateNotNullOrEmpty()][string]$ApplicationLogDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal")); try { $script:CrashLogDirectory = $CrashLogDirectory; $script:ScreenshotsDirectory = $ScreenshotsDirectory; $script:LogDirectoryForPanic = $ApplicationLogDirectory; if (-not (Test-Path $script:CrashLogDirectory)) { New-Item -ItemType Directory -Path $script:CrashLogDirectory -Force -ErrorAction Stop | Out-Null }; if (-not (Test-Path $script:ScreenshotsDirectory)) { New-Item -ItemType Directory -Path $script:ScreenshotsDirectory -Force -ErrorAction Stop | Out-Null }; if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) { Write-Log -Level Info -Message "Panic Handler initialized." -Data @{ CrashLogDir = $script:CrashLogDirectory; ScreenshotsDir = $script:ScreenshotsDirectory; AppLogDir = $script:LogDirectoryForPanic; } } } catch { Write-Warning "PanicHandler: Failed to initialize: $($_.Exception.Message). Crash dumping might not work." } }
function Invoke-PanicHandler { [CmdletBinding()] param([Parameter(Mandatory)][ValidateNotNull()][System.Management.Automation.ErrorRecord]$ErrorRecord, [hashtable]$AdditionalContext = @{}); if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) { Write-Log -Level Fatal -Message "Panic handler invoked due to unhandled error." -Data @{ ErrorMessage = $ErrorRecord.Exception.Message; Type = $ErrorRecord.Exception.GetType().FullName; Stage = "PanicHandlerEntry" } -Force }; try { $crashTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'; $crashReportFileName = "crash_report_${crashTimestamp}.json"; $crashReportPath = Join-Path $script:CrashLogDirectory $crashReportFileName; $detailedError = if (Get-Command '_Get-DetailedError' -ErrorAction SilentlyContinue) { _Get-DetailedError -ErrorRecord $ErrorRecord -AdditionalContext $AdditionalContext } else { [PSCustomObject]@{ Timestamp = (Get-Date -Format "o"); Summary = $ErrorRecord.Exception.Message; Type = $ErrorRecord.Exception.GetType().FullName; StackTrace = $ErrorRecord.Exception.StackTrace; RawErrorRecord = $ErrorRecord.ToString(); AdditionalContext = $AdditionalContext; Warning = "Warning: _Get-DetailedError function was not available for full error context." } }; $systemInfo = Get-DetailedSystemInfo; $screenshotPath = Get-TerminalScreenshot -outputPath $script:ScreenshotsDirectory; $crashReport = @{ Timestamp = (Get-Date -Format "o"); Event = "ApplicationPanic"; Reason = $ErrorRecord.Exception.Message; ErrorDetails = $detailedError; SystemInfo = $systemInfo; ScreenshotFile = $screenshotPath; LastLogEntries = if (Get-Command 'Get-LogEntries' -ErrorAction SilentlyContinue) { (Get-LogEntries -Count 50 | Select-Object -ExpandProperty UserData) } else { $null }; ErrorHistory = if (Get-Command 'Get-ErrorHistory' -ErrorAction SilentlyContinue) { Get-ErrorHistory -Count 25 } else { $null }; }; $crashReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $crashReportPath -Encoding UTF8 -Force; if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) { Write-Log -Level Fatal -Message "Crash report saved to: $crashReportPath" -Data @{ Path = $crashReportPath } -Force } } catch { $criticalFailMessage = "$(Get-Date -Format 'o') [CRITICAL PANIC] PANIC HANDLER FAILED: $($_.Exception.Message)`nOriginal Error: $($ErrorRecord.Exception.Message)"; try { $panicFailLogPath = Join-Path $script:CrashLogDirectory "panic_handler_fail_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"; Add-Content -Path $panicFailLogPath -Value $criticalFailMessage -Encoding UTF8 -Force } catch {} } finally { Restore-Terminal; exit 1 } }
#endregion

#region ####Functions from services\action-service\action-service.psm1
function Initialize-ActionService { [CmdletBinding()] param(); return Invoke-WithErrorHandling -Component "ActionService.Initialize" -Context "Initializing action service" -ScriptBlock { $service = [ActionService]::new(); Write-Log -Level Info -Message "ActionService initialized."; return $service } }
#endregion

#region ####Functions from services\keybinding-service\keybinding-service.psm1
function New-KeybindingService { [CmdletBinding()] param([switch]$EnableChords); if ($EnableChords) { return [KeybindingService]::new($true) } else { return [KeybindingService]::new() } }
#endregion

#region ####Functions from services\navigation-service\navigation-service.psm1
function Initialize-NavigationService { param([hashtable]$Services); if (-not $Services) { throw [System.ArgumentNullException]::new("Services") }; return [NavigationService]::new($Services) }
#endregion

#region ####Functions from modules\tui-framework\tui-framework.psm1
function Initialize-TuiFrameworkService { [CmdletBinding()] param(); if (-not (Get-Module -Name 'ThreadJob' -ListAvailable)) { Write-Warning "The 'ThreadJob' module is not installed. Asynchronous features will be limited. Please run 'Install-Module ThreadJob'." }; return [TuiFrameworkService]::new() }
#endregion

#region ####Functions from modules\tui-engine\tui-engine.psm1
$global:TuiState = @{ Running = $false; BufferWidth = 0; BufferHeight = 0; CompositorBuffer = $null; PreviousCompositorBuffer = $null; ScreenStack = [System.Collections.Stack]::new(); CurrentScreen = $null; OverlayStack = [System.Collections.Generic.List[UIElement]]::new(); IsDirty = $true; RenderStats = @{ LastFrameTime = 0; FrameCount = 0; TargetFPS = 60; AverageFrameTime = 0 }; Components = @(); Layouts = @{}; FocusedComponent = $null; InputQueue = [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]::new(); InputRunspace = $null; InputPowerShell = $null; InputAsyncResult = $null; CancellationTokenSource = $null; EventHandlers = @{}; LastWindowWidth = 0; LastWindowHeight = 0 }
function Initialize-TuiEngine { [CmdletBinding()] param([int]$Width = [Console]::WindowWidth, [int]$Height = [Console]::WindowHeight - 1); try { Write-Log -Level Info -Message "Initializing TUI Engine with dimensions $Width x $Height"; $global:TuiState.BufferWidth = $Width; $global:TuiState.BufferHeight = $Height; $global:TuiState.LastWindowWidth = [Console]::WindowWidth; $global:TuiState.LastWindowHeight = [Console]::WindowHeight; $global:TuiState.CompositorBuffer = [TuiBuffer]::new($Width, $Height, "CompositorBuffer"); $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($Width, $Height, "PreviousCompositorBuffer"); [Console]::CursorVisible = $false; [Console]::TreatControlCAsInput = $true; Initialize-InputThread; Initialize-PanicHandler; Write-Log -Level Info -Message "TUI Engine initialized successfully" } catch { Write-Error "Failed to initialize TUI Engine: $($_.Exception.Message)"; throw } }
function Initialize-InputThread { [CmdletBinding()] param(); try { Write-Log -Level Debug -Message "Input system initialized (synchronous mode)" } catch { Write-Error "Failed to initialize input system: $($_.Exception.Message)"; throw } }
function Start-TuiLoop { [CmdletBinding()] param([Parameter(Mandatory)][object]$InitialScreen); try { if (-not $global:TuiState.BufferWidth) { Initialize-TuiEngine }; if ($InitialScreen) { Push-Screen -Screen $InitialScreen }; if (-not $global:TuiState.CurrentScreen) { throw "No screen available to start TUI loop" }; $global:TuiState.Running = $true; $frameTimer = [System.Diagnostics.Stopwatch]::new(); $targetFrameTime = 1000.0 / $global:TuiState.RenderStats.TargetFPS; Write-Log -Level Info -Message "Starting TUI main loop"; while ($global:TuiState.Running) { try { $frameTimer.Restart(); Check-ForResize; $hadInput = Process-TuiInput; if ($global:TuiState.IsDirty -or $hadInput) { Render-Frame; $global:TuiState.IsDirty = $false }; $elapsed = $frameTimer.ElapsedMilliseconds; if ($elapsed -lt $targetFrameTime) { $sleepTime = [Math]::Max(1, [int]($targetFrameTime - $elapsed)); Start-Sleep -Milliseconds $sleepTime }; $global:TuiState.RenderStats.LastFrameTime = $frameTimer.ElapsedMilliseconds; $global:TuiState.RenderStats.FrameCount++ } catch { Write-Error "Error in TUI main loop: $($_.Exception.Message)"; Invoke-PanicHandler -ErrorRecord $_ -AdditionalContext @{ Context = "TUI Main Loop" }; $global:TuiState.Running = $false; break } }; Write-Log -Level Info -Message "TUI main loop ended" } catch { Write-Error "Fatal error in TUI loop: $($_.Exception.Message)"; throw } finally { Cleanup-TuiEngine } }
function Check-ForResize { [CmdletBinding()] param(); try { $currentWidth = [Console]::WindowWidth; $currentHeight = [Console]::WindowHeight - 1; if ($currentWidth -ne $global:TuiState.BufferWidth -or $currentHeight -ne $global:TuiState.BufferHeight) { Write-Log -Level Info -Message "Terminal resized from $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight) to $($currentWidth)x$($currentHeight)"; $global:TuiState.BufferWidth = $currentWidth; $global:TuiState.BufferHeight = $currentHeight; $global:TuiState.CompositorBuffer.Resize($currentWidth, $currentHeight); $global:TuiState.PreviousCompositorBuffer.Resize($currentWidth, $currentHeight); if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.Resize($currentWidth, $currentHeight) }; foreach ($overlay in $global:TuiState.OverlayStack) { if ($overlay -is [Dialog]) { $overlay.X = [Math]::Floor(($currentWidth - $overlay.Width) / 2); $overlay.Y = [Math]::Floor(($currentHeight - $overlay.Height) / 4) }; $overlay.Resize($overlay.Width, $overlay.Height) }; Publish-Event -EventName "TUI.Resized" -Data @{ Width = $currentWidth; Height = $currentHeight; PreviousWidth = $global:TuiState.LastWindowWidth; PreviousHeight = $global:TuiState.LastWindowHeight }; $global:TuiState.LastWindowWidth = $currentWidth; $global:TuiState.LastWindowHeight = $currentHeight; Request-TuiRefresh } } catch { Write-Error "Error checking for resize: $($_.Exception.Message)" } }
function Process-TuiInput { [CmdletBinding()] param(); $hadInput = $false; try { while ([Console]::KeyAvailable) { $hadInput = $true; $keyInfo = [Console]::ReadKey($true); if (Handle-GlobalShortcuts -KeyInfo $keyInfo) { continue }; if ($global:TuiState.OverlayStack.Count -gt 0) { if ($global:TuiState.OverlayStack[-1].HandleInput($keyInfo)) { continue } }; if ($global:TuiState.FocusedComponent) { if ($global:TuiState.FocusedComponent.HandleInput($keyInfo)) { continue } }; if ($global:TuiState.CurrentScreen) { if ($global:TuiState.CurrentScreen.HandleInput($keyInfo)) { continue } } } } catch { Write-Error "Error processing input: $($_.Exception.Message)" }; return $hadInput }
function Handle-GlobalShortcuts { [CmdletBinding()] param([Parameter(Mandatory)][System.ConsoleKeyInfo]$KeyInfo); try { if ($KeyInfo.Key -eq [ConsoleKey]::C -and $KeyInfo.Modifiers -band [ConsoleModifiers]::Control) { $global:TuiState.Running = $false; return $true }; if ($KeyInfo.Key -eq [ConsoleKey]::P -and $KeyInfo.Modifiers -band [ConsoleModifiers]::Control) { if (Get-Command Publish-Event -ErrorAction SilentlyContinue) { Publish-Event -EventName "CommandPalette.Open"; return $true } }; if ($KeyInfo.Key -eq [ConsoleKey]::F12) { Show-DebugInfo; return $true }; return $false } catch { Write-Error "Error handling global shortcuts: $($_.Exception.Message)"; return $false } }
function Render-Frame { [CmdletBinding()] param(); try { $global:TuiState.CompositorBuffer.Clear(); if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.Render(); $global:TuiState.CompositorBuffer.BlendBuffer($global:TuiState.CurrentScreen.GetBuffer(), 0, 0) }; foreach ($overlay in $global:TuiState.OverlayStack) { $overlayBuffer = $overlay.GetBuffer(); if ($overlayBuffer) { for ($y = 0; $y -lt $overlay.Height; $y++) { for ($x = 0; $x -lt $overlay.Width; $x++) { $compX = $overlay.X + $x; $compY = $overlay.Y + $y; if ($compX -ge 0 -and $compX -lt $global:TuiState.BufferWidth -and $compY -ge 0 -and $compY -lt $global:TuiState.BufferHeight) { $clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black); $clearCell.ZIndex = 1000; $global:TuiState.CompositorBuffer.SetCell($compX, $compY, $clearCell) } } }; $overlay.Render(); $global:TuiState.CompositorBuffer.BlendBuffer($overlayBuffer, $overlay.X, $overlay.Y) } }; Render-CompositorToConsole; $temp = $global:TuiState.PreviousCompositorBuffer; $global:TuiState.PreviousCompositorBuffer = $global:TuiState.CompositorBuffer; $global:TuiState.CompositorBuffer = $temp } catch { Write-Error "Error rendering frame: $($_.Exception.Message)" } }
function Render-CompositorToConsole { [CmdletBinding()] param(); try { $output = [System.Text.StringBuilder]::new(); for ($y = 0; $y -lt $global:TuiState.BufferHeight; $y++) { for ($x = 0; $x -lt $global:TuiState.BufferWidth; $x++) { $currentCell = $global:TuiState.CompositorBuffer.GetCell($x, $y); $previousCell = $global:TuiState.PreviousCompositorBuffer.GetCell($x, $y); if ($currentCell.DiffersFrom($previousCell)) { [void]$output.Append("`e[" + ($y + 1) + ";" + ($x + 1) + "H"); [void]$output.Append([TuiAnsiHelper]::Reset()); [void]$output.Append([TuiAnsiHelper]::GetForegroundCode($currentCell.ForegroundColor)); [void]$output.Append([TuiAnsiHelper]::GetBackgroundCode($currentCell.BackgroundColor)); if ($currentCell.Bold) { [void]$output.Append([TuiAnsiHelper]::Bold()) }; if ($currentCell.Underline) { [void]$output.Append([TuiAnsiHelper]::Underline()) }; if ($currentCell.Italic) { [void]$output.Append([TuiAnsiHelper]::Italic()) }; [void]$output.Append($currentCell.Char) } } }; if ($output.Length -gt 0) { [void]$output.Append([TuiAnsiHelper]::Reset()); [Console]::Write($output.ToString()) } } catch { Write-Error "Error rendering to console: $($_.Exception.Message)" } }
function Cleanup-TuiEngine { [CmdletBinding()] param(); try { if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.Cleanup() }; while ($global:TuiState.ScreenStack.Count -gt 0) { $global:TuiState.ScreenStack.Pop().Cleanup() }; foreach ($overlay in $global:TuiState.OverlayStack) { $overlay.Cleanup() }; $global:TuiState.OverlayStack.Clear(); [Console]::CursorVisible = $true; [Console]::TreatControlCAsInput = $false; [Console]::Clear() } catch { Write-Error "Error during TUI cleanup: $($_.Exception.Message)" } }
function Push-Screen { [CmdletBinding()] param([Parameter(Mandatory)][object]$Screen); if (-not $Screen) { return }; try { $screenName = $Screen.Name ?? "UnknownScreen"; if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.OnExit(); [void]$global:TuiState.ScreenStack.Push($global:TuiState.CurrentScreen) }; $global:TuiState.CurrentScreen = $Screen; $global:TuiState.FocusedComponent = $null; $Screen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight); if ($Screen.PSObject.Methods['Initialize']) { $Screen.Initialize() }; $Screen.OnEnter(); $Screen.RequestRedraw(); Request-TuiRefresh; Publish-Event -EventName "Screen.Pushed" -Data @{ ScreenName = $screenName } } catch { $errorMsg = $_.Exception.Message ?? "Unknown error"; $screenName = if ($Screen -and $Screen.PSObject.Properties['Name']) { $Screen.Name } else { "UnknownScreen" }; Write-Error "Error pushing screen '$screenName': $errorMsg"; $global:TuiState.Running = $false } }
function Pop-Screen { [CmdletBinding()] param(); if ($global:TuiState.ScreenStack.Count -eq 0) { return $false }; try { if ($global:TuiState.FocusedComponent) { $global:TuiState.FocusedComponent.OnBlur() }; $screenToExit = $global:TuiState.CurrentScreen; $global:TuiState.CurrentScreen = $global:TuiState.ScreenStack.Pop(); $global:TuiState.FocusedComponent = $null; if ($screenToExit) { $screenToExit.OnExit(); if ($screenToExit.PSObject.Methods['Cleanup']) { $screenToExit.Cleanup() } }; if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.OnResume(); if ($global:TuiState.CurrentScreen.LastFocusedComponent) { Set-ComponentFocus -Component $global:TuiState.CurrentScreen.LastFocusedComponent } }; Request-TuiRefresh; Publish-Event -EventName "Screen.Popped" -Data @{ ScreenName = $global:TuiState.CurrentScreen.Name }; return $true } catch { Write-Error "Error popping screen: $($_.Exception.Message)"; return $false } }
function Show-TuiOverlay { [CmdletBinding()] param([Parameter(Mandatory)]$Element); try { if ($Element.PSObject.Methods['Initialize']) { $Element.Initialize() }; $global:TuiState.OverlayStack.Add($Element); Request-TuiRefresh } catch { Write-Error "Error showing overlay '$($Element.Name)': $($_.Exception.Message)" } }
function Close-TopTuiOverlay { [CmdletBinding()] param(); try { if ($global:TuiState.OverlayStack.Count -gt 0) { $overlay = $global:TuiState.OverlayStack[-1]; $global:TuiState.OverlayStack.RemoveAt($global:TuiState.OverlayStack.Count - 1); if ($overlay.PSObject.Methods['Cleanup']) { $overlay.Cleanup() }; Request-TuiRefresh } } catch { Write-Error "Error closing overlay: $($_.Exception.Message)" } }
function Set-ComponentFocus { [CmdletBinding()] param([Parameter(Mandatory)]$Component); try { if (-not $Component.IsFocusable) { return }; if ($global:TuiState.FocusedComponent) { $global:TuiState.FocusedComponent.OnBlur() }; $global:TuiState.FocusedComponent = $Component; $Component.OnFocus(); if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.LastFocusedComponent = $Component }; Request-TuiRefresh } catch { Write-Error "Error setting focus to component '$($Component.Name)': $($_.Exception.Message)" } }
function Get-FocusedComponent { [CmdletBinding()] param(); return $global:TuiState.FocusedComponent }
function Request-TuiRefresh { [CmdletBinding()] param(); $global:TuiState.IsDirty = $true }
function Show-DebugInfo { [CmdletBinding()] param(); try { $debugInfo = "TUI Debug: Running=$($global:TuiState.Running), Size=$($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight), Screen=$($global:TuiState.CurrentScreen?.Name), Focused=$($global:TuiState.FocusedComponent?.Name)"; if (Get-Command Show-AlertDialog -ErrorAction SilentlyContinue) { Show-AlertDialog -Title "Debug Information" -Message $debugInfo } } catch { Write-Error "Error showing debug info: $($_.Exception.Message)" } }
#endregion

# ==============================================================================
# --- STAGE 3: MAIN EXECUTION LOGIC ---
# This is the primary entry point of the application, executed after all
# classes and functions have been defined.
# ==============================================================================

$container = $null 
try {
    Write-Host "`n=== Axiom-Phoenix v5.0 - Starting Up ===" -ForegroundColor Cyan
    
    # 1. Initialize standalone services
    Initialize-Logger -Level $(if ($Debug) { "Debug" } else { "Info" })
    Initialize-EventSystem
    Initialize-ThemeManager
    
    # 2. Create and configure the service container
    $container = Initialize-ServiceContainer
    $container.RegisterFactory("ActionService", { param($c) Initialize-ActionService }, $true)
    $container.RegisterFactory("KeybindingService", { param($c) New-KeybindingService }, $true)
    $container.RegisterFactory("DataManager", { param($c) Initialize-DataManager }, $true)
    $container.RegisterFactory("NavigationService", { param($c) Initialize-NavigationService -Services @{ ServiceContainer = $c } }, $true)
    $container.RegisterFactory("TuiFramework", { param($c) Initialize-TuiFrameworkService }, $true)
    
    # 3. Register screen classes with the Navigation Service
    $navService = $container.GetService("NavigationService")
    $navService.RegisterScreenClass("DashboardScreen", [DashboardScreen])
    $navService.RegisterScreenClass("TaskListScreen", [TaskListScreen])
    
    # 4. Initialize the Command Palette system
    Register-CommandPalette -ActionService $container.GetService("ActionService") -KeybindingService $container.GetService("KeybindingService")
    
    Write-Host "Service container configured!" -ForegroundColor Green
    
    # 5. Initialize and start the TUI Engine
    Write-Host "Starting TUI Engine..." -ForegroundColor Yellow
    Initialize-TuiEngine
    $initialScreen = $navService.ScreenFactory.CreateScreen("DashboardScreen", @{})
    Start-TuiLoop -InitialScreen $initialScreen
    
} catch {
    Write-Host "`n=== FATAL STARTUP ERROR ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    if ($Host.Name -eq 'ConsoleHost' -and $Host.UI.RawUI) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
    exit 1
} finally {
    Write-Host "`nApplication has exited. Cleaning up..."
    if ($container) {
        try {
            $tuiFramework = $container.GetService("TuiFramework")
            if ($tuiFramework) { $tuiFramework.StopAllAsyncJobs() }
            $container.Cleanup()
        } catch {
            Write-Warning "Error during service container cleanup: $($_.Exception.Message)"
        }
    }
    try {
        Cleanup-TuiEngine
    } catch {
        Write-Warning "Error during TUI engine cleanup: $($_.Exception.Message)"
    }
}