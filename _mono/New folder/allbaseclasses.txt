# ==============================================================================
# Axiom-Phoenix v4.0 - Base Classes (Load First)
# Core framework classes with NO external dependencies
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ABC.###" to find specific sections.
# Each section ends with "END_PAGE: ABC.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Management.Automation
using namespace System.Threading

# Disable verbose output during TUI rendering
$script:TuiVerbosePreference = 'SilentlyContinue'

#<!-- PAGE: ABC.001 - TuiAnsiHelper Class -->
#region TuiAnsiHelper - ANSI Code Generation with Truecolor Support

# ==============================================================================
# CLASS: TuiAnsiHelper
#
# INHERITS:
#   - None (Static Class)
#
# DEPENDENCIES:
#   - None from within the framework.
#
# PURPOSE:
#   A static utility class for generating ANSI escape codes. It specializes in
#   creating "truecolor" (24-bit) escape sequences from hex color strings,
#   which is essential for the framework's rich color support.
#
# KEY LOGIC:
#   - HexToRgb(): Parses a "#RRGGBB" hex string into its R, G, and B components.
#   - GetAnsiSequence(): Constructs the final ANSI escape code string by
#     combining foreground color, background color, and text attributes (bold,
#     italic, etc.) into a single sequence.
# ==============================================================================
class TuiAnsiHelper {
    static [hashtable] HexToRgb([string]$hexColor) {
        if ([string]::IsNullOrEmpty($hexColor) -or -not $hexColor.StartsWith("#") -or $hexColor.Length -ne 7) {
            # Cannot use Write-Log here as this file is loaded before AllFunctions.ps1
            return $null
        }
        try {
            return @{
                R = [System.Convert]::ToInt32($hexColor.Substring(1, 2), 16)
                G = [System.Convert]::ToInt32($hexColor.Substring(3, 2), 16)
                B = [System.Convert]::ToInt32($hexColor.Substring(5, 2), 16)
            }
        } catch {
            return $null
        }
    }

    static [string] GetAnsiSequence([string]$fgHex, [string]$bgHex, [hashtable]$attributes) {
        $sequences = [System.Collections.Generic.List[string]]::new()

        if (-not [string]::IsNullOrEmpty($fgHex)) {
            $rgb = [TuiAnsiHelper]::HexToRgb($fgHex)
            if ($rgb) { $sequences.Add("38;2;$($rgb.R);$($rgb.G);$($rgb.B)") }
        }

        if (-not [string]::IsNullOrEmpty($bgHex)) {
            $rgb = [TuiAnsiHelper]::HexToRgb($bgHex)
            if ($rgb) { $sequences.Add("48;2;$($rgb.R);$($rgb.G);$($rgb.B)") }
        }

        if ($attributes) {
            if ($attributes.Bold) { $sequences.Add("1") }
            if ($attributes.Italic) { $sequences.Add("3") }
            if ($attributes.Underline) { $sequences.Add("4") }
            if ($attributes.Strikethrough) { $sequences.Add("9") }
        }

        if ($sequences.Count -eq 0) { return "" }
        return "`e[$($sequences -join ';')m"
    }

    static [string] Reset() { return "`e[0m" }
}
#endregion
#<!-- END_PAGE: ABC.001 -->

#<!-- PAGE: ABC.002 - TuiCell Class -->
#region TuiCell Class - Core Compositor Unit with Truecolor Support

# ==============================================================================
# CLASS: TuiCell
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   Classes:
#     - TuiAnsiHelper (ABC.001)
#
# PURPOSE:
#   Represents a single character cell in the terminal grid. It encapsulates not
#   just the character, but its complete styling information: foreground color,
#   background color, attributes (bold, etc.), and Z-Index for layering.
#   This is the fundamental unit of rendering.
#
# KEY LOGIC:
#   - Stores colors as hex strings for truecolor support.
#   - `ToAnsiString()`: Uses `TuiAnsiHelper` to convert its properties into a
#     drawable string for the terminal.
#   - `DiffersFrom()`: An efficient method for comparing two cells, which is the
#     core of the differential rendering engine.
#   - `BlendWith()`: Defines how this cell is replaced by a cell from a layer
#     above it, respecting the Z-Index.
# ==============================================================================
class TuiCell {
    [char] $Char = ' '
    [string] $ForegroundColor = "#FFFFFF"
    [string] $BackgroundColor = "#000000"
    [bool] $Bold = $false
    [bool] $Underline = $false
    [bool] $Italic = $false
    [bool] $Strikethrough = $false
    [int] $ZIndex = 0        
    [object] $Metadata = $null 

    TuiCell() { }
    TuiCell([char]$char) { $this.Char = $char }
    TuiCell([char]$char, [string]$fg, [string]$bg) {
        $this.Char = $char; $this.ForegroundColor = $fg; $this.BackgroundColor = $bg
    }
    TuiCell([char]$char, [string]$fg, [string]$bg, [bool]$bold, [bool]$italic, [bool]$underline, [bool]$strikethrough) {
        $this.Char = $char; $this.ForegroundColor = $fg; $this.BackgroundColor = $bg;
        $this.Bold = $bold; $this.Italic = $italic; $this.Underline = $underline; $this.Strikethrough = $strikethrough
    }
    TuiCell([object]$other) {
        $this.Char = $other.Char; $this.ForegroundColor = $other.ForegroundColor; $this.BackgroundColor = $other.BackgroundColor
        $this.Bold = $other.Bold; $this.Underline = $other.Underline; $this.Italic = $other.Italic; $this.Strikethrough = $other.Strikethrough
        $this.ZIndex = $other.ZIndex; $this.Metadata = $other.Metadata
    }

    [TuiCell] BlendWith([object]$other) {
        if ($null -eq $other) { return $this }
        if ($other.ZIndex -gt $this.ZIndex) { return [TuiCell]::new($other) }
        if ($other.ZIndex -lt $this.ZIndex) { return $this }
        return [TuiCell]::new($other)
    }

    [bool] DiffersFrom([object]$other) {
        if ($null -eq $other) { return $true }
        return ($this.Char -ne $other.Char -or $this.ForegroundColor -ne $other.ForegroundColor -or $this.BackgroundColor -ne $other.BackgroundColor -or
                $this.Bold -ne $other.Bold -or $this.Underline -ne $other.Underline -or $this.Italic -ne $other.Italic -or
                $this.Strikethrough -ne $other.Strikethrough -or $this.ZIndex -ne $other.ZIndex)
    }

    [string] ToAnsiString() {
        $attributes = @{ Bold=$this.Bold; Italic=$this.Italic; Underline=$this.Underline; Strikethrough=$this.Strikethrough }
        return "$([TuiAnsiHelper]::GetAnsiSequence($this.ForegroundColor, $this.BackgroundColor, $attributes))$($this.Char)"
    }
}
#endregion
#<!-- END_PAGE: ABC.002 -->

#<!-- PAGE: ABC.003 - TuiBuffer Class -->
#region TuiBuffer Class - 2D Array of TuiCells

# ==============================================================================
# CLASS: TuiBuffer
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   Classes:
#     - TuiCell (ABC.002)
#
# PURPOSE:
#   A 2D grid of `TuiCell` objects that represents a rectangular area of the
#   terminal. It serves as an in-memory canvas for all UI components to draw
#   onto before being rendered to the screen.
#
# KEY LOGIC:
#   - `Cells`: The core `object[,]` array holding the TuiCell instances.
#   - Drawing Primitives: Provides methods like `SetCell`, `WriteString`, and
#     `FillRect` that allow components to draw content.
#   - `BlendBuffer`: The key compositing method. It overlays another buffer onto
#     this one, respecting the Z-Index of each cell to correctly layer content.
#   - `Resize`: Re-creates the cell grid with new dimensions, copying over the
#     old content.
# ==============================================================================
class TuiBuffer {
    $Cells
    [int] $Width             
    [int] $Height            
    [string] $Name            
    [bool] $IsDirty = $true  

    TuiBuffer([int]$width, [int]$height, [string]$name = "Unnamed") {
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        $this.Width = $width
        $this.Height = $height
        $this.Name = $name
        $this.InitializeCells()
    }

    hidden [void] InitializeCells() {
        $tempArray = New-Object 'System.Object[,]' $this.Height,$this.Width
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $tempArray[$y,$x] = [TuiCell]::new()
            }
        }
        $this.Cells = $tempArray
    }

    [void] Clear([TuiCell]$fillCell = ([TuiCell]::new())) {
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.Cells[$y, $x] = [TuiCell]::new($fillCell) 
            }
        }
        $this.IsDirty = $true
    }

    [TuiCell] GetCell([int]$x, [int]$y) {
        if ($x -lt 0 -or $x -ge $this.Width -or $y -lt 0 -or $y -ge $this.Height) { return $null }
        return $this.Cells[$y, $x]
    }

    [void] SetCell([int]$x, [int]$y, [TuiCell]$cell) {
        if ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height) {
            $this.Cells[$y, $x] = $cell
            $this.IsDirty = $true
        }
    }

    [void] WriteString([int]$x, [int]$y, [string]$text, [hashtable]$style = @{}) {
        if ([string]::IsNullOrEmpty($text) -or $y -lt 0 -or $y -ge $this.Height) { return }
        
        $fg = $style.FG ?? "#FFFFFF"
        $bg = $style.BG ?? "#000000"
        $bold = [bool]($style.Bold ?? $false)
        $italic = [bool]($style.Italic ?? $false)
        $underline = [bool]($style.Underline ?? $false)
        $strikethrough = [bool]($style.Strikethrough ?? $false)
        $zIndex = [int]($style.ZIndex ?? 0)

        $currentX = $x
        foreach ($char in $text.ToCharArray()) {
            if ($currentX -ge $this.Width) { break } 
            if ($currentX -ge 0) {
                $cell = [TuiCell]::new($char, $fg, $bg, $bold, $italic, $underline, $strikethrough)
                $cell.ZIndex = $zIndex
                $this.SetCell($currentX, $y, $cell)
            }
            $currentX++
        }
    }

    [void] BlendBuffer([object]$other, [int]$offsetX, [int]$offsetY) {
        for ($y = 0; $y -lt $other.Height; $y++) {
            $targetY = $offsetY + $y
            if ($targetY -ge 0 -and $targetY -lt $this.Height) {
                for ($x = 0; $x -lt $other.Width; $x++) {
                    $targetX = $offsetX + $x
                    if ($targetX -ge 0 -and $targetX -lt $this.Width) {
                        $sourceCell = $other.GetCell($x, $y)
                        if ($sourceCell) {
                           $targetCell = $this.GetCell($targetX, $targetY)
                           $this.SetCell($targetX, $targetY, $targetCell.BlendWith($sourceCell))
                        }
                    }
                }
            }
        }
        $this.IsDirty = $true
    }

    [TuiBuffer] GetSubBuffer([int]$x, [int]$y, [int]$width, [int]$height) {
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height") }
        $subBuffer = [TuiBuffer]::new($width, $height, "$($this.Name).Sub")
        for ($sy = 0; $sy -lt $height; $sy++) {
            for ($sx = 0; $sx -lt $width; $sx++) {
                $sourceCell = $this.GetCell($x + $sx, $y + $sy)
                if ($sourceCell) { $subBuffer.SetCell($sx, $sy, [TuiCell]::new($sourceCell)) }
            }
        }
        return $subBuffer
    }

    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0) { throw [System.ArgumentOutOfRangeException]::new("newWidth") }
        if ($newHeight -le 0) { throw [System.ArgumentOutOfRangeException]::new("newHeight") }
        $oldCells = $this.Cells
        $oldWidth = $this.Width
        $oldHeight = $this.Height
        $this.Width = $newWidth
        $this.Height = $newHeight
        $this.InitializeCells()
        $copyWidth = [Math]::Min($oldWidth, $newWidth)
        $copyHeight = [Math]::Min($oldHeight, $newHeight)
        for ($y = 0; $y -lt $copyHeight; $y++) {
            for ($x = 0; $x -lt $copyWidth; $x++) {
                $this.Cells[$y, $x] = $oldCells[$y, $x]
            }
        }
        $this.IsDirty = $true
    }
    
    [void] FillRect([int]$x, [int]$y, [int]$width, [int]$height, [char]$char, [hashtable]$style = @{}) {
        $charString = [string]$char
        for ($py = $y; $py -lt $y + $height; $py++) {
            $this.WriteString($x, $py, $charString * $width, $style)
        }
    }
    
    [TuiBuffer] Clone() {
        $clone = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name)_Clone")
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $clone.Cells[$y, $x] = [TuiCell]::new($this.Cells[$y, $x])
            }
        }
        return $clone
    }
}
#endregion
#<!-- END_PAGE: ABC.003 -->

#<!-- PAGE: ABC.004 - UIElement Class -->
#region UIElement - Base Class for all UI Components

# ==============================================================================
# CLASS: UIElement
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   Classes:
#     - TuiBuffer (ABC.003)
#
# PURPOSE:
#   The abstract base class for ALL visual and interactive components in the
#   framework. It defines the common contract for position, size, visibility,
#   parent-child relationships, input handling, and the rendering lifecycle.
#
# KEY LOGIC:
#   - Defines core properties like X, Y, Width, Height, Parent, and Children.
#   - `_private_buffer`: Each element has its own TuiBuffer to draw on.
#   - `Render()` and `_RenderContent()`: The heart of the rendering pipeline.
#     `Render()` is the public entry point, while the virtual `_RenderContent()`
#     manages the on-demand rendering of the element itself and its children,
#     blending their buffers together.
#   - `HandleInput()`: A virtual method for components to implement their own
#     response to keyboard input.
#   - `RequestRedraw()`: A critical method that flags a component and its entire
#     parent hierarchy as "dirty", ensuring it gets redrawn on the next frame.
# ==============================================================================
class UIElement {
    [string] $Name = "UIElement" 
    [int] $X = 0; [int] $Y = 0; [int] $Width = 1; [int] $Height = 1
    [bool] $Visible = $true; [bool] $Enabled = $true
    [bool] $IsFocusable = $false; [bool] $IsFocused = $false
    [bool] $IsOverlay = $false
    [int] $TabIndex = 0; [int] $ZIndex = 0
    [UIElement] $Parent = $null 
    [System.Collections.Generic.List[UIElement]] $Children 
    
    hidden [TuiBuffer] $_private_buffer
    hidden [bool] $_needs_redraw = $true
    [hashtable] $Metadata = @{} 

    UIElement([string]$name = "UIElement") {
        $this.Name = $name
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        if ($this.Width -gt 0 -and $this.Height -gt 0) {
            $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        }
    }

    [hashtable] GetAbsolutePosition() {
        $absX = $this.X; $absY = $this.Y; $current = $this.Parent
        while ($current) { $absX += $current.X; $absY += $current.Y; $current = $current.Parent }
        return @{ X = $absX; Y = $absY }
    }

    [void] AddChild([UIElement]$child) {
        if ($child.Parent) { $child.Parent.RemoveChild($child) }
        $child.Parent = $this
        $this.Children.Add($child)
        if ($child.PSObject.Methods['AddedToParent']) { $child.AddedToParent() }
        $this.RequestRedraw()
    }

    [void] RemoveChild([UIElement]$child) {
        if ($this.Children.Remove($child)) {
            $child.Parent = $null
            if ($child.PSObject.Methods['RemovedFromParent']) { $child.RemovedFromParent() }
            $this.RequestRedraw()
        }
    }

    [void] RequestRedraw() {
        $this._needs_redraw = $true
        $this.Parent?.RequestRedraw()
    }

    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0) { return }
        if ($newHeight -le 0) { return }
        if ($this.Width -eq $newWidth -and $this.Height -eq $newHeight) { return }
        
        $this.Width = $newWidth
        $this.Height = $newHeight
        if ($this._private_buffer) { $this._private_buffer.Resize($newWidth, $newHeight) }
        else { $this._private_buffer = [TuiBuffer]::new($newWidth, $newHeight, "$($this.Name).Buffer") }
        
        $this.OnResize($newWidth, $newHeight)
        $this.RequestRedraw()
    }

    # --- VIRTUAL METHODS ---
    [void] OnRender() { if ($this._private_buffer) { $this._private_buffer.Clear() } }
    [void] OnResize([int]$newWidth, [int]$newHeight) { }
    [void] OnFocus() { }
    [void] OnBlur() { }
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) { return $false }

    [void] Cleanup() {
        foreach ($child in $this.Children) { $child.Cleanup() }
        $this.Children.Clear(); $this.Parent = $null; $this._private_buffer = $null
    }

    [void] Render() { if ($this.Visible) { $this._RenderContent() } }

    hidden [void] _RenderContent() {
        if (-not $this.Visible) { return }

        $parentDidRedraw = $this._needs_redraw
        if ($parentDidRedraw) {
            # Re-initialize buffer if dimensions are wrong
            if (($null -eq $this._private_buffer) -or $this._private_buffer.Width -ne $this.Width -or $this._private_buffer.Height -ne $this.Height) {
                $this._private_buffer = [TuiBuffer]::new([Math]::Max(1, $this.Width), [Math]::Max(1, $this.Height), "$($this.Name).Buffer")
            }
            $this.OnRender()
        }

        foreach ($child in $this.Children | Sort-Object ZIndex) { 
            if ($child.Visible) {
                $child.Render()
                if (($parentDidRedraw -or $child._needs_redraw) -and $child._private_buffer) {
                    $this._private_buffer.BlendBuffer($child._private_buffer, $child.X, $child.Y)
                }
            }
        }
        $this._needs_redraw = $false
    }
    
    [TuiBuffer] GetBuffer() { return $this._private_buffer }
}
#endregion
#<!-- END_PAGE: ABC.004 -->

#<!-- PAGE: ABC.005 - Component Class -->
#region Component - A generic container component

# ==============================================================================
# CLASS: Component
#
# INHERITS:
#   - UIElement (ABC.004)
#
# DEPENDENCIES:
#   - None
#
# PURPOSE:
#   A generic, empty container component that inherits from UIElement. It serves
#   as a basic building block or placeholder for composing UIs where a simple
#   grouping container is needed without the extra features of a `Panel`.
# ==============================================================================
class Component : UIElement {
    Component([string]$name) : base($name) { }
}
#endregion
#<!-- END_PAGE: ABC.005 -->

#<!-- PAGE: ABC.006 - Screen Class -->
#region Screen - Top-level Container for Application Views

# ==============================================================================
# CLASS: Screen
#
# INHERITS:
#   - UIElement (ABC.004)
#
# DEPENDENCIES:
#   Services:
#     - ServiceContainer (ABC.007)
#
# PURPOSE:
#   Represents a top-level application view, like a "Dashboard" or "Settings"
#   page. It's a specialized `UIElement` that fills the entire terminal window
#   and has direct access to the application's service container.
#
# KEY LOGIC:
#   - Its constructor accepts the main `ServiceContainer`, giving it and its
#     children access to all application services.
#   - Defines a screen-specific lifecycle (`Initialize`, `OnEnter`, `OnExit`,
#     `OnResume`) that is called by the `NavigationService`.
#   - `Cleanup` is responsible for unsubscribing from any events it subscribed
#     to during its lifetime, preventing memory leaks.
# ==============================================================================
class Screen : UIElement {
    [object]$ServiceContainer 
    [hashtable]$Services
    [System.Collections.Generic.Dictionary[string, string]] $EventSubscriptions 
    hidden [bool] $_isInitialized = $false
    
    Screen([string]$name, [object]$serviceContainer) : base($name) {
        $this.ServiceContainer = $serviceContainer
        $this.Services = [hashtable]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        if ($this.ServiceContainer) {
            $allServices = $this.ServiceContainer.GetAllRegisteredServices()
            foreach ($serviceInfo in $allServices) {
                $this.Services[$serviceInfo.Name] = $this.ServiceContainer.GetService($serviceInfo.Name)
            }
        }
    }

    # --- VIRTUAL METHODS for screen lifecycle ---
    [void] Initialize() { }
    [void] OnEnter() { }
    [void] OnExit() { }
    [void] OnResume() { }

    [void] Cleanup() {
        # Unsubscribe from events registered via SubscribeToEvent
        if (Get-Command 'Unsubscribe-Event' -ErrorAction SilentlyContinue) {
            foreach ($kvp in $this.EventSubscriptions.GetEnumerator()) {
                try { Unsubscribe-Event -EventName $kvp.Key -HandlerId $kvp.Value } catch {}
            }
        }
        $this.EventSubscriptions.Clear()
        
        # Call base UIElement cleanup
        ([UIElement]$this).Cleanup()
    }

    [void] SubscribeToEvent([string]$eventName, [scriptblock]$action) {
        if (Get-Command 'Subscribe-Event' -ErrorAction SilentlyContinue) {
            $subscriptionId = Subscribe-Event -EventName $eventName -Handler $action -Source $this.Name
            $this.EventSubscriptions[$eventName] = $subscriptionId
        }
    }
}
#endregion
#<!-- END_PAGE: ABC.006 -->

#<!-- PAGE: ABC.007 - ServiceContainer Class -->
#region ServiceContainer Class

# ==============================================================================
# CLASS: ServiceContainer
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   - None
#
# PURPOSE:
#   A simple but effective Dependency Injection (DI) container. It is responsible
#   for instantiating, storing, and providing access to all the long-lived
#   service classes (e.g., DataManager, NavigationService) used by the application.
#
# KEY LOGIC:
#   - `Register`: Stores a pre-created instance of a service.
#   - `RegisterFactory`: Stores a scriptblock that can create a service on
#     demand. This allows for lazy-loading and singleton/transient lifestyles.
#   - `GetService`: The main retrieval method. It first checks for an already
#     created instance. If not found, it checks for a factory, invokes it, and
#     if the factory is a singleton, it caches the new instance for future calls.
#   - `_InitializeServiceFromFactory` includes logic to detect circular
#     dependencies during service resolution.
# ==============================================================================
class ServiceContainer {
    hidden [hashtable] $_services = @{}
    hidden [hashtable] $_serviceFactories = @{}

    [void] Register([string]$name, [object]$serviceInstance) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("name") }
        if ($null -eq $serviceInstance) { throw [System.ArgumentNullException]::new("serviceInstance") }
        if ($this._services.ContainsKey($name) -or $this._serviceFactories.ContainsKey($name)) {
            throw [System.InvalidOperationException]::new("A service with the name '$name' is already registered.")
        }
        $this._services[$name] = $serviceInstance
    }

    [void] RegisterFactory([string]$name, [scriptblock]$factory, [bool]$isSingleton = $true) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("name") }
        if ($null -eq $factory) { throw [System.ArgumentNullException]::new("factory") }
        if ($this._services.ContainsKey($name) -or $this._serviceFactories.ContainsKey($name)) {
            throw [System.InvalidOperationException]::new("A service with the name '$name' is already registered.")
        }
        $this._serviceFactories[$name] = @{ Factory = $factory; IsSingleton = $isSingleton; Instance = $null }
    }

    [object] GetService([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("name") }

        if ($this._services.ContainsKey($name)) { return $this._services[$name] }
        if ($this._serviceFactories.ContainsKey($name)) {
            return $this._InitializeServiceFromFactory($name, [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase))
        }

        $available = @($this.GetAllRegisteredServices().Name) -join ', '
        throw [System.InvalidOperationException]::new("Service '$name' not found. Available services: $available")
    }
    
    [object[]] GetAllRegisteredServices() {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($key in $this._services.Keys) { $list.Add(@{ Name = $key; Type = 'Instance'; Initialized = $true; Lifestyle = 'Singleton' }) }
        foreach ($key in $this._serviceFactories.Keys) {
            $factoryInfo = $this._serviceFactories[$key]
            $list.Add(@{ Name = $key; Type = 'Factory'; Initialized = ($null -ne $factoryInfo.Instance); Lifestyle = if ($factoryInfo.IsSingleton) { 'Singleton' } else { 'Transient' } })
        }
        return $list.ToArray() | Sort-Object Name
    }

    [void] Cleanup() {
        $instancesToClean = [System.Collections.Generic.List[object]]::new()
        $instancesToClean.AddRange($this._services.Values)
        $this._serviceFactories.Values | Where-Object { $_.IsSingleton -and $_.Instance } | ForEach-Object { $instancesToClean.Add($_.Instance) }

        foreach ($service in $instancesToClean) {
            if ($service -is [System.IDisposable]) { try { $service.Dispose() } catch { } }
        }
        
        $this._services.Clear(); $this._serviceFactories.Clear()
    }

    hidden [object] _InitializeServiceFromFactory([string]$name, [System.Collections.Generic.HashSet[string]]$resolutionChain) {
        $factoryInfo = $this._serviceFactories[$name]
        if ($factoryInfo.IsSingleton -and $factoryInfo.Instance) { return $factoryInfo.Instance }
        if ($resolutionChain.Contains($name)) { throw [System.InvalidOperationException]::new("Circular dependency detected while resolving service '$name'.") }
        
        $resolutionChain.Add($name) | Out-Null
        $serviceInstance = & $factoryInfo.Factory $this
        if ($factoryInfo.IsSingleton) { $factoryInfo.Instance = $serviceInstance }
        $resolutionChain.Remove($name) | Out-Null
        
        return $serviceInstance
    }
}
#endregion
#<!-- END_PAGE: ABC.007 -->