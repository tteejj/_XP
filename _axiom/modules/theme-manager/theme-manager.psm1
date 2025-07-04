# FILE: modules/theme-manager.psm1
# PURPOSE: Provides advanced theming and color management for the TUI with truecolor support.

# ------------------------------------------------------------------------------
# Module-Scoped State Variables
# ------------------------------------------------------------------------------
# Stores the currently active theme (a hashtable defining its name and colors/styles).
$script:CurrentTheme = $null 

# Stores all predefined themes for backward compatibility
$script:BuiltinThemes = @{
    Modern = @{ Name="Modern"; Colors=@{ Background=[ConsoleColor]::Black; Foreground=[ConsoleColor]::White; Primary=[ConsoleColor]::White; Secondary=[ConsoleColor]::Gray; Accent=[ConsoleColor]::Cyan; Success=[ConsoleColor]::Green; Warning=[ConsoleColor]::Yellow; Error=[ConsoleColor]::Red; Info=[ConsoleColor]::Blue; Header=[ConsoleColor]::Cyan; Border=[ConsoleColor]::DarkGray; Selection=[ConsoleColor]::Yellow; Highlight=[ConsoleColor]::Cyan; Subtle=[ConsoleColor]::DarkGray; Keyword=[ConsoleColor]::Blue; String=[ConsoleColor]::Green; Number=[ConsoleColor]::Magenta; Comment=[ConsoleColor]::DarkGray } }
    Dark   = @{ Name="Dark"; Colors=@{ Background=[ConsoleColor]::Black; Foreground=[ConsoleColor]::Gray; Primary=[ConsoleColor]::Gray; Secondary=[ConsoleColor]::DarkGray; Accent=[ConsoleColor]::DarkCyan; Success=[ConsoleColor]::DarkGreen; Warning=[ConsoleColor]::DarkYellow; Error=[ConsoleColor]::DarkRed; Info=[ConsoleColor]::DarkBlue; Header=[ConsoleColor]::DarkCyan; Border=[ConsoleColor]::DarkGray; Selection=[ConsoleColor]::Yellow; Highlight=[ConsoleColor]::Cyan; Subtle=[ConsoleColor]::DarkGray; Keyword=[ConsoleColor]::DarkBlue; String=[ConsoleColor]::DarkGreen; Number=[ConsoleColor]::DarkMagenta; Comment=[ConsoleColor]::DarkGray } }
    Light  = @{ Name="Light"; Colors=@{ Background=[ConsoleColor]::White; Foreground=[ConsoleColor]::Black; Primary=[ConsoleColor]::Black; Secondary=[ConsoleColor]::DarkGray; Accent=[ConsoleColor]::Blue; Success=[ConsoleColor]::Green; Warning=[ConsoleColor]::DarkYellow; Error=[ConsoleColor]::Red; Info=[ConsoleColor]::Blue; Header=[ConsoleColor]::Blue; Border=[ConsoleColor]::Gray; Selection=[ConsoleColor]::Cyan; Highlight=[ConsoleColor]::Yellow; Subtle=[ConsoleColor]::Gray; Keyword=[ConsoleColor]::Blue; String=[ConsoleColor]::Green; Number=[ConsoleColor]::Magenta; Comment=[ConsoleColor]::Gray } }
    Retro  = @{ Name="Retro"; Colors=@{ Background=[ConsoleColor]::Black; Foreground=[ConsoleColor]::Green; Primary=[ConsoleColor]::Green; Secondary=[ConsoleColor]::DarkGreen; Accent=[ConsoleColor]::Yellow; Success=[ConsoleColor]::Green; Warning=[ConsoleColor]::Yellow; Error=[ConsoleColor]::Red; Info=[ConsoleColor]::Cyan; Header=[ConsoleColor]::Yellow; Border=[ConsoleColor]::DarkGreen; Selection=[ConsoleColor]::Yellow; Highlight=[ConsoleColor]::White; Subtle=[ConsoleColor]::DarkGreen; Keyword=[ConsoleColor]::Yellow; String=[ConsoleColor]::Cyan; Number=[ConsoleColor]::White; Comment=[ConsoleColor]::DarkGreen } }
}

# External themes directory for advanced JSON themes
$script:ExternalThemesDirectory = $null

# ------------------------------------------------------------------------------
# Private Helper Functions
# ------------------------------------------------------------------------------

# Resolves a color value, supporting both ConsoleColor enums and hex strings
function _Resolve-ThemeColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $ColorValue,
        
        [hashtable]$Palette = @{}
    )
    
    # Handle palette reference (starts with $)
    if ($ColorValue -is [string] -and $ColorValue.StartsWith('$')) {
        $paletteKey = $ColorValue.Substring(1)
        if ($Palette.ContainsKey($paletteKey)) {
            return $Palette[$paletteKey]
        } else {
            Write-Warning "Palette key '$paletteKey' not found in theme palette."
            return "#FF00FF" # Magenta as error indicator
        }
    }
    
    # Return as-is (ConsoleColor enum or hex string)
    return $ColorValue
}

# Validates if a string is a valid hex color
function _Test-HexColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$HexColor
    )
    
    return $HexColor -match '^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$'
}

# ------------------------------------------------------------------------------
# Public Functions
# ------------------------------------------------------------------------------

function Initialize-ThemeManager {
    <#
    .SYNOPSIS
    Initializes the theme manager, setting the default theme and external themes directory.
    #>
    [CmdletBinding()]
    param(
        [string]$ExternalThemesDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\Themes")
    )

    # Wrap the core logic in Invoke-WithErrorHandling for application-wide error consistency.
    Invoke-WithErrorHandling -Component "ThemeManager.Initialize" -Context "Initializing theme service" -ScriptBlock {
        # Set up external themes directory
        $script:ExternalThemesDirectory = $ExternalThemesDirectory
        if (-not (Test-Path $script:ExternalThemesDirectory)) {
            try {
                New-Item -ItemType Directory -Path $script:ExternalThemesDirectory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "ThemeManager: Created external themes directory: $script:ExternalThemesDirectory"
            } catch {
                Write-Warning "ThemeManager: Could not create external themes directory: $($_.Exception.Message). External themes will not be available."
                $script:ExternalThemesDirectory = $null
            }
        }
        
        # Attempt to set the default theme.
        Set-TuiTheme -ThemeName "Modern"
        
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "Theme manager initialized." -Data @{
                ExternalThemesDirectory = $script:ExternalThemesDirectory
                BuiltinThemes = ($script:BuiltinThemes.Keys -join ', ')
            }
        }
        Write-Verbose "ThemeManager: Successfully initialized."
    }
}

function Set-TuiTheme {
    <#
    .SYNOPSIS
    Sets the active theme for the TUI.
    .PARAMETER ThemeName
    The name of the theme to activate. Can be a builtin theme or external JSON theme.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ThemeName
    )

    if ($PSCmdlet.ShouldProcess("theme '$ThemeName'", "Set active theme")) {
        Invoke-WithErrorHandling -Component "ThemeManager.SetTheme" -Context "Setting active TUI theme" -AdditionalData @{ ThemeName = $ThemeName } -ScriptBlock {
            $themeFound = $false
            
            # Try builtin themes first
            if ($script:BuiltinThemes.ContainsKey($ThemeName)) {
                $script:CurrentTheme = $script:BuiltinThemes[$ThemeName]
                $themeFound = $true
                Write-Verbose "ThemeManager: Loaded builtin theme '$ThemeName'."
            }
            # Try external JSON themes
            elseif ($script:ExternalThemesDirectory) {
                $themePath = Join-Path $script:ExternalThemesDirectory "$ThemeName.theme.json"
                if (Test-Path $themePath) {
                    try {
                        $themeContent = Get-Content $themePath -Raw | ConvertFrom-Json -AsHashtable
                        
                        # Validate advanced theme structure
                        if ($themeContent.ContainsKey('palette') -and $themeContent.ContainsKey('styles')) {
                            # Advanced theme format
                            $script:CurrentTheme = @{
                                Name = $ThemeName
                                Type = 'Advanced'
                                Palette = $themeContent.palette
                                Styles = $themeContent.styles
                            }
                        } elseif ($themeContent.ContainsKey('Colors')) {
                            # Simple theme format (backward compatibility)
                            $script:CurrentTheme = @{
                                Name = $ThemeName
                                Type = 'Simple'
                                Colors = $themeContent.Colors
                            }
                        } else {
                            throw "Invalid theme format. Theme must contain 'Colors' or both 'palette' and 'styles' keys."
                        }
                        
                        $themeFound = $true
                        Write-Verbose "ThemeManager: Loaded external theme '$ThemeName' from '$themePath'."
                    } catch {
                        throw "Failed to load external theme '$ThemeName': $($_.Exception.Message)"
                    }
                }
            }
            
            if ($themeFound) {
                # Apply console colors for immediate effect if it's a simple theme
                if ($script:CurrentTheme.Type -ne 'Advanced' -and $Host.UI.RawUI) {
                    $bgColor = Get-ThemeColor -ColorName 'Background' -Default ([ConsoleColor]::Black)
                    $fgColor = Get-ThemeColor -ColorName 'Foreground' -Default ([ConsoleColor]::White)
                    
                    if ($bgColor -is [ConsoleColor]) { $Host.UI.RawUI.BackgroundColor = $bgColor }
                    if ($fgColor -is [ConsoleColor]) { $Host.UI.RawUI.ForegroundColor = $fgColor }
                    Write-Verbose "ThemeManager: Applied console colors for theme '$ThemeName'."
                }
                
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Debug -Message "Theme set to: $ThemeName"
                }
                
                # Publish an event so other components can react to theme changes.
                if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
                    Publish-Event -EventName "Theme.Changed" -Data @{ ThemeName = $ThemeName; Theme = $script:CurrentTheme }
                }
                Write-Verbose "ThemeManager: Theme '$ThemeName' activated and 'Theme.Changed' event published."
            } else {
                # Theme not found
                $availableThemes = Get-AvailableThemes
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Warning -Message "Theme not found: $ThemeName. Available themes: $($availableThemes -join ', '). Active theme remains unchanged."
                }
                Write-Verbose "ThemeManager: Theme '$ThemeName' not found."
            }
        }
    }
}

function Get-ThemeColor {
    <#
    .SYNOPSIS
    Retrieves a specific color from the currently active theme.
    .PARAMETER ColorName
    The name of the color to retrieve (e.g., "Background", "Accent") or style path for advanced themes.
    .PARAMETER Default
    A default value to return if the specified color name is not found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ColorName,
        
        $Default = [ConsoleColor]::Gray
    )
    
    try {
        if ($null -eq $script:CurrentTheme) {
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Warning -Message "No active theme set. Returning default color for '$ColorName'."
            }
            Write-Verbose "ThemeManager: No active theme, returning default color '$Default' for '$ColorName'."
            return $Default
        }
        
        # Handle different theme types
        if ($script:CurrentTheme.Type -eq 'Advanced') {
            # Advanced theme with styles and palette
            $styleValue = $script:CurrentTheme.Styles.$ColorName
            if ($null -ne $styleValue) {
                $resolvedColor = _Resolve-ThemeColor -ColorValue $styleValue -Palette $script:CurrentTheme.Palette
                Write-Verbose "ThemeManager: Retrieved advanced style '$ColorName' as '$resolvedColor'."
                return $resolvedColor
            }
        } else {
            # Simple theme or builtin theme
            $colors = $script:CurrentTheme.Colors
            if ($colors -and $colors.ContainsKey($ColorName)) {
                $color = $colors[$ColorName]
                Write-Verbose "ThemeManager: Retrieved color '$ColorName' as '$color'."
                return $color
            }
        }
        
        # Color not found, return default
        Write-Verbose "ThemeManager: Color '$ColorName' not found in current theme, returning default '$Default'."
        return $Default
    } catch {
        # Log any unexpected errors during color retrieval.
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Warning -Message "Error in Get-ThemeColor for '$ColorName'. Returning default '$Default'. Error: $($_.Exception.Message)"
        }
        Write-Verbose "ThemeManager: Failed to get color '$ColorName', returning default. Error: $($_.Exception.Message)."
        return $Default
    }
}

function Get-TuiTheme {
    <#
    .SYNOPSIS
    Gets the currently active theme configuration.
    #>
    [CmdletBinding()]
    param()

    Invoke-WithErrorHandling -Component "ThemeManager.GetTheme" -Context "Retrieving current theme" -ScriptBlock {
        Write-Verbose "ThemeManager: Retrieving current theme."
        return $script:CurrentTheme
    }
}

function Get-AvailableThemes {
    <#
    .SYNOPSIS
    Gets a list of names of all available themes (builtin and external).
    #>
    [CmdletBinding()]
    param()

    Invoke-WithErrorHandling -Component "ThemeManager.GetAvailableThemes" -Context "Retrieving available themes" -ScriptBlock {
        $themes = [System.Collections.Generic.List[string]]::new()
        
        # Add builtin themes
        $themes.AddRange($script:BuiltinThemes.Keys)
        
        # Add external themes
        if ($script:ExternalThemesDirectory -and (Test-Path $script:ExternalThemesDirectory)) {
            $externalThemes = Get-ChildItem -Path $script:ExternalThemesDirectory -Filter "*.theme.json" -ErrorAction SilentlyContinue | 
                ForEach-Object { $_.BaseName -replace '\.theme$' }
            $themes.AddRange($externalThemes)
        }
        
        Write-Verbose "ThemeManager: Found $($themes.Count) available themes."
        return $themes.ToArray() | Sort-Object -Unique
    }
}

function New-TuiTheme {
    <#
    .SYNOPSIS
    Creates a new custom theme, optionally based on an existing theme.
    .PARAMETER Name
    The unique name for the new theme.
    .PARAMETER BaseTheme
    Optional. The name of an existing theme to use as a base.
    .PARAMETER Colors
    A hashtable specifying custom colors for the theme.
    .PARAMETER Palette
    A hashtable defining color palette for advanced themes.
    .PARAMETER Styles
    A hashtable defining style mappings for advanced themes.
    .PARAMETER Force
    If specified, an existing theme with the same name will be overwritten without warning.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [string]$BaseTheme = "Modern",
        
        [hashtable]$Colors = @{},
        
        [hashtable]$Palette = @{},
        
        [hashtable]$Styles = @{},
        
        [switch]$Force
    )

    if ($PSCmdlet.ShouldProcess("new theme '$Name'", "Create or update theme")) {
        Invoke-WithErrorHandling -Component "ThemeManager.NewTheme" -Context "Creating new theme" -AdditionalData @{ ThemeName = $Name } -ScriptBlock {
            # Check if theme already exists
            $existingThemes = Get-AvailableThemes
            if ($Name -in $existingThemes) {
                if (-not $Force) {
                    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Warning -Message "Theme '$Name' already exists. Use -Force to overwrite."
                    }
                    Write-Verbose "ThemeManager: Cannot create theme '$Name'. It already exists and -Force was not used."
                    return $null
                } else {
                    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Info -Message "Overwriting existing theme: $Name"
                    }
                    Write-Verbose "ThemeManager: Overwriting theme '$Name' due to -Force."
                }
            }

            # Create theme based on type
            if ($Palette.Count -gt 0 -or $Styles.Count -gt 0) {
                # Advanced theme
                $newTheme = @{
                    Name = $Name
                    palette = $Palette
                    styles = $Styles
                }
                
                # If no base palette/styles, start with empty
                if ($Palette.Count -eq 0) { $newTheme.palette = @{} }
                if ($Styles.Count -eq 0) { $newTheme.styles = @{} }
            } else {
                # Simple theme
                $newTheme = @{ Name = $Name; Colors = @{} }

                # Copy colors from base theme if specified and exists
                if ($script:BuiltinThemes.ContainsKey($BaseTheme)) {
                    $newTheme.Colors = $script:BuiltinThemes[$BaseTheme].Colors.Clone()
                    Write-Verbose "ThemeManager: New theme '$Name' based on builtin '$BaseTheme'."
                } elseif ($BaseTheme -ne "Modern") {
                    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Warning -Message "Base theme '$BaseTheme' not found for new theme '$Name'. Starting with empty color set."
                    }
                    Write-Verbose "ThemeManager: Base theme '$BaseTheme' not found."
                }
                
                # Apply custom colors
                foreach ($colorKey in $Colors.Keys) {
                    $colorValue = $Colors[$colorKey]
                    # Validate color value
                    if ($colorValue -is [System.ConsoleColor] -or (_Test-HexColor -HexColor $colorValue)) {
                        $newTheme.Colors[$colorKey] = $colorValue
                    } else {
                        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                            Write-Log -Level Warning -Message "Invalid color value '$colorValue' for '$colorKey' in theme '$Name'. Must be a ConsoleColor enum or valid hex color."
                        }
                    }
                }
            }
            
            # Save theme to external directory if available
            if ($script:ExternalThemesDirectory) {
                try {
                    $themePath = Join-Path $script:ExternalThemesDirectory "$Name.theme.json"
                    $newTheme | ConvertTo-Json -Depth 3 | Set-Content -Path $themePath -Encoding UTF8 -Force
                    Write-Verbose "ThemeManager: Saved theme '$Name' to '$themePath'."
                } catch {
                    Write-Warning "ThemeManager: Failed to save theme '$Name' to file: $($_.Exception.Message)"
                }
            }
            
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Info -Message "Created new theme: $Name"
            }
            Write-Verbose "ThemeManager: Theme '$Name' created successfully."
            return $newTheme
        }
    }
    return $null
}

function Export-TuiTheme {
    <#
    .SYNOPSIS
    Exports a theme's definition to a JSON file.
    .PARAMETER ThemeName
    The name of the theme to export.
    .PARAMETER Path
    The file path where the JSON definition will be saved.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ThemeName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if ($PSCmdlet.ShouldProcess("theme '$ThemeName' to '$Path'", "Export theme")) {
        Invoke-WithErrorHandling -Component "ThemeManager.ExportTheme" -Context "Exporting theme to JSON" -AdditionalData @{ ThemeName = $ThemeName; FilePath = $Path } -ScriptBlock {
            $theme = $null
            
            # Find theme (builtin or external)
            if ($script:BuiltinThemes.ContainsKey($ThemeName)) {
                $theme = $script:BuiltinThemes[$ThemeName]
            } elseif ($script:ExternalThemesDirectory) {
                $themePath = Join-Path $script:ExternalThemesDirectory "$ThemeName.theme.json"
                if (Test-Path $themePath) {
                    $theme = Get-Content $themePath -Raw | ConvertFrom-Json -AsHashtable
                }
            }
            
            if ($theme) {
                $exportTheme = @{}
                
                # Handle different theme formats
                if ($theme.ContainsKey('Colors')) {
                    # Simple theme format
                    $exportTheme = @{ Name = $theme.Name; Colors = @{} }
                    foreach ($colorKey in $theme.Colors.Keys) {
                        $exportTheme.Colors[$colorKey] = $theme.Colors[$colorKey].ToString()
                    }
                } else {
                    # Advanced theme format or copy as-is
                    $exportTheme = $theme.Clone()
                }
                
                # Ensure the directory exists before writing the file.
                $directory = Split-Path -Path $Path -Parent
                if (-not (Test-Path $directory)) {
                    New-Item -ItemType Directory -Path $directory -Force | Out-Null
                    Write-Verbose "ThemeManager: Created directory '$directory' for export."
                }

                $exportTheme | ConvertTo-Json -Depth 3 | Set-Content -Path $Path -Encoding UTF8 -Force
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Info -Message "Exported theme '$ThemeName' to: $Path"
                }
                Write-Verbose "ThemeManager: Theme '$ThemeName' successfully exported to '$Path'."
            } else {
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Warning -Message "Cannot export theme. Theme not found: $ThemeName"
                }
                Write-Verbose "ThemeManager: Theme '$ThemeName' not found for export."
            }
        }
    }
}

function Import-TuiTheme {
    <#
    .SYNOPSIS
    Imports a theme definition from a JSON file.
    .PARAMETER Path
    The file path of the JSON theme definition.
    .PARAMETER Force
    If specified, an existing theme with the same name will be overwritten without warning.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        
        [switch]$Force
    )

    if ($PSCmdlet.ShouldProcess("theme from '$Path'", "Import theme")) {
        Invoke-WithErrorHandling -Component "ThemeManager.ImportTheme" -Context "Importing theme from JSON" -AdditionalData @{ FilePath = $Path } -ScriptBlock {
            if (-not (Test-Path $Path)) {
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Warning -Message "Cannot import theme. File not found: $Path"
                }
                Write-Verbose "ThemeManager: Import failed. File not found: '$Path'."
                return $null
            }
            
            try {
                $importedThemeData = Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable
                
                if (-not $importedThemeData.ContainsKey('Name')) {
                    throw "Invalid theme file format. Missing 'Name' property."
                }

                $themeName = $importedThemeData.Name
                $existingThemes = Get-AvailableThemes

                if ($themeName -in $existingThemes) {
                    if (-not $Force) {
                        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                            Write-Log -Level Warning -Message "Theme '$themeName' already exists. Use -Force to overwrite."
                        }
                        Write-Verbose "ThemeManager: Cannot import theme '$themeName'. It already exists and -Force was not used."
                        return $null
                    } else {
                        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                            Write-Log -Level Info -Message "Overwriting existing theme: $themeName (from import)."
                        }
                        Write-Verbose "ThemeManager: Overwriting theme '$themeName' due to -Force."
                    }
                }

                # Save to external themes directory
                if ($script:ExternalThemesDirectory) {
                    $targetPath = Join-Path $script:ExternalThemesDirectory "$themeName.theme.json"
                    $importedThemeData | ConvertTo-Json -Depth 3 | Set-Content -Path $targetPath -Encoding UTF8 -Force
                }

                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Info -Message "Imported theme: $themeName"
                }
                Write-Verbose "ThemeManager: Theme '$themeName' imported successfully from '$Path'."
                return $importedThemeData
            }
            catch {
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Error -Message "Failed to import theme from '$Path': $($_.Exception.Message)"
                }
                throw # Re-throw to propagate error for Invoke-WithErrorHandling
            }
        }
    }
    return $null
}

# ------------------------------------------------------------------------------
# Module Export
# ------------------------------------------------------------------------------
# Export all public functions to make them available when the module is imported.
Export-ModuleMember -Function Initialize-ThemeManager, Set-TuiTheme, Get-ThemeColor, Get-TuiTheme, Get-AvailableThemes, New-TuiTheme, Export-TuiTheme, Import-TuiTheme
