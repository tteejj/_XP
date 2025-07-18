# ==============================================================================
# Axiom-Phoenix v4.0 - Enhanced Type System
# Custom attributes, validation, and type safety improvements
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.ComponentModel.DataAnnotations

#region Custom Validation Attributes

# Theme color validation attribute
class ThemeColorAttribute : ValidationAttribute {
    [bool] $AllowFallback = $true
    
    ThemeColorAttribute() {
        $this.ErrorMessage = "Invalid theme color key"
    }
    
    [bool] IsValid([object]$value) {
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace($value)) {
            return $false
        }
        
        $colorKey = $value.ToString()
        
        # Check if it's a valid theme color key or hex color
        if ($colorKey.StartsWith("#") -and $colorKey.Length -in @(4, 7, 9)) {
            return $true
        }
        
        # Check against theme manager if available
        if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.ThemeManager) {
            return $global:TuiState.Services.ThemeManager.IsValidThemeKey($colorKey)
        }
        
        return $this.AllowFallback
    }
}

# Coordinate validation attribute
class CoordinateAttribute : ValidationAttribute {
    [int] $MinValue = 0
    [int] $MaxValue = [int]::MaxValue
    
    CoordinateAttribute() {
        $this.ErrorMessage = "Coordinate value must be between {0} and {1}"
    }
    
    CoordinateAttribute([int]$min, [int]$max) {
        $this.MinValue = $min
        $this.MaxValue = $max
        $this.ErrorMessage = "Coordinate value must be between $min and $max"
    }
    
    [bool] IsValid([object]$value) {
        if ($null -eq $value) { return $false }
        
        $intValue = 0
        if ([int]::TryParse($value.ToString(), [ref]$intValue)) {
            return $intValue -ge $this.MinValue -and $intValue -le $this.MaxValue
        }
        
        return $false
    }
}

# Component name validation attribute
class ComponentNameAttribute : ValidationAttribute {
    [bool] $AllowEmpty = $false
    [string[]] $ReservedNames = @("System", "Global", "Root")
    
    ComponentNameAttribute() {
        $this.ErrorMessage = "Invalid component name"
    }
    
    [bool] IsValid([object]$value) {
        if ($null -eq $value) { return $this.AllowEmpty }
        
        $name = $value.ToString()
        if ([string]::IsNullOrWhiteSpace($name)) { return $this.AllowEmpty }
        
        # Check reserved names
        if ($name -in $this.ReservedNames) { return $false }
        
        # Check valid characters (alphanumeric, underscore, dash)
        return $name -match '^[a-zA-Z0-9_-]+$'
    }
}

#endregion

#region Component Property Attributes

# Marks a property as bindable to data
class BindableAttribute : System.Attribute {
    [string] $PropertyName
    [bool] $TwoWay = $false
    
    BindableAttribute([string]$propertyName) {
        $this.PropertyName = $propertyName
    }
    
    BindableAttribute([string]$propertyName, [bool]$twoWay) {
        $this.PropertyName = $propertyName
        $this.TwoWay = $twoWay
    }
}

# Marks a property as theme-aware
class ThemeAwareAttribute : System.Attribute {
    [string] $ThemeKey
    [string] $FallbackValue
    
    ThemeAwareAttribute([string]$themeKey) {
        $this.ThemeKey = $themeKey
    }
    
    ThemeAwareAttribute([string]$themeKey, [string]$fallbackValue) {
        $this.ThemeKey = $themeKey
        $this.FallbackValue = $fallbackValue
    }
}

# Marks a property as performance-critical
class PerformanceCriticalAttribute : System.Attribute {
    [string] $Reason
    [bool] $CacheValue = $true
    
    PerformanceCriticalAttribute([string]$reason) {
        $this.Reason = $reason
    }
}

#endregion

#region Enhanced Component Base with Type Safety

class TypedUIElement : LifecycleAwareUIElement {
    # Coordinate properties with validation
    hidden [int] $_validatedX = 0
    hidden [int] $_validatedY = 0
    hidden [int] $_validatedWidth = 10
    hidden [int] $_validatedHeight = 3
    
    # Color properties with theme validation
    hidden [string] $_validatedForegroundColor = ""
    hidden [string] $_validatedBackgroundColor = ""
    hidden [string] $_validatedBorderColor = ""
    
    # Property validation cache
    hidden [hashtable] $_validationCache = @{}
    hidden [bool] $_validationEnabled = $true
    
    TypedUIElement([string]$name) : base($name) {
        # Initialize with validation
        $this.EnableValidation($true)
    }
    
    # Enable/disable validation
    [void] EnableValidation([bool]$enabled) {
        $this._validationEnabled = $enabled
    }
    
    # Validated coordinate properties
    [int] GetValidatedX() {
        return $this._validatedX
    }
    
    [void] SetValidatedX([int]$value) {
        if ($this.ValidateCoordinate("X", $value, 0, 1000)) {
            $this._validatedX = $value
            $this.X = $value
            $this.OnPropertyChanged("X")
        }
    }
    
    [int] GetValidatedY() {
        return $this._validatedY
    }
    
    [void] SetValidatedY([int]$value) {
        if ($this.ValidateCoordinate("Y", $value, 0, 1000)) {
            $this._validatedY = $value
            $this.Y = $value
            $this.OnPropertyChanged("Y")
        }
    }
    
    [int] GetValidatedWidth() {
        return $this._validatedWidth
    }
    
    [void] SetValidatedWidth([int]$value) {
        if ($this.ValidateCoordinate("Width", $value, 1, 1000)) {
            $this._validatedWidth = $value
            $this.Width = $value
            $this.OnPropertyChanged("Width")
        }
    }
    
    [int] GetValidatedHeight() {
        return $this._validatedHeight
    }
    
    [void] SetValidatedHeight([int]$value) {
        if ($this.ValidateCoordinate("Height", $value, 1, 1000)) {
            $this._validatedHeight = $value
            $this.Height = $value
            $this.OnPropertyChanged("Height")
        }
    }
    
    # Validated color properties
    [string] GetValidatedForegroundColor() {
        return $this._validatedForegroundColor
    }
    
    [void] SetValidatedForegroundColor([string]$value) {
        if ($this.ValidateThemeColor("ForegroundColor", $value)) {
            $this._validatedForegroundColor = $value
            $this.ForegroundColor = $value
            $this.OnPropertyChanged("ForegroundColor")
        }
    }
    
    [string] GetValidatedBackgroundColor() {
        return $this._validatedBackgroundColor
    }
    
    [void] SetValidatedBackgroundColor([string]$value) {
        if ($this.ValidateThemeColor("BackgroundColor", $value)) {
            $this._validatedBackgroundColor = $value
            $this.BackgroundColor = $value
            $this.OnPropertyChanged("BackgroundColor")
        }
    }
    
    # Property validation methods
    [bool] ValidateCoordinate([string]$propertyName, [int]$value, [int]$min, [int]$max) {
        if (-not $this._validationEnabled) { return $true }
        
        $cacheKey = "${propertyName}:${value}:${min}:${max}"
        if ($this._validationCache.ContainsKey($cacheKey)) {
            return $this._validationCache[$cacheKey]
        }
        
        $valid = $value -ge $min -and $value -le $max
        $this._validationCache[$cacheKey] = $valid
        
        if (-not $valid) {
            Write-Log -Level Warning -Message "Invalid coordinate for $($this.Name).${propertyName}: ${value} (expected ${min}-${max})"
        }
        
        return $valid
    }
    
    [bool] ValidateThemeColor([string]$propertyName, [string]$value) {
        if (-not $this._validationEnabled) { return $true }
        
        $cacheKey = "color:${propertyName}:${value}"
        if ($this._validationCache.ContainsKey($cacheKey)) {
            return $this._validationCache[$cacheKey]
        }
        
        $validator = [ThemeColorAttribute]::new()
        $valid = $validator.IsValid($value)
        $this._validationCache[$cacheKey] = $valid
        
        if (-not $valid) {
            Write-Log -Level Warning -Message "Invalid theme color for $($this.Name).${propertyName}: ${value}"
        }
        
        return $valid
    }
    
    # Property change notification
    [void] OnPropertyChanged([string]$propertyName) {
        # Trigger validation and redraw
        Request-OptimizedRedraw -Source "TypedComponent:$($this.Name):${propertyName}"
        
        # Clear related validation cache
        $keysToRemove = $this._validationCache.Keys | Where-Object { $_ -like "*${propertyName}*" }
        foreach ($key in $keysToRemove) {
            $this._validationCache.Remove($key)
        }
    }
    
    # Type safety helpers
    [hashtable] GetValidationReport() {
        return @{
            ValidationEnabled = $this._validationEnabled
            CacheSize = $this._validationCache.Count
            ValidatedProperties = @{
                X = $this._validatedX
                Y = $this._validatedY
                Width = $this._validatedWidth
                Height = $this._validatedHeight
                ForegroundColor = $this._validatedForegroundColor
                BackgroundColor = $this._validatedBackgroundColor
            }
        }
    }
    
    # Cleanup validation cache
    [void] OnDispose() {
        $this._validationCache.Clear()
        ([LifecycleAwareUIElement]$this).OnDispose()
    }
}

#endregion

#region Type-Safe Property Helpers

# Create type-safe property setter
function Set-TypedProperty {
    param(
        [object]$Component,
        [string]$PropertyName,
        [object]$Value,
        [type]$ExpectedType = $null
    )
    
    if ($ExpectedType -and $Value -isnot $ExpectedType) {
        throw "Property '$PropertyName' expects type '$($ExpectedType.Name)' but got '$($Value.GetType().Name)'"
    }
    
    # Use reflection to set property
    $property = $Component.GetType().GetProperty($PropertyName)
    if ($property) {
        $property.SetValue($Component, $Value)
    } else {
        throw "Property '$PropertyName' not found on component '$($Component.GetType().Name)'"
    }
}

# Validate component configuration
function Test-ComponentConfiguration {
    param([object]$Component)
    
    $issues = @()
    
    # Check required properties
    if ($Component.Name -and -not (Test-ComponentName $Component.Name)) {
        $issues += "Invalid component name: $($Component.Name)"
    }
    
    # Check coordinates
    if ($Component.X -lt 0) { $issues += "X coordinate cannot be negative" }
    if ($Component.Y -lt 0) { $issues += "Y coordinate cannot be negative" }
    if ($Component.Width -le 0) { $issues += "Width must be positive" }
    if ($Component.Height -le 0) { $issues += "Height must be positive" }
    
    # Check colors if present
    if ($Component.PSObject.Properties['ForegroundColor'] -and $Component.ForegroundColor) {
        if (-not (Test-ThemeColor $Component.ForegroundColor)) {
            $issues += "Invalid foreground color: $($Component.ForegroundColor)"
        }
    }
    
    return @{
        Valid = $issues.Count -eq 0
        Issues = $issues
    }
}

# Helper validation functions
function Test-ComponentName {
    param([string]$Name)
    $validator = [ComponentNameAttribute]::new()
    return $validator.IsValid($Name)
}

function Test-ThemeColor {
    param([string]$Color)
    $validator = [ThemeColorAttribute]::new()
    return $validator.IsValid($Color)
}

#endregion

Write-Host "Enhanced Type System loaded" -ForegroundColor Green