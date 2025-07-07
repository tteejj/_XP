# ==============================================================================
# Axiom-Phoenix v4.0 - All Functions (Load After Classes)
# Standalone functions for TUI operations and utilities
# ==============================================================================

#region TUI Drawing Functions

function Write-TuiBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [TuiBuffer]$Buffer,
        
        [Parameter(Mandatory)]
        [int]$X,
        
        [Parameter(Mandatory)]
        [int]$Y,
        
        [Parameter(Mandatory)]
        [int]$Width,
        
        [Parameter(Mandatory)]
        [int]$Height,
        
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        [string]$BorderStyle = "Single",
        [string]$Title = ""
    )
    
    try {
        if ($Width -le 0 -or $Height -le 0) {
            Write-Warning "Write-TuiBox: Invalid dimensions ($($Width)x$($Height)). Dimensions must be positive."
            return
        }
        
        $borders = Get-TuiBorderChars -Style $BorderStyle
        
        # Calculate effective drawing area
        $drawStartX = [Math]::Max(0, $X)
        $drawStartY = [Math]::Max(0, $Y)
        $drawEndX = [Math]::Min($Buffer.Width, $X + $Width)
        $drawEndY = [Math]::Min($Buffer.Height, $Y + $Height)
        
        if ($drawEndX -le $drawStartX -or $drawEndY -le $drawStartY) {
            Write-Verbose "Write-TuiBox: Effective drawing area is invalid after clipping. Skipping."
            return
        }
        
        # Fill background
        $fillCell = [TuiCell]::new(' ', $ForegroundColor, $BackgroundColor)
        for ($currentY = $drawStartY; $currentY -lt $drawEndY; $currentY++) {
            for ($currentX = $drawStartX; $currentX -lt $drawEndX; $currentX++) {
                $Buffer.SetCell($currentX, $currentY, [TuiCell]::new($fillCell))
            }
        }
        
        # Draw corners
        if ($X -ge 0 -and $Y -ge 0) { 
            $Buffer.SetCell($X, $Y, [TuiCell]::new($borders.TopLeft, $ForegroundColor, $BackgroundColor))
        }
        if (($X + $Width - 1) -lt $Buffer.Width -and $Y -ge 0) { 
            $Buffer.SetCell($X + $Width - 1, $Y, [TuiCell]::new($borders.TopRight, $ForegroundColor, $BackgroundColor))
        }
        if ($X -ge 0 -and ($Y + $Height - 1) -lt $Buffer.Height) { 
            $Buffer.SetCell($X, $Y + $Height - 1, [TuiCell]::new($borders.BottomLeft, $ForegroundColor, $BackgroundColor))
        }
        if (($X + $Width - 1) -lt $Buffer.Width -and ($Y + $Height - 1) -lt $Buffer.Height) { 
            $Buffer.SetCell($X + $Width - 1, $Y + $Height - 1, [TuiCell]::new($borders.BottomRight, $ForegroundColor, $BackgroundColor))
        }
        
        # Draw horizontal lines
        for ($i = 1; $i -lt $Width - 1; $i++) {
            if ($Y -ge 0 -and ($X + $i) -ge 0 -and ($X + $i) -lt $Buffer.Width) {
                $Buffer.SetCell($X + $i, $Y, [TuiCell]::new($borders.Horizontal, $ForegroundColor, $BackgroundColor))
            }
            if (($Y + $Height - 1) -ge 0 -and ($Y + $Height - 1) -lt $Buffer.Height -and ($X + $i) -ge 0 -and ($X + $i) -lt $Buffer.Width) {
                $Buffer.SetCell($X + $i, $Y + $Height - 1, [TuiCell]::new($borders.Horizontal, $ForegroundColor, $BackgroundColor))
            }
        }
        
        # Draw vertical lines
        for ($i = 1; $i -lt $Height - 1; $i++) {
            if ($X -ge 0 -and ($Y + $i) -ge 0 -and ($Y + $i) -lt $Buffer.Height) {
                $Buffer.SetCell($X, $Y + $i, [TuiCell]::new($borders.Vertical, $ForegroundColor, $BackgroundColor))
            }
            if (($X + $Width - 1) -ge 0 -and ($X + $Width - 1) -lt $Buffer.Width -and ($Y + $i) -ge 0 -and ($Y + $i) -lt $Buffer.Height) {
                $Buffer.SetCell($X + $Width - 1, $Y + $i, [TuiCell]::new($borders.Vertical, $ForegroundColor, $BackgroundColor))
            }
        }
        
        # Draw title if provided
        if ($Title -and $Title.Length -gt 0 -and $Y -ge 0) {
            $titleWithSpace = " $Title "
            $titleX = $X + [Math]::Floor(($Width - $titleWithSpace.Length) / 2)
            if ($titleX -ge 0) {
                $maxTitleLength = [Math]::Min($titleWithSpace.Length, $Width - 2)
                if ($maxTitleLength -gt 0) {
                    $displayTitle = $titleWithSpace.Substring(0, $maxTitleLength)
                    $Buffer.WriteString($titleX, $Y, $displayTitle, $ForegroundColor, $BackgroundColor)
                }
            }
        }
    }
    catch {
        Write-Error "Write-TuiBox error: $_"
    }
}

function Write-TuiText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][TuiBuffer]$Buffer,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][string]$Text,
        [object]$ForegroundColor = [ConsoleColor]::White,
        [object]$BackgroundColor = [ConsoleColor]::Black,
        [bool]$Bold = $false,
        [bool]$Underline = $false,
        [bool]$Italic = $false,
        [int]$ZIndex = 0
    )
    
    try {
        if ($Y -lt 0 -or $Y -ge $Buffer.Height) {
            Write-Warning "Write-TuiText: Y coordinate ($Y) is out of bounds for buffer '$($Buffer.Name)' (0..$($Buffer.Height-1)). Text: '$Text'."
            return
        }
        
        $currentX = $X
        foreach ($char in $Text.ToCharArray()) {
            if ($currentX -ge $Buffer.Width) { break }
            if ($currentX -ge 0) {
                $cell = [TuiCell]::new($char, $ForegroundColor, $BackgroundColor, $Bold, $Underline)
                $cell.Italic = $Italic
                $cell.ZIndex = $ZIndex
                $Buffer.SetCell($currentX, $Y, $cell)
            }
            $currentX++
        }
        
        Write-Verbose "Write-TuiText: Wrote '$Text' to buffer '$($Buffer.Name)' at ($X, $Y)."
    }
    catch {
        Write-Error "Failed to write text to buffer '$($Buffer.Name)' at ($X, $Y): $($_.Exception.Message)"
        throw
    }
}

function Write-TuiBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][TuiBuffer]$Buffer,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][int]$Width,
        [Parameter(Mandatory)][int]$Height,
        [ValidateSet("Single", "Double", "Rounded", "Thick")][string]$BorderStyle = "Single",
        [object]$BorderColor = [ConsoleColor]::White,
        [object]$BackgroundColor = [ConsoleColor]::Black,
        [string]$Title = ""
    )
    
    try {
        if ($Width -le 0 -or $Height -le 0) {
            Write-Warning "Write-TuiBox: Invalid dimensions ($($Width)x$($Height)). Dimensions must be positive."
            return
        }
        
        $borders = Get-TuiBorderChars -Style $BorderStyle
        
        # Calculate effective drawing area
        $drawStartX = [Math]::Max(0, $X)
        $drawStartY = [Math]::Max(0, $Y)
        $drawEndX = [Math]::Min($Buffer.Width, $X + $Width)
        $drawEndY = [Math]::Min($Buffer.Height, $Y + $Height)
        
        if ($drawEndX -le $drawStartX -or $drawEndY -le $drawStartY) {
            Write-Verbose "Write-TuiBox: Effective drawing area is invalid after clipping. Skipping."
            return
        }
        
        # Fill background
        $fillCell = [TuiCell]::new(' ', $BorderColor, $BackgroundColor)
        for ($currentY = $drawStartY; $currentY -lt $drawEndY; $currentY++) {
            for ($currentX = $drawStartX; $currentX -lt $drawEndX; $currentX++) {
                $Buffer.SetCell($currentX, $currentY, [TuiCell]::new($fillCell))
            }
        }
        
        # Draw corners
        if ($X -ge 0 -and $Y -ge 0) { 
            $Buffer.SetCell($X, $Y, [TuiCell]::new($borders.TopLeft, $BorderColor, $BackgroundColor))
        }
        if (($X + $Width - 1) -lt $Buffer.Width -and $Y -ge 0) { 
            $Buffer.SetCell($X + $Width - 1, $Y, [TuiCell]::new($borders.TopRight, $BorderColor, $BackgroundColor))
        }
        if ($X -ge 0 -and ($Y + $Height - 1) -lt $Buffer.Height) { 
            $Buffer.SetCell($X, $Y + $Height - 1, [TuiCell]::new($borders.BottomLeft, $BorderColor, $BackgroundColor))
        }
        if (($X + $Width - 1) -lt $Buffer.Width -and ($Y + $Height - 1) -lt $Buffer.Height) { 
            $Buffer.SetCell($X + $Width - 1, $Y + $Height - 1, [TuiCell]::new($borders.BottomRight, $BorderColor, $BackgroundColor))
        }
        
        # Draw horizontal borders
        for ($cx = 1; $cx -lt ($Width - 1); $cx++) {
            if (($X + $cx) -ge 0 -and ($X + $cx) -lt $Buffer.Width) {
                if ($Y -ge 0 -and $Y -lt $Buffer.Height) { 
                    $Buffer.SetCell($X + $cx, $Y, [TuiCell]::new($borders.Horizontal, $BorderColor, $BackgroundColor))
                }
                if ($Height -gt 1 -and ($Y + $Height - 1) -ge 0 -and ($Y + $Height - 1) -lt $Buffer.Height) { 
                    $Buffer.SetCell($X + $cx, $Y + $Height - 1, [TuiCell]::new($borders.Horizontal, $BorderColor, $BackgroundColor))
                }
            }
        }
        
        # Draw vertical borders
        for ($cy = 1; $cy -lt ($Height - 1); $cy++) {
            if (($Y + $cy) -ge 0 -and ($Y + $cy) -lt $Buffer.Height) {
                if ($X -ge 0 -and $X -lt $Buffer.Width) { 
                    $Buffer.SetCell($X, $Y + $cy, [TuiCell]::new($borders.Vertical, $BorderColor, $BackgroundColor))
                }
                if ($Width -gt 1 -and ($X + $Width - 1) -ge 0 -and ($X + $Width - 1) -lt $Buffer.Width) { 
                    $Buffer.SetCell($X + $Width - 1, $Y + $cy, [TuiCell]::new($borders.Vertical, $BorderColor, $BackgroundColor))
                }
            }
        }
        
        # Draw title if provided
        if (-not [string]::IsNullOrEmpty($Title) -and $Y -ge 0 -and $Y -lt $Buffer.Height) {
            $titleText = " $Title "
            if ($titleText.Length -le ($Width - 2)) { 
                $titleX = $X + [Math]::Floor(($Width - $titleText.Length) / 2)
                Write-TuiText -Buffer $Buffer -X $titleX -Y $Y -Text $titleText -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
            }
        }
        
        Write-Verbose "Write-TuiBox: Drew '$BorderStyle' box on buffer '$($Buffer.Name)' at ($X, $Y) with dimensions $($Width)x$($Height)."
    }
    catch {
        Write-Error "Failed to draw TUI box on buffer '$($Buffer.Name)' at ($X, $Y), $($Width)x$($Height): $($_.Exception.Message)"
        throw
    }
}

function Get-TuiBorderChars {
    [CmdletBinding()]
    param(
        [ValidateSet("Single", "Double", "Rounded", "Thick")][string]$Style = "Single"
    )
    
    try {
        $styles = @{
            Single = @{ 
                TopLeft = '┌'; TopRight = '┐'; BottomLeft = '└'; BottomRight = '┘'; 
                Horizontal = '─'; Vertical = '│' 
            }
            Double = @{ 
                TopLeft = '╔'; TopRight = '╗'; BottomLeft = '╚'; BottomRight = '╝'; 
                Horizontal = '═'; Vertical = '║' 
            }
            Rounded = @{ 
                TopLeft = '╭'; TopRight = '╮'; BottomLeft = '╰'; BottomRight = '╯'; 
                Horizontal = '─'; Vertical = '│' 
            }
            Thick = @{ 
                TopLeft = '┏'; TopRight = '┓'; BottomLeft = '┗'; BottomRight = '┛'; 
                Horizontal = '━'; Vertical = '┃' 
            }
        }
        
        $selectedStyle = $styles[$Style]
        if ($null -eq $selectedStyle) {
            Write-Warning "Get-TuiBorderChars: Border style '$Style' not found. Returning 'Single' style."
            return $styles.Single
        }
        
        Write-Verbose "Get-TuiBorderChars: Retrieved TUI border characters for style: $Style."
        return $selectedStyle
    }
    catch {
        Write-Error "Failed to get TUI border characters for style '$Style': $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Factory Functions

function New-TuiBuffer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Width,
        [Parameter(Mandatory)][int]$Height,
        [string]$Name = "Unnamed"
    )
    return [TuiBuffer]::new($Width, $Height, $Name)
}

function New-TuiLabel {
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $labelName = $Props.Name ?? "Label_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $label = [LabelComponent]::new($labelName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($label.PSObject.Properties.Match($_.Name)) {
                $label.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created label '$labelName' with $($Props.Count) properties"
        return $label
    }
    catch {
        Write-Error "Failed to create label: $($_.Exception.Message)"
        throw
    }
}

function New-TuiButton {
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $buttonName = $Props.Name ?? "Button_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $button = [ButtonComponent]::new($buttonName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($button.PSObject.Properties.Match($_.Name)) {
                $button.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created button '$buttonName' with $($Props.Count) properties"
        return $button
    }
    catch {
        Write-Error "Failed to create button: $($_.Exception.Message)"
        throw
    }
}

function New-TuiTextBox {
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $textBoxName = $Props.Name ?? "TextBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $textBox = [TextBoxComponent]::new($textBoxName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($textBox.PSObject.Properties.Match($_.Name)) {
                $textBox.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created textbox '$textBoxName' with $($Props.Count) properties"
        return $textBox
    }
    catch {
        Write-Error "Failed to create textbox: $($_.Exception.Message)"
        throw
    }
}

function New-TuiCheckBox {
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $checkBoxName = $Props.Name ?? "CheckBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $checkBox = [CheckBoxComponent]::new($checkBoxName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($checkBox.PSObject.Properties.Match($_.Name)) {
                $checkBox.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created checkbox '$checkBoxName' with $($Props.Count) properties"
        return $checkBox
    }
    catch {
        Write-Error "Failed to create checkbox: $($_.Exception.Message)"
        throw
    }
}

function New-TuiRadioButton {
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $radioButtonName = $Props.Name ?? "RadioButton_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $radioButton = [RadioButtonComponent]::new($radioButtonName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($radioButton.PSObject.Properties.Match($_.Name)) {
                $radioButton.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created radio button '$radioButtonName' with $($Props.Count) properties"
        return $radioButton
    }
    catch {
        Write-Error "Failed to create radio button: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Theme Functions

function Get-ThemeColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ColorName
    )
    
    if ($global:TuiState.Services.ThemeManager) {
        return $global:TuiState.Services.ThemeManager.GetColor($ColorName)
    }
    
    # Fallback if theme manager not available
    $defaultTheme = @{
        'Foreground' = [ConsoleColor]::White
        'Background' = [ConsoleColor]::Black
        'Accent' = [ConsoleColor]::Cyan
        'Header' = [ConsoleColor]::Cyan
        'Subtle' = [ConsoleColor]::DarkGray
        'Highlight' = [ConsoleColor]::Yellow
        'Border' = [ConsoleColor]::Gray
        'Selection' = [ConsoleColor]::DarkBlue
        'button.normal.background' = [ConsoleColor]::Black
        'button.normal.foreground' = [ConsoleColor]::White
        'button.normal.border' = [ConsoleColor]::Gray
        'button.focus.background' = [ConsoleColor]::Black
        'button.focus.foreground' = [ConsoleColor]::White
        'button.focus.border' = [ConsoleColor]::Cyan
        'button.pressed.background' = [ConsoleColor]::DarkGray
        'button.pressed.foreground' = [ConsoleColor]::Black
        'button.pressed.border' = [ConsoleColor]::Cyan
    }
    
    return $defaultTheme[$ColorName] ?? [ConsoleColor]::White
}

#endregion

#region Utility Functions

function Set-ComponentFocus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][UIElement]$Component
    )
    
    # Find parent screen/container and clear other focus
    $parent = $Component.Parent
    while ($parent -and -not ($parent -is [Screen])) {
        $parent = $parent.Parent
    }
    
    if ($parent) {
        # Clear focus from all other focusable components
        $parent.Children | ForEach-Object {
            if ($_.IsFocusable -and $_.IsFocused -and $_ -ne $Component) {
                $_.IsFocused = $false
                $_.OnBlur()
                $_.RequestRedraw()
            }
        }
    }
    
    # Set focus on target component
    if ($Component.IsFocusable) {
        $Component.IsFocused = $true
        $Component.OnFocus()
        $Component.RequestRedraw()
        Write-Verbose "Set focus to component: $($Component.Name)"
    } else {
        Write-Warning "Component '$($Component.Name)' is not focusable"
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info'
    )
    
    # Simplified logging - in full app this would use Logger service
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'Error' { Write-Error $logMessage }
        'Warning' { Write-Warning $logMessage }
        'Debug' { Write-Debug $logMessage }
        default { Write-Verbose $logMessage }
    }
}

#endregion

#region Event System

function Subscribe-Event {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventName,
        [Parameter(Mandatory)][scriptblock]$Handler,
        [string]$Source = ""
    )
    
    if ($global:TuiState.Services.EventManager) {
        return $global:TuiState.Services.EventManager.Subscribe($EventName, $Handler)
    }
    
    # Fallback
    $subscriptionId = [Guid]::NewGuid().ToString()
    Write-Verbose "Subscribed to event '$EventName' with handler ID: $subscriptionId"
    return $subscriptionId
}

function Unsubscribe-Event {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventName,
        [Parameter(Mandatory)][string]$HandlerId
    )
    
    if ($global:TuiState.Services.EventManager) {
        $global:TuiState.Services.EventManager.Unsubscribe($EventName, $HandlerId)
    }
    Write-Verbose "Unsubscribed from event '$EventName' (Handler ID: $HandlerId)"
}

function Publish-Event {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventName,
        [hashtable]$EventData = @{}
    )
    
    if ($global:TuiState.Services.EventManager) {
        $global:TuiState.Services.EventManager.Publish($EventName, $EventData)
    }
    Write-Verbose "Published event '$EventName' with data: $($EventData | ConvertTo-Json -Compress)"
}

#endregion

#region Initialize Functions

function Initialize-Logger {
    [CmdletBinding()]
    param()
    
    $logger = [Logger]::new()
    Write-Verbose "Logger initialized at: $($logger.LogPath)"
    return $logger
}

function Initialize-EventManager {
    [CmdletBinding()]
    param()
    
    $eventManager = [EventManager]::new()
    Write-Verbose "EventManager initialized"
    return $eventManager
}

function Initialize-ThemeManager {
    [CmdletBinding()]
    param()
    
    $themeManager = [ThemeManager]::new()
    Write-Verbose "ThemeManager initialized with theme: $($themeManager.ThemeName)"
    return $themeManager
}

function Initialize-ActionService {
    [CmdletBinding()]
    param(
        [EventManager]$EventManager = $null
    )
    
    $actionService = if ($EventManager) {
        [ActionService]::new($EventManager)
    } else {
        [ActionService]::new()
    }
    Write-Verbose "ActionService initialized"
    return $actionService
}

function Initialize-DataManager {
    [CmdletBinding()]
    param(
        [string]$DataPath = (Join-Path $env:APPDATA "AxiomPhoenix\data.json"),
        [EventManager]$EventManager = $null
    )
    
    $dataManager = if ($EventManager) {
        [DataManager]::new($DataPath, $EventManager)
    } else {
        [DataManager]::new($DataPath)
    }
    Write-Verbose "DataManager initialized with path: $($dataManager.DataPath)"
    return $dataManager
}

function Initialize-ServiceContainer {
    [CmdletBinding()]
    param()
    
    $container = [ServiceContainer]::new()
    Write-Verbose "ServiceContainer initialized"
    return $container
}

function Initialize-NavigationService {
    [CmdletBinding()]
    param(
        [EventManager]$EventManager = $null
    )
    
    $navService = if ($EventManager) {
        [NavigationService]::new($EventManager)
    } else {
        [NavigationService]::new()
    }
    Write-Verbose "NavigationService initialized"
    return $navService
}

function Initialize-KeybindingService {
    [CmdletBinding()]
    param(
        [ActionService]$ActionService = $null
    )
    
    $kbService = if ($ActionService) {
        [KeybindingService]::new($ActionService)
    } else {
        [KeybindingService]::new()
    }
    Write-Verbose "KeybindingService initialized"
    return $kbService
}

function Initialize-TuiFrameworkService {
    [CmdletBinding()]
    param()
    
    $framework = [TuiFrameworkService]::new()
    Write-Verbose "TuiFrameworkService initialized"
    return $framework
}

#endregion
