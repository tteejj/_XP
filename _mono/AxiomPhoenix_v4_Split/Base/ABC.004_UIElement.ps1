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

#region UIElement - Base Class for all UI Components

# ==============================================================================
# CLASS: UIElement
#
# INHERITS:
#   - None (base class)
#
# DEPENDENCIES:
#   Classes:
#     - TuiBuffer (ABC.003)
#     - TuiCell (ABC.002)
#   Services:
#     - TuiFrameworkService (ASE.010) - for dimension access
#
# PURPOSE:
#   Foundation class for all UI components in the framework. Provides core
#   functionality for positioning, sizing, visibility, focus management,
#   hierarchical parent-child relationships, and the rendering lifecycle.
#
# KEY LOGIC:
#   - OnRender: Override to define component-specific rendering
#   - _RenderContent: Core rendering pipeline with optimization
#   - HandleInput: Process keyboard/mouse input
#   - AddChild/RemoveChild: Manage component hierarchy
#   - RequestRedraw: Mark component as needing redraw
#   - Lifecycle: Initialize → OnRender → HandleInput → Cleanup
# ==============================================================================
class UIElement {
    [string] $Name = "UIElement" 
    [int] $X = 0               
    [int] $Y = 0               
    [int] $Width = 30          
    [int] $Height = 10          
    [bool] $Visible = $true    
    [bool] $Enabled = $true    
    [bool] $IsFocusable = $false 
    [bool] $IsFocused = $false  
    [bool] $IsOverlay = $false
    [int] $TabIndex = 0        
    [int] $ZIndex = 0          
    [UIElement] $Parent = $null 
    [System.Collections.Generic.List[UIElement]] $Children 
    
    # Theme-aware color properties
    [string] $ForegroundColor = "$null"
    [string] $BackgroundColor = "$null"
    [string] $BorderColor = "$null"
    
    hidden [object] $_private_buffer = $null
    hidden [bool] $_needs_redraw = $true
    
    [hashtable] $Metadata = @{} 

    UIElement() {
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        # Write-Verbose "UIElement 'Unnamed' created with default size ($($this.Width)x$($this.Height))."
    }

    UIElement([string]$name) {
        $this.Name = $name
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        # Write-Verbose "UIElement '$($this.Name)' created with default size ($($this.Width)x$($this.Height))."
    }

    UIElement([int]$x, [int]$y, [int]$width, [int]$height) {
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($width, $height, "Unnamed.Buffer")
        # Write-Verbose "UIElement 'Unnamed' created at ($x, $y) with dimensions $($width)x$($height)."
    }

    [hashtable] GetAbsolutePosition() {
        $absX = $this.X
        $absY = $this.Y
        $current = $this.Parent
        while ($null -ne $current) {
            $absX += $current.X
            $absY += $current.Y
            $current = $current.Parent
        }
        return @{ X = $absX; Y = $absY }
    }

    [void] AddChild([object]$child) {
        try {
            if ($child -eq $this) { throw [System.ArgumentException]::new("Cannot add an element as its own child.") }
            if ($this.Children.Contains($child)) {
                Write-Warning "Child '$($child.Name)' is already a child of '$($this.Name)'. Skipping addition."
                return
            }
            if ($child.Parent -ne $null) {
                Write-Warning "Child '$($child.Name)' already has a parent ('$($child.Parent.Name)'). Consider removing it from its current parent first."
            }
            $child.Parent = $this
            $this.Children.Add($child)
            
            # Call the lifecycle hook if the child has it defined
            if ($child.PSObject.Methods['AddedToParent']) {
                try {
                    $child.AddedToParent()
                }
                catch {
                    Write-Warning "Error calling AddedToParent on child '$($child.Name)': $($_.Exception.Message)"
                }
            }
            
            $this.RequestRedraw()
            # Write-Verbose "Added child '$($child.Name)' to parent '$($this.Name)'."
        }
        catch {
            Write-Error "Failed to add child '$($child.Name)' to '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    [void] RemoveChild([object]$child) {
        try {
            if ($this.Children.Remove($child)) {
                $child.Parent = $null
                
                # Call the lifecycle hook if the child has it defined
                if ($child.PSObject.Methods['RemovedFromParent']) {
                    try {
                        $child.RemovedFromParent()
                    }
                    catch {
                        Write-Warning "Error calling RemovedFromParent on child '$($child.Name)': $($_.Exception.Message)"
                    }
                }
                
                $this.RequestRedraw()
                # Write-Verbose "Removed child '$($child.Name)' from parent '$($this.Name)'."
            } else {
                Write-Warning "Child '$($child.Name)' not found in parent '$($this.Name)' for removal. No action taken."
            }
        }
        catch {
            Write-Error "Failed to remove child '$($child.Name)' from '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    [void] RequestRedraw() {
        $this._needs_redraw = $true
        if ($null -ne $this.Parent) {
            $this.Parent.RequestRedraw()
        }
        # Write-Verbose "Redraw requested for '$($this.Name)'."
    }

    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0) { throw [System.ArgumentOutOfRangeException]::new("newWidth", "New width must be positive.") }
        if ($newHeight -le 0) { throw [System.ArgumentOutOfRangeException]::new("newHeight", "New height must be positive.") }
        try {
            if ($this.Width -eq $newWidth -and $this.Height -eq $newHeight) {
                Write-Verbose "Resize: Component '$($this.Name)' already has target dimensions ($($newWidth)x$($newHeight)). No change."
                return
            }
            $this.Width = $newWidth
            $this.Height = $newHeight
            if ($null -ne $this._private_buffer) {
                $this._private_buffer.Resize($newWidth, $newHeight)
            } else {
                $this._private_buffer = [TuiBuffer]::new($newWidth, $newHeight, "$($this.Name).Buffer")
                # Write-Verbose "Re-initialized buffer for '$($this.Name)' due to null buffer."
            }
            $this.RequestRedraw()
            $this.OnResize($newWidth, $newHeight)
            # Write-Verbose "Component '$($this.Name)' resized to $($newWidth)x$($newHeight)."
        }
        catch {
            Write-Error "Failed to resize component '$($this.Name)' to $($newWidth)x$($newHeight): $($_.Exception.Message)"
            throw
        }
    }

    [void] Move([int]$newX, [int]$newY) {
        if ($this.X -eq $newX -and $this.Y -eq $newY) {
            # Write-Verbose "Move: Component '$($this.Name)' already at target position ($($newX), $($newY)). No change."
            return
        }
        $this.X = $newX
        $this.Y = $newY
        $this.RequestRedraw()
        $this.OnMove($newX, $newY)
        # Write-Verbose "Component '$($this.Name)' moved to ($newX, $newY)."
    }

    [bool] ContainsPoint([int]$x, [int]$y) {
        return ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height)
    }

    [object] GetChildAtPoint([int]$x, [int]$y) {
        for ($i = $this.Children.Count - 1; $i -ge 0; $i--) {
            $child = $this.Children[$i]
            if ($child.Visible -and $child.ContainsPoint($x - $child.X, $y - $child.Y)) {
                return $child
            }
        }
        return $null
    }

    [void] OnRender() 
    {
        if ($null -ne $this._private_buffer) {
            $this._private_buffer.Clear()
        }
        # Write-Verbose "OnRender called for '$($this.Name)': Default buffer clear."
    }

    [void] OnResize([int]$newWidth, [int]$newHeight) 
    {
        # Write-Verbose "OnResize called for '$($this.Name)': No custom resize logic."
    }

    [void] OnMove([int]$newX, [int]$newY) 
    {
        # Write-Verbose "OnMove called for '$($this.Name)': No custom move logic."
    }

    # Get theme-aware color with fallback
    [string] GetThemeColor([string]$themePath, [string]$fallback = "#ffffff") {
        if (Get-Command 'Get-ThemeColor' -ErrorAction SilentlyContinue) {
            return Get-ThemeColor $themePath $fallback
        }
        return $fallback
    }
    
    # Get effective foreground color (theme-aware)
    [string] GetEffectiveForegroundColor() {
        if ($this.ForegroundColor -and $this.ForegroundColor -ne '$null') {
            return $this.ForegroundColor
        }
        return $this.GetThemeColor("Label.Foreground", "#d4d4d4")
    }
    
    # Get effective background color (theme-aware)
    [string] GetEffectiveBackgroundColor() {
        if ($this.BackgroundColor -and $this.BackgroundColor -ne '$null') {
            return $this.BackgroundColor
        }
        return $this.GetThemeColor("Panel.Background", "#1e1e1e")
    }
    
    # Get effective border color (theme-aware)
    [string] GetEffectiveBorderColor() {
        if ($this.BorderColor -and $this.BorderColor -ne '$null') {
            return $this.BorderColor
        }
        return $this.GetThemeColor("Panel.Border", "#404040")
    }

    [void] OnFocus() 
    { 
        # Write-Verbose "OnFocus called for '$($this.Name)'." 
    }
    
    [void] OnBlur() 
    { 
        # Write-Verbose "OnBlur called for '$($this.Name)'." 
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) 
    {
        # Write-Verbose "HandleInput called for '$($this.Name)': Key: $($keyInfo.Key)."
        return $false
    }

    [void] Cleanup()
    {
        # Cleanup all children recursively
        foreach ($child in $this.Children) {
            if ($child.PSObject.Methods['Cleanup']) {
                try { 
                    $child.Cleanup() 
                } 
                catch { 
                    Write-Warning "Failed to cleanup child '$($child.Name)': $($_.Exception.Message)" 
                }
            }
        }
        
        # Clear references
        $this.Children.Clear()
        $this.Parent = $null
        $this._private_buffer = $null
        
        # Write-Verbose "Cleanup completed for UIElement '$($this.Name)'."
    }

    [void] Render() 
    {
        if (-not $this.Visible) { 
            # Write-Verbose "Skipping Render for '$($this.Name)': Not visible."
            return 
        }
        $this._RenderContent() 
    }

    hidden [void] _RenderContent() 
    {
        if (-not $this.Visible) { return }
        
        # Phase 1: Render Self (if needed)
        $parentDidRedraw = $false
        if ($this._needs_redraw -or ($null -eq $this._private_buffer) -or 
            ($this._private_buffer.Width -ne $this.Width) -or 
            ($this._private_buffer.Height -ne $this.Height)) {
            
            try {
                # Ensure buffer exists and is correct size
                if ($null -eq $this._private_buffer -or 
                    $this._private_buffer.Width -ne $this.Width -or 
                    $this._private_buffer.Height -ne $this.Height) {
                    
                    $bufferWidth = [Math]::Max(1, $this.Width)
                    $bufferHeight = [Math]::Max(1, $this.Height)
                    $this._private_buffer = [TuiBuffer]::new($bufferWidth, $bufferHeight, "$($this.Name).Buffer")
                    
                    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Debug -Message "UIElement '$($this.Name)': Buffer resized to ${bufferWidth}x${bufferHeight}"
                    }
                }
                
                # Render component content
                $this.OnRender()
                $parentDidRedraw = $true
                
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Debug -Message "UIElement '$($this.Name)': Rendered own content"
                }
            }
            catch {
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Error -Message "UIElement '$($this.Name)': OnRender() failed: $($_.Exception.Message)"
                }
                throw
            }
        }
        
        # Phase 2: Render and Blend Children (with optimization)
        foreach ($child in $this.Children | Sort-Object ZIndex) {
            if ($child.Visible) {
                try {
                    # Always recurse to allow children to render if they need to
                    $child._RenderContent()
                    
                    # OPTIMIZATION: Only blend if parent redrew OR child redrew
                    $childNeedsBlending = $parentDidRedraw -or $child._needs_redraw
                    
                    if ($childNeedsBlending -and $null -ne $child._private_buffer) {
                        # Bounds checking for child position
                        if ($child.X -lt $this.Width -and $child.Y -lt $this.Height -and 
                            $child.X + $child.Width -gt 0 -and $child.Y + $child.Height -gt 0) {
                            
                            $this._private_buffer.BlendBuffer($child._private_buffer, $child.X, $child.Y)
                            
                            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                                Write-Log -Level Debug -Message "UIElement '$($this.Name)': Blended child '$($child.Name)' at ($($child.X), $($child.Y))"
                            }
                        }
                        else {
                            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                                Write-Log -Level Debug -Message "UIElement '$($this.Name)': Child '$($child.Name)' is out of bounds, skipping blend"
                            }
                        }
                    }
                }
                catch {
                    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Error -Message "UIElement '$($this.Name)': Error rendering child '$($child.Name)': $($_.Exception.Message)"
                    }
                    # Continue with other children even if one fails
                }
            }
        }
        
        # Phase 3: Reset redraw flag for next frame
        $this._needs_redraw = $false
    }

    [object] GetBuffer() 
    { 
        return $this._private_buffer 
    }
    
    [string] ToString() 
    {
        return "$($this.GetType().Name)(Name='$($this.Name)', X=$($this.X), Y=$($this.Y), Width=$($this.Width), Height=$($this.Height), Visible=$($this.Visible))"
    }
}
#endregion
#<!-- END_PAGE: ABC.004 -->
