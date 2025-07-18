####\Base\ABC.004_UIElement.ps1
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
    hidden [int] $_zIndex = 0
    [UIElement] $Parent = $null 
    [System.Collections.Generic.List[UIElement]] $Children 
    
    # Theme-aware color properties
    [string] $ForegroundColor = $null
    [string] $BackgroundColor = $null
    [string] $BorderColor = $null
    
    hidden [object] $_private_buffer = $null
    hidden [bool] $_needs_redraw = $true
    
    # Theme color caching properties
    hidden [hashtable] $_themeColorCache = @{}
    hidden [string] $_lastThemeName = ""
    
    # PERFORMANCE: Pre-resolved theme colors at initialization
    hidden [hashtable] $_preResolvedThemeColors = @{}
    hidden [string[]] $_requiredThemeColors = @()
    
    # DEPENDENCY INJECTION: Injected services (replaces service locator anti-pattern)
    hidden [hashtable] $_injectedServices = @{}
    
    # PERFORMANCE: Cached sorted children list
    hidden [System.Collections.Generic.List[UIElement]] $_sortedChildren = $null
    hidden [bool] $_sortedChildrenValid = $false
    
    # PERFORMANCE: Render caching properties
    hidden [string] $_lastRenderHash = ""
    hidden [bool] $_renderCacheValid = $false
    hidden [hashtable] $_renderState = @{}
    
    [hashtable] $Metadata = @{} 

    # PERFORMANCE: Property getter for sorted children
    hidden [System.Collections.Generic.List[UIElement]] GetSortedChildren() {
        if (-not $this._sortedChildrenValid) {
            $this._sortedChildren.Clear()
            foreach ($child in ($this.Children | Sort-Object ZIndex)) {
                $this._sortedChildren.Add($child)
            }
            $this._sortedChildrenValid = $true
        }
        return $this._sortedChildren
    }
    
    # PERFORMANCE: Method to invalidate sorted children cache when ZIndex changes
    [void] InvalidateSortedChildren() {
        $this._sortedChildrenValid = $false
        # Also invalidate parent's cache if we have one
        if ($this.Parent) {
            $this.Parent.InvalidateSortedChildren()
        }
    }
    
    # PERFORMANCE: ZIndex property with cache invalidation
    [int] GetZIndex() {
        return $this._zIndex
    }
    
    [void] SetZIndex([int]$value) {
        if ($this._zIndex -ne $value) {
            $this._zIndex = $value
            # Invalidate parent's sorted children cache
            if ($this.Parent) {
                $this.Parent.InvalidateSortedChildren()
            }
        }
    }
    
    # PERFORMANCE: Calculate hash of render-affecting properties
    hidden [string] GetRenderHash() {
        $hashComponents = @(
            $this.X, $this.Y, $this.Width, $this.Height
            $this.Visible, $this.Enabled, $this.IsFocused
            $this.ForegroundColor, $this.BackgroundColor, $this.BorderColor
            $this._zIndex
        )
        
        # Add component-specific properties if they exist
        if ($this.PSObject.Properties['Text']) { $hashComponents += $this.Text }
        if ($this.PSObject.Properties['Value']) { $hashComponents += $this.Value }
        if ($this.PSObject.Properties['Items']) { $hashComponents += @($this.Items).Count }
        if ($this.PSObject.Properties['SelectedIndex']) { $hashComponents += $this.SelectedIndex }
        
        # Include children hash
        $childrenHash = ($this.Children | ForEach-Object { "$($_.Name):$($_._lastRenderHash)" }) -join "|"
        $hashComponents += $childrenHash
        
        return ($hashComponents -join "|").GetHashCode().ToString()
    }
    
    # PERFORMANCE: Check if render is needed
    hidden [bool] NeedsRender() {
        if (-not $this._renderCacheValid -or $this._needs_redraw) {
            return $true
        }
        
        $currentHash = $this.GetRenderHash()
        if ($currentHash -ne $this._lastRenderHash) {
            $this._lastRenderHash = $currentHash
            return $true
        }
        
        return $false
    }
    
    # PERFORMANCE: Invalidate render cache
    [void] InvalidateRenderCache() {
        $this._renderCacheValid = $false
        $this._needs_redraw = $true
        
        # Invalidate parent cache too
        if ($this.Parent) {
            $this.Parent.InvalidateRenderCache()
        }
    }
    
    # PERFORMANCE: Add ZIndex property with cache invalidation
    hidden [void] _InitializeZIndexProperty() {
        $this | Add-Member -MemberType ScriptProperty -Name "ZIndex" -Value {
            return $this._zIndex
        } -SecondValue {
            param($value)
            if ($this._zIndex -ne $value) {
                $this._zIndex = $value
                if ($this.Parent) {
                    $this.Parent.InvalidateSortedChildren()
                }
            }
        } -Force
    }

    UIElement() {
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._sortedChildren = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        $this._InitializeZIndexProperty()
        # Write-Verbose "UIElement 'Unnamed' created with default size ($($this.Width)x$($this.Height))."
    }

    UIElement([string]$name) {
        $this.Name = $name
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._sortedChildren = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        $this._InitializeZIndexProperty()
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
        $this._sortedChildren = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($width, $height, "Unnamed.Buffer")
        $this._InitializeZIndexProperty()
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
            
            # PERFORMANCE: Invalidate sorted children cache
            $this._sortedChildrenValid = $false
            
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
                
                # PERFORMANCE: Invalidate sorted children cache
                $this._sortedChildrenValid = $false
                
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

    # Get theme-aware color with fallback and caching
    [string] GetThemeColor([string]$themePath, [string]$fallback = "#ffffff") {
        # Get current theme name for cache validation
        $currentTheme = $global:TuiState?.Services?.ThemeManager?.ThemeName
        if (-not $currentTheme) {
            $currentTheme = "default"
        }
        
        # Invalidate cache if theme changed
        if ($this._lastThemeName -ne $currentTheme) {
            $this._themeColorCache = @{}
            $this._lastThemeName = $currentTheme
        }
        
        # Check cache first
        if ($this._themeColorCache.ContainsKey($themePath)) {
            return $this._themeColorCache[$themePath]
        }
        
        # Resolve color and cache it
        $resolvedColor = $fallback
        
        # First try using the global Get-ThemeColor function if available
        if (Get-Command 'Get-ThemeColor' -ErrorAction SilentlyContinue) {
            $resolvedColor = Get-ThemeColor $themePath $fallback
        }
        else {
            # Fallback to direct theme manager access
            $themeManager = $global:TuiState?.Services?.ThemeManager
            if (-not $themeManager) {
                $themeManager = $global:TuiState?.ServiceContainer?.GetService("ThemeManager")
            }
            
            if ($themeManager) {
                $resolvedColor = $themeManager.GetColor($themePath, $fallback)
            }
        }
        
        # Cache the resolved color
        $this._themeColorCache[$themePath] = $resolvedColor
        return $resolvedColor
    }
    
    # Get effective foreground color (theme-aware)
    [string] GetEffectiveForegroundColor() {
        if ($this.ForegroundColor) {
            return $this.ForegroundColor
        }
        return $this.GetThemeColor("Label.Foreground", "#d4d4d4")
    }
    
    # Get effective background color (theme-aware)
    [string] GetEffectiveBackgroundColor() {
        if ($this.BackgroundColor) {
            return $this.BackgroundColor
        }
        return $this.GetThemeColor("Panel.Background", "#1e1e1e")
    }
    
    # Get effective border color (theme-aware)
    [string] GetEffectiveBorderColor() {
        if ($this.BorderColor) {
            return $this.BorderColor
        }
        return $this.GetThemeColor("Panel.Border", "#404040")
    }
    
    # PERFORMANCE: Define theme colors that this component needs (call in constructor)
    [void] DefineThemeColors([string[]]$themeColorKeys) {
        $this._requiredThemeColors = $themeColorKeys
        $this.ResolveThemeColors()
    }
    
    # PERFORMANCE: Pre-resolve all required theme colors for this component
    [void] ResolveThemeColors() {
        # Get current theme name for cache validation
        $currentTheme = $global:TuiState?.Services?.ThemeManager?.ThemeName
        if (-not $currentTheme) {
            $currentTheme = "default"
        }
        
        # Clear cache if theme changed
        if ($this._lastThemeName -ne $currentTheme) {
            $this._preResolvedThemeColors = @{}
            $this._lastThemeName = $currentTheme
        }
        
        # Resolve each required theme color
        foreach ($themeKey in $this._requiredThemeColors) {
            if (-not $this._preResolvedThemeColors.ContainsKey($themeKey)) {
                # Extract fallback from key if it contains a pipe separator
                $fallback = "#ffffff"
                $actualKey = $themeKey
                
                if ($themeKey.Contains('|')) {
                    $parts = $themeKey -split '\|', 2
                    $actualKey = $parts[0]
                    $fallback = $parts[1]
                }
                
                # Resolve the color using existing GetThemeColor logic
                $resolvedColor = $fallback
                
                # First try using the global Get-ThemeColor function if available
                if (Get-Command 'Get-ThemeColor' -ErrorAction SilentlyContinue) {
                    $resolvedColor = Get-ThemeColor $actualKey $fallback
                }
                else {
                    # Fallback to direct theme manager access
                    $themeManager = $global:TuiState?.Services?.ThemeManager
                    if (-not $themeManager) {
                        $themeManager = $global:TuiState?.ServiceContainer?.GetService("ThemeManager")
                    }
                    
                    if ($themeManager) {
                        $resolvedColor = $themeManager.GetColor($actualKey, $fallback)
                    }
                }
                
                # Cache the resolved color
                $this._preResolvedThemeColors[$themeKey] = $resolvedColor
            }
        }
    }
    
    # PERFORMANCE: Get pre-resolved theme color (much faster than GetThemeColor during render)
    [string] GetPreResolvedThemeColor([string]$themeKey, [string]$fallback = "#ffffff") {
        # Check if we have this color pre-resolved
        if ($this._preResolvedThemeColors.ContainsKey($themeKey)) {
            return $this._preResolvedThemeColors[$themeKey]
        }
        
        # If not pre-resolved, fall back to regular GetThemeColor and cache it
        $resolvedColor = $this.GetThemeColor($themeKey, $fallback)
        $this._preResolvedThemeColors[$themeKey] = $resolvedColor
        return $resolvedColor
    }
    
    # PERFORMANCE: Invalidate theme cache when theme changes
    [void] InvalidateThemeCache() {
        $this._preResolvedThemeColors = @{}
        $this._themeColorCache = @{}
        $this._lastThemeName = ""
        
        # Re-resolve if we have required colors defined
        if ($this._requiredThemeColors.Count -gt 0) {
            $this.ResolveThemeColors()
        }
        
        # Invalidate render cache since colors changed
        $this.InvalidateRenderCache()
    }
    
    # DEPENDENCY INJECTION: Inject services during component construction
    [void] InjectServices([hashtable]$services) {
        if ($services) {
            foreach ($key in $services.Keys) {
                $this._injectedServices[$key] = $services[$key]
            }
        }
    }
    
    # DEPENDENCY INJECTION: Inject a single service
    [void] InjectService([string]$serviceName, [object]$service) {
        $this._injectedServices[$serviceName] = $service
    }
    
    # DEPENDENCY INJECTION: Get an injected service (replaces service locator calls)
    [object] GetService([string]$serviceName) {
        if ($this._injectedServices.ContainsKey($serviceName)) {
            return $this._injectedServices[$serviceName]
        }
        
        # FALLBACK: If service not injected, fall back to global service access with warning
        if ($global:TuiDebugMode) {
            Write-Log -Level Warning -Message "Component '$($this.Name)' requesting non-injected service '$serviceName' - consider using dependency injection"
        }
        
        # Try direct Services access first
        if ($global:TuiState?.Services?.ContainsKey($serviceName)) {
            return $global:TuiState.Services[$serviceName]
        }
        
        # Fall back to service container
        if ($global:TuiState?.ServiceContainer) {
            return $global:TuiState.ServiceContainer.GetService($serviceName)
        }
        
        return $null
    }
    
    # DEPENDENCY INJECTION: Check if a service is available
    [bool] HasService([string]$serviceName) {
        return $this._injectedServices.ContainsKey($serviceName) -or
               $global:TuiState?.Services?.ContainsKey($serviceName) -or
               ($global:TuiState?.ServiceContainer -and $global:TuiState.ServiceContainer.GetService($serviceName))
    }
    
    # DEPENDENCY INJECTION: Get list of injected services
    [string[]] GetInjectedServiceNames() {
        return @($this._injectedServices.Keys)
    }

    [void] OnFocus() 
    { 
        # Default focus behavior - components should override with Add-Member
        if ($this.BorderColor) {
            $this.BorderColor = $this.GetThemeColor("primary.accent", "#0078d4")
            $this.RequestRedraw()
        }
        # Write-Verbose "OnFocus called for '$($this.Name)'." 
    }
    
    [void] OnBlur() 
    { 
        # Default blur behavior - components should override with Add-Member
        if ($this.BorderColor) {
            $this.BorderColor = $this.GetThemeColor("border", "#404040")
            $this.RequestRedraw()
        }
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
        
        # PERFORMANCE: Check if render is actually needed
        if (-not $this.NeedsRender()) {
            # Component hasn't changed, but still need to recurse to children
            foreach ($child in $this.GetSortedChildren()) {
                if ($child.Visible) {
                    $child._RenderContent()
                }
            }
            return
        }
        
        # PERFORMANCE: Track render cache metrics
        if ($global:TuiPerformanceMetrics -and $global:TuiDebugMode) {
            $global:TuiPerformanceMetrics.ComponentRenders++
        }
        
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
        foreach ($child in $this.GetSortedChildren()) {
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