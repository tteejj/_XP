# ==============================================================================
# Axiom-Phoenix v4.0 - All Functions (Load After Classes)
# Standalone functions for TUI operations and utilities
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: AFU.###" to find specific sections.
# Each section ends with "END_PAGE: AFU.###"
# ==============================================================================

#<!-- PAGE: AFU.001 - TUI Drawing Functions -->
#region TUI Drawing Functions

# ==============================================================================
# FUNCTION: Write-TuiText
#
# DEPENDENCIES:
#   Classes:
#     - TuiBuffer (ABC.003)
#
# PURPOSE:
#   A high-level wrapper around the `TuiBuffer.WriteString` method. It provides
#   a convenient, PowerShell-idiomatic way for UI components to draw text onto
#   a buffer without needing to instantiate `TuiCell` objects manually.
#
# KEY LOGIC:
#   - Accepts a `TuiBuffer` target, position, text, and a style hashtable.
#   - Delegates the actual drawing logic directly to the `WriteString` method
#     on the provided buffer instance.
# ==============================================================================
function Write-TuiText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][TuiBuffer]$Buffer,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][string]$Text,
        [hashtable]$Style = @{}
    )
    
    if ($null -eq $Buffer -or [string]::IsNullOrEmpty($Text)) { return }
    $Buffer.WriteString($X, $Y, $Text, $Style)
}

# ==============================================================================
# FUNCTION: Write-TuiBox
#
# DEPENDENCIES:
#   Functions:
#     - Get-TuiBorderChars (AFU.002)
#     - Write-TuiText (AFU.001)
#   Classes:
#     - TuiBuffer (ABC.003)
#
# PURPOSE:
#   Draws a styled box with borders and an optional title onto a buffer. This
#   is the primary function used by Panel components to render their frames.
#
# KEY LOGIC:
#   - Retrieves the correct border characters using `Get-TuiBorderChars`.
#   - Fills the background of the box area first.
#   - Draws the top, bottom, and side borders using `Write-TuiText`.
#   - Intelligently places and truncates the title on the top border.
#   - Handles small dimension edge cases (e.g., a 1x1 or 2x2 box).
# ==============================================================================
function Write-TuiBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][TuiBuffer]$Buffer,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][int]$Width,
        [Parameter(Mandatory)][int]$Height,
        [string]$Title = "",
        [hashtable]$Style = @{}
    )
    
    if ($null -eq $Buffer -or $Width -le 0 -or $Height -le 0) { return }

    $borderStyleName = $Style.BorderStyle ?? "Single"
    $borderColor = $Style.BorderFG ?? "#808080"
    $bgColor = $Style.BG ?? "#000000"
    $titleColor = $Style.TitleFG ?? $borderColor
    $fillChar = [char]($Style.FillChar ?? ' ')

    $borders = Get-TuiBorderChars -Style $borderStyleName
    
    $generalStyle = @{ FG = $borderColor; BG = $bgColor }
    $fillStyle = @{ FG = $borderColor; BG = $bgColor }
    $titleTextStyle = @{ FG = $titleColor; BG = $bgColor }
    if ($Style.TitleStyle) { foreach ($key in $Style.TitleStyle.Keys) { $titleTextStyle[$key] = $Style.TitleStyle[$key] } }

    $Buffer.FillRect($X, $Y, $Width, $Height, $fillChar, $fillStyle)
    
    if ($Height -gt 0) {
        if ($Width -gt 1) { Write-TuiText -Buffer $Buffer -X $X -Y $Y -Text "$($borders.TopLeft)$($borders.Horizontal * [Math]::Max(0, $Width - 2))$($borders.TopRight)" -Style $generalStyle }
        elseif ($Width -eq 1) { $Buffer.SetCell($X, $Y, [TuiCell]::new($borders.Vertical, $generalStyle.FG, $generalStyle.BG)) }
    }

    for ($i = 1; $i -lt ($Height - 1); $i++) {
        Write-TuiText -Buffer $Buffer -X $X -Y ($Y + $i) -Text $borders.Vertical -Style $generalStyle
        if ($Width -gt 1) { Write-TuiText -Buffer $Buffer -X ($X + $Width - 1) -Y ($Y + $i) -Text $borders.Vertical -Style $generalStyle }
    }
    
    if ($Height -gt 1) {
        if ($Width -gt 1) { Write-TuiText -Buffer $Buffer -X $X -Y ($Y + $Height - 1) -Text "$($borders.BottomLeft)$($borders.Horizontal * [Math]::Max(0, $Width - 2))$($borders.BottomRight)" -Style $generalStyle }
        elseif ($Width -eq 1) { $Buffer.SetCell($X, $Y + $Height - 1, [TuiCell]::new($borders.Vertical, $generalStyle.FG, $generalStyle.BG)) }
    }

    if (-not [string]::IsNullOrEmpty($Title) -and $Width -gt 2) {
        $titleText = " $Title "
        $maxTitleLength = $Width - 2
        if ($titleText.Length -gt $maxTitleLength) { $titleText = $titleText.Substring(0, $maxTitleLength - 3) + "..." }
        
        $titleX = $X + [Math]::Floor(($Width - $titleText.Length) / 2)
        Write-TuiText -Buffer $Buffer -X $titleX -Y $Y -Text $titleText -Style $titleTextStyle
    }
    
    $Buffer.IsDirty = $true
}

#endregion
#<!-- END_PAGE: AFU.001 -->

#<!-- PAGE: AFU.002 - Border Functions -->
#region Border Functions

# ==============================================================================
# FUNCTION: Get-TuiBorderChars
#
# DEPENDENCIES:
#   - None
#
# PURPOSE:
#   A simple data retrieval function. It acts as a lookup table for different
#   box-drawing character sets (e.g., Single, Double, Rounded).
#
# KEY LOGIC:
#   - Contains a static hashtable of predefined border styles.
#   - Returns the hashtable of characters corresponding to the requested style,
#     defaulting to "Single" if the style is not found.
# ==============================================================================
function Get-TuiBorderChars {
    [CmdletBinding()]
    param(
        [ValidateSet("Single", "Double", "Rounded", "Thick")][string]$Style = "Single"
    )
    
    $styles = @{
        Single = @{ TopLeft = '┌'; TopRight = '┐'; BottomLeft = '└'; BottomRight = '┘'; Horizontal = '─'; Vertical = '│' }
        Double = @{ TopLeft = '╔'; TopRight = '╗'; BottomLeft = '╚'; BottomRight = '╝'; Horizontal = '═'; Vertical = '║' }
        Rounded = @{ TopLeft = '╭'; TopRight = '╮'; BottomLeft = '╰'; BottomRight = '╯'; Horizontal = '─'; Vertical = '│' }
        Thick = @{ TopLeft = '┏'; TopRight = '┓'; BottomLeft = '┗'; BottomRight = '┛'; Horizontal = '━'; Vertical = '┃' }
    }
    
    return $styles[$Style] ?? $styles.Single
}

#endregion
#<!-- END_PAGE: AFU.002 -->

#<!-- PAGE: AFU.003 - Factory Functions -->
#region Factory Functions

# ==============================================================================
# FUNCTION: New-Tui* (e.g., New-TuiLabel, New-TuiButton)
#
# DEPENDENCIES:
#   Classes:
#     - Various component classes from AllComponents.ps1 (e.g., LabelComponent)
#
# PURPOSE:
#   Provides a set of convenient, PowerShell-idiomatic factory functions for
#   creating instances of common UI components.
#
# KEY LOGIC:
#   - Each function is a simple wrapper around the `[new]` constructor of a
#     component class.
#   - They expose common properties as parameters, allowing for concise,
#     declarative UI construction in screen initialization code.
# ==============================================================================
function New-TuiBuffer { [CmdletBinding()]param([int]$Width,[int]$Height,[string]$Name="Unnamed"); return [TuiBuffer]::new($Width, $Height, $Name) }
function New-TuiLabel { param([string]$Name,[string]$Text="",[int]$X=0,[int]$Y=0,[string]$Fg=$null); $c=[LabelComponent]::new($Name);$c.Text=$Text;$c.X=$X;$c.Y=$Y;if($Fg){$c.ForegroundColor=$Fg};return $c }
function New-TuiButton { param([string]$Name,[string]$Text="Button",[int]$X=0,[int]$Y=0,[int]$W=10,[int]$H=3,[scriptblock]$OnClick=$null); $c=[ButtonComponent]::new($Name);$c.Text=$Text;$c.X=$X;$c.Y=$Y;$c.Width=$W;$c.Height=$H;if($OnClick){$c.OnClick=$OnClick};return $c }
function New-TuiTextBox { param([string]$Name,[string]$Placeholder="",[int]$X=0,[int]$Y=0,[int]$W=20,[int]$H=3,[scriptblock]$OnChange=$null); $c=[TextBoxComponent]::new($Name);$c.Placeholder=$Placeholder;$c.X=$X;$c.Y=$Y;$c.Width=$W;$c.Height=$H;if($OnChange){$c.OnChange=$OnChange};return $c }
function New-TuiCheckBox { param([string]$Name,[string]$Text="Checkbox",[int]$X=0,[int]$Y=0,[bool]$Checked=$false,[scriptblock]$OnChange=$null); $c=[CheckBoxComponent]::new($Name);$c.Text=$Text;$c.X=$X;$c.Y=$Y;$c.Checked=$Checked;if($OnChange){$c.OnChange=$OnChange};return $c }
function New-TuiRadioButton { param([string]$Name,[string]$Text="Radio",[string]$Group="default",[int]$X=0,[int]$Y=0,[bool]$Selected=$false,[scriptblock]$OnChange=$null); $c=[RadioButtonComponent]::new($Name);$c.Text=$Text;$c.GroupName=$Group;$c.X=$X;$c.Y=$Y;$c.Selected=$Selected;if($OnChange){$c.OnChange=$OnChange};return $c }

#endregion
#<!-- END_PAGE: AFU.003 -->

#<!-- PAGE: AFU.004 - Theme Functions -->
#region Theme Functions

# ==============================================================================
# FUNCTION: Get-ThemeColor
#
# DEPENDENCIES:
#   Services:
#     - ThemeManager (ASE.005) (via $global:TuiState)
#
# PURPOSE:
#   The single point of access for all UI components to retrieve colors from the
#   currently active theme.
#
# KEY LOGIC:
#   - Retrieves the `ThemeManager` instance from the global state.
#   - Calls the manager's `GetColor` method to look up a color by its semantic
#     name (e.g., "button.focused.bg").
#   - Returns a default color if the `ThemeManager` isn't available or the
#     color name is not found, ensuring the UI never fails to render due to a
#     missing color definition.
# ==============================================================================
function Get-ThemeColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ColorName,
        [string]$DefaultColor = "#808080"
    )
    $themeManager = $global:TuiState.Services.ThemeManager
    if ($themeManager) {
        $color = $themeManager.GetColor($ColorName, $DefaultColor)
        if ($color) { return $color }
    }
    return $DefaultColor
}

#endregion
#<!-- END_PAGE: AFU.004 -->

#<!-- PAGE: AFU.005 - Focus Management -->
#region Focus Management Functions

# ==============================================================================
# FUNCTION: Set-ComponentFocus
#
# DEPENDENCIES:
#   Services:
#     - FocusManager (ASE.009) (via $global:TuiState)
#
# PURPOSE:
#   A global convenience function to set input focus on a specific component.
#   (DEPRECATED in favor of direct service access).
#
# KEY LOGIC:
#   - Retrieves the `FocusManager` instance from the global state.
#   - Delegates the call directly to `FocusManager.SetFocus()`.
# ==============================================================================
function Set-ComponentFocus {
    [CmdletBinding()]
    param([Parameter(Mandatory)][UIElement]$Component)
    $global:TuiState.Services.FocusManager?.SetFocus($Component)
}

#endregion
#<!-- END_PAGE: AFU.005 -->

#<!-- PAGE: AFU.006 - Logging Functions -->
#region Logging Functions

# ==============================================================================
# FUNCTION: Write-Log
#
# DEPENDENCIES:
#   Services:
#     - Logger (ASE.006) (via $global:TuiState)
#
# PURPOSE:
#   The single, centralized function for all framework and application-level
#   logging. It provides a consistent logging interface that can be routed to
#   different outputs by the `Logger` service.
#
# KEY LOGIC:
#   - Attempts to get the `Logger` service instance from the global state.
#   - If the service is found, it calls the service's `Log` method, passing
#     the level, message, and any additional structured data.
#   - If the `Logger` service is not yet available (e.g., during initial
#     startup), it provides a fallback mechanism to write directly to the host
#     console with basic color-coding.
# ==============================================================================
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Trace', 'Debug', 'Info', 'Warning', 'Error', 'Fatal')][string]$Level,
        [Parameter(Mandatory)][string]$Message,
        [object]$Data = $null
    )
    $logger = $global:TuiState.Services.Logger
    if ($logger) {
        $logger.Log($Level, $Message, $Data)
    }
    else {
        $timestamp = Get-Date -Format "HH:mm:ss"
        $prefix = "[$timestamp] [$Level]"
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Info' { 'Cyan' }
            default { 'Gray' }
        }
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

#endregion
#<!-- END_PAGE: AFU.006 -->

#<!-- PAGE: AFU.007 - Event Functions -->
#region Event System

# ==============================================================================
# FUNCTION: Subscribe-Event / Unsubscribe-Event / Publish-Event
#
# DEPENDENCIES:
#   Services:
#     - EventManager (ASE.007) (via $global:TuiState)
#
# PURPOSE:
#   A set of global convenience functions that act as wrappers around the
#   `EventManager` service. They provide a simple, global way for any part of
#   the code to participate in the event system.
#
# KEY LOGIC:
#   - Each function retrieves the `EventManager` instance from the global state.
#   - They delegate the call directly to the corresponding method on the service
#     instance (`Subscribe`, `Unsubscribe`, `Publish`).
# ==============================================================================
function Subscribe-Event {
    [CmdletBinding()]
    param([string]$EventName,[scriptblock]$Handler,[string]$Source="");
    return $global:TuiState.Services.EventManager?.Subscribe($EventName, $Handler)
}

function Unsubscribe-Event {
    [CmdletBinding()]
    param([string]$EventName,[string]$HandlerId);
    $global:TuiState.Services.EventManager?.Unsubscribe($EventName, $HandlerId)
}

function Publish-Event {
    [CmdletBinding()]
    param([string]$EventName,[hashtable]$EventData=@{});
    $global:TuiState.Services.EventManager?.Publish($EventName, $EventData)
}

#endregion
#<!-- END_PAGE: AFU.007 -->

#<!-- PAGE: AFU.008 - Error Handling -->
#region Error Handling Functions
#endregion
#<!-- END_PAGE: AFU.008 -->

#<!-- PAGE: AFU.009 - Input Processing -->
#region Input Processing Functions
#endregion
#<!-- END_PAGE: AFU.009 -->

#<!-- PAGE: AFU.010 - Utility Functions -->
#region Utility Functions
#endregion
#<!-- END_PAGE: AFU.010 -->