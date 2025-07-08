



#--- START OF MERGED AND REFACTORED FILE ---

# Project Management Console - V8 Enhanced (Phase 4 - PSStyle Integration)

# Target: PowerShell 7.2+ (Tested on 7.5) on Windows (Windows Terminal Recommended)

# Based on V8 Enhanced Phase 3, Integrated with PSStyle Theming Proof-of-Concept

 

#region Configuration & Globals

 

# --- Determine Script Root ---

if ($PSScriptRoot) {

    $scriptRoot = $PSScriptRoot

} else {

    try {

        $scriptRoot = (Get-Location -ErrorAction Stop).Path

        Write-Warning "Could not determine script root ($PSScriptRoot). Using current directory '$scriptRoot'. Config/Data paths may be relative to this."

    } catch {

        Write-Error "FATAL: Could not determine script root or current location. Exiting."

        Read-Host "Press Enter to exit."

        exit 1

    }

}

$Global:DefaultDataSubDir = "_ProjectData" # Subdirectory for data/config relative to script root

 

# --- PSStyle Check ---

if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 2)) {

    Write-Error "FATAL: This script requires PowerShell 7.2 or later for PSStyle support. You have $($PSVersionTable.PSVersion)."

    Read-Host "Press Enter to exit."

    exit 1

}

# Ensure ANSI rendering is enabled (usually default in modern terminals, but can be explicit)

# $PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::Ansi # Or 'Host'

 

# --- PSStyle ANSI Reset ---

# Use PSStyle's built-in Reset

$global:ansiReset = $PSStyle.Reset # Kept mainly for compatibility during merge, direct PSStyle.Reset is preferred

 

# --- Default Configuration (Used if config.json is missing/invalid) ---

# --- Default Configuration (Used if config.json is missing/invalid) ---
Function Get-DefaultConfig {
    param([string]$BaseDir) # Pass script root to function
    $dataDir = Join-Path -Path $BaseDir -ChildPath $Global:DefaultDataSubDir
    return @{
        projectsFile          = Join-Path -Path $dataDir -ChildPath "projects_todos.json"
        timeTrackingFile      = Join-Path -Path $dataDir -ChildPath "timetracking.csv"
        commandsFolder        = Join-Path -Path $dataDir -ChildPath "Commands"
        logFilePath           = Join-Path -Path $dataDir -ChildPath "pmc_log_psstyle.txt" # Updated log name
        caaTemplatePath       = "C:\Path\To\Your\Master\CAA Template.xlsm" # <<< USER MUST EDIT IN SCRIPT OR CONFIG.JSON
        defaultTheme          = "SynthwaveSunset" # Changed default for testing
        displayDateFormat     = "yyyy-MM-dd"
        logMaxSizeMB          = 1 # Max log file size before rotation
        # >>> ADDED for new timesheet function <<<
        tempTimesheetCsvPath  = Join-Path -Path $BaseDir -ChildPath "_temp_timesheet.csv" # Path for temporary formatted timesheet
    }
}

# --- Table Configuration (Structure remains the same, added FormattedTimesheet) ---
$global:tableConfig = @{
    BorderStyle = @{ TopLeft = "┌"; TopRight = "┐"; BottomLeft = "└"; BottomRight = "┘"; Horizontal = "─"; Vertical = "│"; LeftJoin = "├"; RightJoin = "┤"; TopJoin = "┬"; BottomJoin = "┴"; Cross = "┼" } # Fallback
    Columns = @{
        Projects            = @( @{Title="ID2"; Width=10}, @{Title="Full Name"; Width=30}, @{Title="Assigned"; Width=10}, @{Title="Due"; Width=10}, @{Title="BF"; Width=10}, @{Title="Status"; Width=10}, @{Title="Hrs"; Width=6}, @{Title="Latest Todo"; Width=25} )
        ProjectSelection    = @( @{Title="#"; Width=3}, @{Title="ID2"; Width=12}, @{Title="Full Name"; Width=40}, @{Title="Status"; Width=15} )
        ProjectInfoDetail   = @( @{Title="Field"; Width=15}, @{Title="Value"; Width=55} )
        ProjectTodos        = @( @{Title="ID"; Width=4}, @{Title="Task"; Width=45}, @{Title="Due Date"; Width=10}, @{Title="Priority"; Width=8}, @{Title="Status"; Width=10} )
        TodoSelection       = @( @{Title="#"; Width=3}, @{Title="Task"; Width=45}, @{Title="Status"; Width=10}, @{Title="Due"; Width=10}, @{Title="Priority"; Width=8} )
        TimeSheet           = @( @{Title="Date"; Width=10}, @{Title="ID2/Task"; Width=20}, @{Title="Hours"; Width=6}, @{Title="Description"; Width=40} )
        Commands            = @( @{Title="Name"; Width=30}, @{Title="Description"; Width=60} )
        CommandSelection    = @( @{Title="#"; Width=3}, @{Title="Name"; Width=30}, @{Title="Description"; Width=60} )
        NoteSelection       = @( @{Title="#"; Width=3}, @{Title="Filename"; Width=50}, @{Title="Modified"; Width=19} )
        Dashboard           = @( @{Title="#"; Width=3}, @{Title="ID2"; Width=10}, @{Title="Name"; Width=60}, @{Title="BF Date"; Width=10}, @{Title="Latest Todo"; Width=42} )
        Todos               = @( @{Title="ID"; Width=4}, @{Title="Task"; Width=35}, @{Title="Project"; Width=10}, @{Title="Due"; Width=10}, @{Title="Priority"; Width=8}, @{Title="Status"; Width=10} )
        # >>> ADDED for new timesheet function <<<
        FormattedTimesheet  = @( @{Title="ID1"; Width=10}, @{Title="ID2"; Width=20}, @{Title=""; Width=1}, @{Title=""; Width=1}, @{Title=""; Width=1}, @{Title=""; Width=1}, @{Title="Mon"; Width=5}, @{Title="Tue"; Width=5}, @{Title="Wed"; Width=5}, @{Title="Thu"; Width=5}, @{Title="Fri"; Width=5} )
    }
}

 

# --- Global AppConfig Variable (populated by Load-AppConfig) ---

$Global:AppConfig = $null

 

# --- Centralized Excel Mappings (Keep as is from v8) ---

$global:excelMappings = @{

    Extraction = @( @{ Type = 'Label'; Source = 'Project Name:'; TargetVariable = 'FullName'; OffsetColumn = 1 }, @{ Type = 'Label'; Source = 'Client ID:'; TargetVariable = 'ClientID'; OffsetColumn = 1 }, @{ Type = 'Label'; Source = 'Address:'; TargetVariable = 'Address1'; OffsetColumn = 1 }, @{ Type = 'Label'; Source = 'Address:'; TargetVariable = 'Address2'; OffsetColumn = 1; OffsetRow = 1 }, @{ Type = 'Label'; Source = 'Address:'; TargetVariable = 'Address3'; OffsetColumn = 1; OffsetRow = 2 }, @{ Type = 'Label'; Source = 'Description:'; TargetVariable = 'Description'; OffsetColumn = 1 }, @{ Type = 'Fixed'; Source = 'X3'; TargetVariable = 'FullName' }, @{ Type = 'Fixed'; Source = 'X5'; TargetVariable = 'ClientID' }, @{ Type = 'Fixed'; Source = 'X7'; TargetVariable = 'Address1' }, @{ Type = 'Fixed'; Source = 'X8'; TargetVariable = 'Address2' }, @{ Type = 'Fixed'; Source = 'X9'; TargetVariable = 'Address3' }, @{ Type = 'Fixed'; Source = 'X11'; TargetVariable = 'Description' } );

    Copying = @( @{ Type = 'LabelToLabel'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'Project Name:'; Destination = 'Project Name:'; OffsetColumn = 1 }, @{ Type = 'LabelToLabel'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'Client ID:'; Destination = 'Client ID:'; OffsetColumn = 1 }, @{ Type = 'LabelToLabel'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'Address:'; Destination = 'Address:'; OffsetColumn = 1 }, @{ Type = 'LabelToLabel'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'Description:'; Destination = 'Description:'; OffsetColumn = 1 }, @{ Type = 'Range'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'X3:X18'; Destination = 'V21' }, @{ Type = 'Range'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'X23:X25'; Destination = 'V41' }, @{ Type = 'Range'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'X27:X38'; Destination = 'V45' }, @{ Type = 'Range'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'X54:X63'; Destination = 'V72' }, @{ Type = 'Range'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'X72'; Destination = 'V90' }, @{ Type = 'Range'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'X78'; Destination = 'V96' }, @{ Type = 'Range'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'X98:X108'; Destination = 'V116' }, @{ Type = 'Range'; SourceSheet = 'SVI-CAS'; DestinationSheet = 'Information'; Source = 'X110:X136'; Destination = 'V128' } );

    StaticEntries = @( @{ DestinationSheet = 'Information'; Destination = 'I191'; Value = 'John Heninger' }, @{ DestinationSheet = 'Information'; Destination = 'I192'; Value = 'userid' }, @{ DestinationSheet = 'Information'; Destination = 'I193'; Value = 'phone#' } );

}

 

# --- Constants ---

$global:DATE_FORMAT_INTERNAL = "yyyyMMdd" # For internal calculations/storage

 

# --- Border Styles Definition (Using Box Drawing Characters) ---

$Global:borderStyles = @{

    "Single"    = @{ TopLeft="┌"; TopRight="┐"; BottomLeft="└"; BottomRight="┘"; Horizontal="─"; Vertical="│"; LeftJoin="├"; RightJoin="┤"; TopJoin="┬"; BottomJoin="┴"; Cross="┼" }

    "Double"    = @{ TopLeft="╔"; TopRight="╗"; BottomLeft="╚"; BottomRight="╝"; Horizontal="═"; Vertical="║"; LeftJoin="╠"; RightJoin="╣"; TopJoin="╦"; BottomJoin="╩"; Cross="╬" }

    "Rounded"   = @{ TopLeft="╭"; TopRight="╮"; BottomLeft="╰"; BottomRight="╯"; Horizontal="─"; Vertical="│"; LeftJoin="├"; RightJoin="┤"; TopJoin="┬"; BottomJoin="┴"; Cross="┼" }

    "HeavyLine" = @{ TopLeft="┏"; TopRight="┓"; BottomLeft="┗"; BottomRight="┛"; Horizontal="━"; Vertical="┃"; LeftJoin="┣"; RightJoin="┫"; TopJoin="┳"; BottomJoin="┻"; Cross="╋" }

    "Block"     = @{ TopLeft="█"; TopRight="█"; BottomLeft="█"; BottomRight="█"; Horizontal="█"; Vertical="█"; LeftJoin="█"; RightJoin="█"; TopJoin="█"; BottomJoin="█"; Cross="█" }

    "ASCII"     = @{ TopLeft="+"; TopRight="+"; BottomLeft="+"; BottomRight="+"; Horizontal="-"; Vertical="|"; LeftJoin="+"; RightJoin="+"; TopJoin="+"; BottomJoin="+" ; Cross="+" }

    "None"      = @{ TopLeft=" "; TopRight=" "; BottomLeft=" "; BottomRight=" "; Horizontal=" "; Vertical=" "; LeftJoin=" "; RightJoin=" "; TopJoin=" "; BottomJoin=" "; Cross=" " }

}

 

 

 

 

 

# --- Table Configuration (Structure remains the same) ---

$global:tableConfig = @{

    BorderStyle = @{ TopLeft = "┌"; TopRight = "┐"; BottomLeft = "└"; BottomRight = "┘"; Horizontal = "─"; Vertical = "│"; LeftJoin = "├"; RightJoin = "┤"; TopJoin = "┬"; BottomJoin = "┴"; Cross = "┼" } # Fallback

    Columns = @{

        Projects            = @( @{Title="ID2"; Width=10}, @{Title="Full Name"; Width=30}, @{Title="Assigned"; Width=10}, @{Title="Due"; Width=10}, @{Title="BF"; Width=10}, @{Title="Status"; Width=10}, @{Title="Hrs"; Width=6}, @{Title="Latest Todo"; Width=25} )

        ProjectSelection    = @( @{Title="#"; Width=3}, @{Title="ID2"; Width=12}, @{Title="Full Name"; Width=40}, @{Title="Status"; Width=15} )

        ProjectInfoDetail   = @( @{Title="Field"; Width=15}, @{Title="Value"; Width=55} )

        ProjectTodos        = @( @{Title="ID"; Width=4}, @{Title="Task"; Width=45}, @{Title="Due Date"; Width=10}, @{Title="Priority"; Width=8}, @{Title="Status"; Width=10} )

        TodoSelection       = @( @{Title="#"; Width=3}, @{Title="Task"; Width=45}, @{Title="Status"; Width=10}, @{Title="Due"; Width=10}, @{Title="Priority"; Width=8} )

        TimeSheet           = @( @{Title="Date"; Width=10}, @{Title="ID2/Task"; Width=20}, @{Title="Hours"; Width=6}, @{Title="Description"; Width=40} )

        Commands            = @( @{Title="Name"; Width=30}, @{Title="Description"; Width=60} )

        CommandSelection    = @( @{Title="#"; Width=3}, @{Title="Name"; Width=30}, @{Title="Description"; Width=60} )

        NoteSelection       = @( @{Title="#"; Width=3}, @{Title="Filename"; Width=50}, @{Title="Modified"; Width=19} )

        Dashboard           = @( @{Title="#"; Width=3}, @{Title="ID2"; Width=10}, @{Title="Name"; Width=60}, @{Title="BF Date"; Width=10}, @{Title="Latest Todo"; Width=42} ) # Added Dashboard layout

        Todos               = @( @{Title="ID"; Width=4}, @{Title="Task"; Width=35}, @{Title="Project"; Width=10}, @{Title="Due"; Width=10}, @{Title="Priority"; Width=8}, @{Title="Status"; Width=10} ) # For Schedule View

    }

}

 

# --- Quick Action Map (Remains the same, defined later) ---



 

#region Logging Functions (Keep PMCV8iv version)

function Write-AppLog {

    param(

        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")][string]$Level = "INFO"

    )

    # Handle case where config isn't loaded yet (first run)

    if ($null -eq $Global:AppConfig) {

        Write-Warning "[PRE-LOG] [$Level] $Message"

        return

    }

 

    $logPath = $Global:AppConfig.logFilePath

    $maxSizeBytes = ($Global:AppConfig.logMaxSizeMB * 1MB)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $logLine = "$timestamp [$Level] $Message"

 

    try {

        # Ensure directory exists

        $logDir = Split-Path -Path $logPath -Parent

        if (-not (Test-Path $logDir)) {

            try {

                New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop | Out-Null

                # Recursive call OK here as config is loaded now

                Write-AppLog "Created log directory: $logDir" "INFO"

            } catch {

                Write-Warning "!!! Failed to create log directory '$logDir': $($_.Exception.Message) !!! Cannot write log."

                return

            }

        }

 

        # Check log size and rotate if needed

        if (Test-Path $logPath) {

            $logSize = (Get-Item $logPath).Length

            if ($logSize -ge $maxSizeBytes) {

                $backupLogPath = "$logPath.1"

                if (Test-Path $backupLogPath) { Remove-Item $backupLogPath -Force -ErrorAction SilentlyContinue }

                try {

                    Move-Item -Path $logPath -Destination $backupLogPath -Force -ErrorAction Stop

                    Write-AppLog "Log rotated. Previous log: $backupLogPath" "INFO" # Log to new file

                } catch {

                    Write-Warning "!!! Failed to rotate log file '$logPath': $($_.Exception.Message) !!!"

                    # Continue logging to the oversized file if rotation fails

                }

            }

        }

 

        # Append to log file

        Add-Content -Path $logPath -Value $logLine -Encoding UTF8 -ErrorAction Stop

 

    } catch {

        # Fallback to console if logging fails

        Write-Warning "!!! Error writing to log file '$logPath': $($_.Exception.Message) !!!"

        Write-Warning "Log Entry: $logLine"

    }

}

 

function Handle-Error {

    param(

        [Parameter(Mandatory = $true)]$ErrorRecord,

        [string]$Context = "General Operation"

    )

    $errMsg = $ErrorRecord.Exception.Message

    $fullErrMsg = "Error in $Context`: $errMsg"

    # Try to log the error

    Write-AppLog -Message "$fullErrMsg`nStackTrace: $($ErrorRecord.ScriptStackTrace)" -Level ERROR

    # Show simplified error to user using the themed function

    # Ensure Show-Error is defined before calling it here if order matters

    # If Show-Error might not be defined yet (e.g., during initial load), fallback

    if (Get-Command 'Show-Error' -ErrorAction SilentlyContinue) {

         Show-Error -Message $fullErrMsg

    } else {

         Write-Warning "DISPLAY ERROR: $fullErrMsg" # Basic fallback

    }

}

#endregion

 

 

#region Theme Loading Function (UPDATED FOR JSON)

function Load-ThemesFromFiles {

    Write-AppLog "Attempting to load themes from JSON files..." "INFO"

    $global:themes = @{} # Reset global themes dictionary

    $themesDir = Join-Path -Path $scriptRoot -ChildPath "Themes"

 

    if (-not (Test-Path $themesDir -PathType Container)) {

        Write-AppLog "Themes directory '$themesDir' not found. Creating..." "WARN"

        try {

            New-Item -Path $themesDir -ItemType Directory -Force -ErrorAction Stop | Out-Null

            Write-AppLog "Created Themes directory. You may need to add default .theme.json files." "INFO"

        } catch {

            Handle-Error $_ "Creating Themes directory '$themesDir'"

            return # Proceed without themes, fallback handled later

        }

    }

 

    # Look for .theme.json files now

    $themeFiles = Get-ChildItem -Path $themesDir -Filter "*.theme.json" -File -ErrorAction SilentlyContinue

    if ($null -eq $themeFiles -or $themeFiles.Count -eq 0) {

        Write-AppLog "No '.theme.json' files found in '$themesDir'." "WARN"

        return # Fallback handled later

    }

 

    Write-AppLog "Found $($themeFiles.Count) potential theme JSON files." "INFO"

    foreach ($file in $themeFiles) {

        $themeKey = $file.BaseName # e.g., "NeonGradientBlue_PSStyle" (filename without .theme.json)

        Write-AppLog "Loading theme '$themeKey' from '$($file.Name)'..." "DEBUG"

        try {

            # Read the JSON content and convert to PowerShell Hashtable

            $themeObject = Get-Content -Path $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop

 

            if ($themeObject -is [hashtable]) {

                # Basic validation

                if (-not $themeObject.ContainsKey('Name') -or -not $themeObject.ContainsKey('Palette')) {

                    Write-AppLog "Theme '$themeKey' from '$($file.Name)' is missing 'Name' or 'Palette'. Skipping." "WARN"

                    continue

                }

                $Global:themes[$themeKey] = $themeObject

                Write-AppLog "Successfully loaded theme '$themeKey'." "INFO"

            } else {

                # Should not happen with ConvertFrom-Json unless file is invalid JSON

                 Write-AppLog "File '$($file.Name)' did not evaluate to a Hashtable for theme '$themeKey'. Check JSON validity. Skipping." "WARN"

            }

        } catch {

            Handle-Error $_ "Loading theme JSON file '$($file.FullName)'"

        }

    }

    Write-AppLog "Finished loading themes. Found $($Global:themes.Count) valid themes." "INFO"

}

#endregion

 

 

 

 

#region Configuration Management Functions (Keep PMCV8iv versions, Ensure-DirectoryExists uses Handle-Error)

function Ensure-DirectoryExists {

    param([string]$DirectoryPath)

    if (-not (Test-Path $DirectoryPath -PathType Container)) {

        try {

            New-Item -Path $DirectoryPath -ItemType Directory -Force -EA Stop | Out-Null

            Write-AppLog "Created directory: $DirectoryPath" "INFO"

            return $true

        } catch {

            # Use Handle-Error to show themed error and log

            Handle-Error $_ "Creating directory '$DirectoryPath'"

            return $false

        }

    }

    return $true

}

 

#region Main Application Loop

 

 

 

 

 

function Load-AppConfig {

    $configDir = Join-Path $scriptRoot $Global:DefaultDataSubDir

    $configPath = Join-Path $configDir 'config.json'

    $defaultConfig = Get-DefaultConfig -BaseDir $scriptRoot

 

    # --- Fallback Theme Selection ---

    # This logic runs AFTER Load-ThemesFromFiles has populated $Global:themes

    # Define the desired primary fallback theme key (must match a filename without extension)

    $primaryFallbackThemeKey = "NeonGradientBlue_PSStyle"

    $finalFallbackThemeKey = "" # This will hold the key of the theme that WILL be used if the configured one fails

 

    if ($Global:themes.ContainsKey($primaryFallbackThemeKey)) {

        # Primary fallback exists, use it if needed

        $finalFallbackThemeKey = $primaryFallbackThemeKey

        Write-AppLog "Primary fallback theme '$primaryFallbackThemeKey' is available." "DEBUG"

    } else {

        # Primary fallback theme file not found or failed to load.

        Write-AppLog "Primary fallback theme '$primaryFallbackThemeKey' not found/loaded." "WARN"

        $availableThemes = $Global:themes.Keys

        if ($availableThemes.Count -gt 0) {

            # Use the first available theme from the loaded ones

            $finalFallbackThemeKey = $availableThemes | Select -First 1

            Write-AppLog "Using first available loaded theme as fallback: '$finalFallbackThemeKey'." "WARN"

        } else {

            # This is the absolute last resort - no themes were loaded at all.

            # Start-ProjectManagement should have created a minimal theme.

            $finalFallbackThemeKey = "FallbackMinimal" # Key name used in Start-ProjectManagement's emergency creation

            Write-AppLog "CRITICAL: No themes loaded. Using hardcoded minimal fallback '$finalFallbackThemeKey'." "ERROR"

            # Ensure the minimal fallback actually exists in the themes dictionary

            if (-not $Global:themes.ContainsKey($finalFallbackThemeKey)) {

                 Write-Error "FATAL: Minimal fallback theme '$finalFallbackThemeKey' is missing. Cannot proceed."

                 # Optionally create it again here, though it indicates a deeper issue

                 # $Global:themes['FallbackMinimal'] = @{ Name = "Fallback (Minimal)"; Palette = @{...}; ... }

                 Read-Host "Press Enter to exit."

                 exit 1 # Cannot function without any theme data

            }

        }

    }

    # At this point, $finalFallbackThemeKey holds a valid key present in $Global:themes

 

    # --- Ensure Config Directory ---

    if (-not (Ensure-DirectoryExists -DirectoryPath $configDir)) {

        # Error handled by Ensure-DirectoryExists

        Write-Warning "Using temporary defaults as config directory failed." # Additional info

        $Global:AppConfig = $defaultConfig

        # Attempt to load a default theme even with temp config

        # Use the determined fallback theme since config loading failed before theme selection could occur

        $global:currentThemeName = $finalFallbackThemeKey

        $global:currentTheme = $global:themes[$global:currentThemeName]

        Write-AppLog "Using fallback theme '$finalFallbackThemeKey' due to config directory failure." "WARN"

        return

    }

 

    # --- Load or Create config.json ---

    if (Test-Path $configPath) {

        Write-AppLog "Loading config from $configPath" "INFO"

        try {

            $loadedConfig = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable -EA Stop

            # Merge loaded config over defaults to ensure all keys exist

            $mergedConfig = $defaultConfig.Clone()

            foreach ($key in $loadedConfig.Keys) {

                 if ($mergedConfig.ContainsKey($key)) {

                    $mergedConfig[$key] = $loadedConfig[$key]

                 } else {

                     Write-AppLog "Config key '$key' found in json but not in defaults. Adding." "DEBUG"

                     $mergedConfig[$key] = $loadedConfig[$key]

                 }

            }

            # Validate specific paths from loaded config if needed (e.g., caaTemplatePath)

            $Global:AppConfig = $mergedConfig

            Write-AppLog "Config loaded successfully." "INFO"

        } catch {

            Handle-Error $_ "Loading/Parsing config.json"

            Write-AppLog "Using default config due to load error." "WARN"

            $Global:AppConfig = $defaultConfig

        }

    } else {

        Write-AppLog "Config file not found. Creating default: $configPath" "INFO"

        # Set the default theme in the config TO BE CREATED to the determined fallback

        $defaultConfig.defaultTheme = $finalFallbackThemeKey

        $Global:AppConfig = $defaultConfig

        try {

            $Global:AppConfig | ConvertTo-Json -Depth 5 | Out-File $configPath -Encoding UTF8 -Force -EA Stop

            # Use themed messages if possible

            if (Get-Command 'Show-Warning' -ErrorAction SilentlyContinue) {

                 Show-Warning "Default config file created: '$configPath'"

                 Show-Warning ">>> REVIEW/EDIT '$configPath', especially 'caaTemplatePath', AND RESTART <<<"

            } else {

                 Write-Warning "Default config file created: '$configPath'"

                 Write-Warning ">>> REVIEW/EDIT '$configPath', especially 'caaTemplatePath', AND RESTART <<<"

            }

             if (Get-Command 'Pause-Screen' -ErrorAction SilentlyContinue) {

                 Pause-Screen "Press Enter after reviewing config.json..."

             } else {

                 Read-Host "Press Enter after reviewing config.json..."

             }

        } catch {

            Handle-Error $_ "Saving default config.json"

            # Show-Error might not be loaded yet

            Write-Error "Could not save default config file. Using temporary defaults."

            # Config is already set to defaults, theme will use fallback below

        }

    }

 

    # --- Set the Current Theme based on Loaded Config ---

    $configuredThemeName = $Global:AppConfig.defaultTheme

 

    if ($Global:themes.ContainsKey($configuredThemeName)) {

        # Configured theme exists in the loaded themes - use it.

        $global:currentThemeName = $configuredThemeName

        Write-AppLog "Theme set to '$configuredThemeName' from config." "INFO"

    } else {

        # Configured theme NOT found among loaded themes. Use the final determined fallback.

        Write-AppLog "Configured theme '$configuredThemeName' not found in loaded themes. Falling back to '$finalFallbackThemeKey'." "WARN"

        $global:currentThemeName = $finalFallbackThemeKey

        $Global:AppConfig.defaultTheme = $global:currentThemeName # Update config in memory to reflect the fallback

    }

    # Set the current theme object

    $global:currentTheme = $global:themes[$global:currentThemeName]

    Write-AppLog "Current theme object set to '$($global:currentTheme.Name)'." "INFO"

}

 

 

function Save-AppConfig {

    if ($null -eq $Global:AppConfig) {

        Write-AppLog "Save-AppConfig called before config was loaded." "ERROR"

        return $false

    }

    $configDir = Join-Path $scriptRoot $Global:DefaultDataSubDir

    $configPath = Join-Path $configDir 'config.json'

 

    if (-not (Ensure-DirectoryExists -DirectoryPath $configDir)) {

        # Error already shown by Ensure-DirectoryExists via Handle-Error

        return $false

    }

 

    Write-AppLog "Saving config to $configPath" "INFO"

    try {

        # Backup existing config before overwriting

        if (Test-Path $configPath) {

            $backupPath = "$configPath.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"

            Copy-Item -Path $configPath -Destination $backupPath -Force -ErrorAction SilentlyContinue # Best effort backup

            Write-AppLog "Backed up existing config to $backupPath" "DEBUG"

        }

        # Save the current config state

        $Global:AppConfig | ConvertTo-Json -Depth 5 | Out-File $configPath -Encoding UTF8 -Force -EA Stop

        Write-AppLog "Config saved successfully." "INFO"

        return $true

    } catch {

        Handle-Error $_ "Saving config.json"

        return $false

    }

}

 

function Configure-Settings {

    Clear-Host

    Draw-Title "CONFIGURE SETTINGS"

    if ($null -eq $Global:AppConfig) { Show-Error "Config not loaded."; Pause-Screen; return }

 

    Show-Info "Current settings. Press Enter to keep current value."

    $originalConfig = $Global:AppConfig.Clone() # Keep a copy to revert if cancelled

    $configChanged = $false

 

    # Get Paths

    $newProjectsFile = Get-InputWithPrompt "Projects JSON Path" $Global:AppConfig.projectsFile

    if ($newProjectsFile -ne $Global:AppConfig.projectsFile) { $Global:AppConfig.projectsFile = $newProjectsFile; $configChanged = $true }

 

    $newTimeFile = Get-InputWithPrompt "Time Tracking CSV Path" $Global:AppConfig.timeTrackingFile

    if ($newTimeFile -ne $Global:AppConfig.timeTrackingFile) { $Global:AppConfig.timeTrackingFile = $newTimeFile; $configChanged = $true }

 

    $newCommandsFolder = Get-InputWithPrompt "Commands Folder Path" $Global:AppConfig.commandsFolder

    if ($newCommandsFolder -ne $Global:AppConfig.commandsFolder) { $Global:AppConfig.commandsFolder = $newCommandsFolder; $configChanged = $true }

 

    $newLogFile = Get-InputWithPrompt "Log File Path" $Global:AppConfig.logFilePath

    if ($newLogFile -ne $Global:AppConfig.logFilePath) { $Global:AppConfig.logFilePath = $newLogFile; $configChanged = $true }

 

    $newCaaTemplate = Get-InputWithPrompt "CAA Master Template Path" $Global:AppConfig.caaTemplatePath

    if ($newCaaTemplate -ne $Global:AppConfig.caaTemplatePath) { $Global:AppConfig.caaTemplatePath = $newCaaTemplate; $configChanged = $true }

 

    # Get Display Format

    $newDateFormat = Get-InputWithPrompt "Display Date Format (e.g., yyyy-MM-dd)" $Global:AppConfig.displayDateFormat

    if ($newDateFormat -ne $Global:AppConfig.displayDateFormat) { $Global:AppConfig.displayDateFormat = $newDateFormat; $configChanged = $true }

 

    # Get Log Size

    $newLogSize = Get-InputWithPrompt "Max Log Size (MB)" $Global:AppConfig.logMaxSizeMB

    if ($newLogSize -match '^\d+$' -and [int]$newLogSize -ge 1 -and [int]$newLogSize -ne $Global:AppConfig.logMaxSizeMB) {

         $Global:AppConfig.logMaxSizeMB = [int]$newLogSize

         $configChanged = $true

    } elseif ($newLogSize -ne $Global:AppConfig.logMaxSizeMB) {

        Show-Warning "Invalid log size, keeping current ($($Global:AppConfig.logMaxSizeMB) MB)."

    }

 

 

    # Select Theme

    $theme = $global:currentTheme

    $availableThemes = $global:themes.Keys | Sort-Object

    Write-Host ""

    # Use Apply-PSStyle for header

    Write-Host (Apply-PSStyle -Text "Available Themes:" -FG (Get-PSStyleValue $theme "Menu.Header.FG"))

    $themeMap = @{}

    for ($i = 0; $i -lt $availableThemes.Count; $i++) {

        $themeName = $availableThemes[$i]

        $displayName = $global:themes[$themeName].Name

        # Use Apply-PSStyle for options

        Write-Host (Apply-PSStyle -Text "$($i + 1). $displayName" -FG (Get-PSStyleValue $theme "Menu.Option.FG"))

        $themeMap[$i + 1] = $themeName

    }

    # Use Apply-PSStyle for cancel/keep option

    Write-Host (Apply-PSStyle -Text " 0. Keep Current ($($Global:AppConfig.defaultTheme))" -FG (Get-PSStyleValue $theme "Palette.WarningFG"))

 

    $choice = Get-NumericChoice -Prompt "Select theme number" -MinValue 0 -MaxValue $availableThemes.Count -CancelOption "" # Don't show cancel in prompt

 

    if ($choice -ne $null -and $choice -ne 0 -and $themeMap.ContainsKey($choice)) {

        $selectedThemeKey = $themeMap[$choice]

        if ($selectedThemeKey -ne $Global:AppConfig.defaultTheme) {

            $Global:AppConfig.defaultTheme = $selectedThemeKey

            $configChanged = $true

            # Update current theme immediately for visual feedback if needed

            $global:currentThemeName = $selectedThemeKey

            $global:currentTheme = $global:themes[$selectedThemeKey]

            Show-Info "Theme selection updated to: $($global:currentTheme.Name)"

        }

    } elseif ($choice -eq 0) {

        Show-Info "Keeping current theme."

    } elseif ($choice -ne $null) { # Only show error if a choice was made but invalid

        Show-Warning "Invalid theme choice entered."

    } # If $choice is null, Get-NumericChoice already handled it (or user entered non-numeric)

 

    # Save or Discard Changes

    if ($configChanged) {

        Write-Host ""

        $confirmSave = Confirm-ActionNumeric -ActionDescription "Save these settings?"

        if ($confirmSave -eq $true) {

            if (Save-AppConfig) {

                Show-Success "Settings saved successfully."

            } else {

                Show-Error "FAILED TO SAVE settings. Reverting changes in memory."

                $Global:AppConfig = $originalConfig # Revert in-memory config

                # Also revert theme if it was changed in memory

                $global:currentThemeName = $originalConfig.defaultTheme

                $global:currentTheme = $global:themes[$global:currentThemeName]

            }

        } else {

            Write-AppLog "Settings configuration cancelled by user." "INFO"

            Show-Warning "Changes discarded."

            $Global:AppConfig = $originalConfig # Revert in-memory config

            $global:currentThemeName = $originalConfig.defaultTheme

            $global:currentTheme = $global:themes[$global:currentThemeName]

        }

    } else {

        Show-Info "No changes were made."

    }

    Pause-Screen

 

##~~~~added

    # In main PMC script (e.g., during Load-AppConfig or Initialize)

    $mappingFilePath = Join-Path $scriptRoot "excel_mappings.json" # Or get path from config

    if (Test-Path $mappingFilePath) {

        try {

            $Global:excelMappings = Get-Content $mappingFilePath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable -ErrorAction Stop

            Write-AppLog "Loaded Excel mappings from $mappingFilePath" "INFO"

            # Basic validation

            if ($null -eq $Global:excelMappings -or

                -not $Global:excelMappings.ContainsKey('Extraction') -or

                -not $Global:excelMappings.ContainsKey('Copying') -or

                -not $Global:excelMappings.ContainsKey('StaticEntries')) {

                 throw "Invalid structure in excel_mappings.json"

            }

             # Ensure arrays (optional but safe)

            if($Global:excelMappings.Extraction -isnot [array]){ $Global:excelMappings.Extraction = @($Global:excelMappings.Extraction) }

            if($Global:excelMappings.Copying -isnot [array]){ $Global:excelMappings.Copying = @($Global:excelMappings.Copying) }

            if($Global:excelMappings.StaticEntries -isnot [array]){ $Global:excelMappings.StaticEntries = @($Global:excelMappings.StaticEntries) }

        } catch {

             Handle-Error $_ "Loading excel_mappings.json"

             # Decide fallback: Use hardcoded defaults? Error out?

             Write-Error "FATAL: Could not load or parse Excel mappings. Using default/empty mappings."

             $Global:excelMappings = @{ Extraction = @(); Copying = @(); StaticEntries = @() } # Minimal fallback

        }

    } else {

        Write-Error "FATAL: Excel mapping file not found: $mappingFilePath"

        # Decide fallback

        $Global:excelMappings = @{ Extraction = @(); Copying = @(); StaticEntries = @() }

    }

 

}

#endregion

 

#region PSStyle Theme Helper Functions

 

# Get-ThemeProperty (Using the more robust version from PMCV8iv, handles $Palette refs)

function Get-ThemeProperty {

    param(

        [Parameter(Mandatory=$true)][hashtable]$ResolvedTheme,

        [Parameter(Mandatory=$true)][string]$PropertyPath,

        [object]$DefaultValue=$null,

        [ValidateSet("Color","Background","String","Boolean","Hashtable","Array","Integer","Any")][string]$ExpectedType="Any"

    )

 

    # Property name mapping (Example: allow older names if needed during transition)

    $propertyMappings = @{

        # Maps older/alternate names to the names used in $ui_DefaultStructure_PSStyle

        'WindowTitle.ForegroundColor'       = 'WindowTitle.FG'; 'WindowTitle.BackgroundColor'     = 'WindowTitle.BG'

        'WindowTitle.Border.ForegroundColor'= 'WindowTitle.Border.FG'; 'Menu.SectionHeader.ForegroundColor'= 'Menu.Header.FG'

        'Menu.SectionHeader.BackgroundColor'='Menu.Header.BG'; 'Menu.OptionLine.ForegroundColor'   = 'Menu.Option.FG'

        'Menu.OptionLine.BackgroundColor' = 'Menu.Option.BG'; 'Menu.OptionLine.NumberColor'     = 'Menu.Option.NumColor'

        'Menu.OptionLine.NumberFormat'    = 'Menu.Option.NumFormat'; 'Menu.OptionLine.Indent'        = 'Menu.Option.Indent'

        'Menu.InfoLine.ForegroundColor'     = 'Menu.Info.FG'; 'Menu.InfoLine.BackgroundColor'   = 'Menu.Info.BG'

        'DataTable.BorderForegroundColor' = 'DataTable.BorderFG'; 'DataTable.ColumnPadding'         = 'DataTable.Pad'

        'DataTable.Header.ForegroundColor'  = 'DataTable.Header.FG'; 'DataTable.Header.BackgroundColor'  = 'DataTable.Header.BG'

        'DataTable.Header.TextCase'       = 'DataTable.Header.Case'; 'DataTable.DataRow.ForegroundColor' = 'DataTable.DataRow.FG'

        'DataTable.DataRow.BackgroundColor' = 'DataTable.DataRow.BG'; 'DataTable.AlternateRow'          = 'DataTable.AltRow'

        'DataTable.AlternateRow.ForegroundColor' = 'DataTable.AltRow.FG'; 'DataTable.AlternateRow.BackgroundColor' = 'DataTable.AltRow.BG'

        'DataTable.HighlightRow'          = 'DataTable.Highlight'; 'InputControl.Prompt.ForegroundColor' = 'InputControl.Prompt.FG'

        'InputControl.DefaultValue.ForegroundColor' = 'InputControl.Default.FG'; 'InputControl.UserInput.ForegroundColor'  = 'InputControl.UserInput.FG'

        'StatusMessage.Types.Success.ForegroundColor' = 'StatusMessage.Types.Success.FG'; 'StatusMessage.Types.Success.BackgroundColor' = 'StatusMessage.Types.Success.BG'

        'StatusMessage.Types.Error.ForegroundColor' = 'StatusMessage.Types.Error.FG'; 'StatusMessage.Types.Error.BackgroundColor' = 'StatusMessage.Types.Error.BG'

        'StatusMessage.Types.Warning.ForegroundColor' = 'StatusMessage.Types.Warning.FG'; 'StatusMessage.Types.Warning.BackgroundColor' = 'StatusMessage.Types.Warning.BG'

        'StatusMessage.Types.Info.ForegroundColor' = 'StatusMessage.Types.Info.FG'; 'StatusMessage.Types.Info.BackgroundColor' = 'StatusMessage.Types.Info.BG'

    }

 

    if ($propertyMappings.ContainsKey($PropertyPath)) {

        $originalPath = $PropertyPath

        $PropertyPath = $propertyMappings[$PropertyPath]

        Write-AppLog "Mapped theme property '$originalPath' to '$PropertyPath'" "DEBUG"

    }

 

    $currentValue = $ResolvedTheme

    $pathSegments = $PropertyPath.Split('.')

 

    foreach($segment in $pathSegments) {

        if ($currentValue -is [hashtable] -and $currentValue.ContainsKey($segment)) {

            $currentValue = $currentValue[$segment]

        } else {

            Write-AppLog "Theme property path not found: '$PropertyPath' (segment: '$segment'). Using default." "DEBUG"

            return $DefaultValue

        }

    }

 

    # Resolve Palette References (including nested)

    while ($currentValue -is [string] -and $currentValue.StartsWith('$Palette:')) {

        $paletteKey = $currentValue.Substring(9)

        if ($ResolvedTheme.Palette -is [hashtable] -and $ResolvedTheme.Palette.ContainsKey($paletteKey)) {

            $resolvedValue = $ResolvedTheme.Palette[$paletteKey]

            Write-AppLog "Resolved palette ref '$currentValue' to '$resolvedValue' for '$PropertyPath'." "DEBUG"

            $currentValue = $resolvedValue # Continue loop in case of nested refs

        } else {

            Write-AppLog "Palette key '$paletteKey' not found for '$PropertyPath'. Using default." "WARN"

            return $DefaultValue

        }

    }

 

    # Type Validation (Simplified for PSStyle where colors are strings/null)

    if ($ExpectedType -ne "Any") {

        $typeMatch = $false

        switch ($ExpectedType) {

            "Color"      { $typeMatch = ($currentValue -is [string] -or $null -eq $currentValue) } # Expect Hex string or null

            "Background" { $typeMatch = ($currentValue -is [string] -or $null -eq $currentValue) } # Expect Hex string or null

            "String"     { $typeMatch = ($currentValue -is [string]) }

            "Boolean"    { $typeMatch = ($currentValue -is [bool]) }

            "Hashtable"  { $typeMatch = ($currentValue -is [hashtable]) }

            "Array"      { $typeMatch = ($currentValue -is [array]) }

            "Integer"    { $typeMatch = ($currentValue -is [int] -or $currentValue -is [long]) } # Accept Int32 or Int64

        }

 

        if (-not $typeMatch) {

            $actualType = if ($null -eq $currentValue) { "null" } else { $currentValue.GetType().Name }

            Write-AppLog "Theme property '$PropertyPath' type mismatch. Expected '$ExpectedType', got '$actualType'. Using default." "WARN"

            return $DefaultValue

        }

    }

 

    return $currentValue

}

 

# Helper to get $PSStyle object/string from theme property (Handles Hex, $null, named colors)

Function Get-PSStyleValue {

    param(

        [hashtable]$ThemeObject, # The specific theme hash (e.g., $Global:themes.NeonGradientBlue_PSStyle)

        [string]$PropertyPath,  # e.g., "WindowTitle.FG", "Palette.ErrorBG"

        [string]$DefaultColor = "#FFFFFF", # Default color as Hex

        [ValidateSet("Foreground", "Background")][string]$StyleType = "Foreground" # Specify if FG or BG is needed

    )

 

    # Use Get-ThemeProperty to safely retrieve the configured value (Hex, $null, or Palette Ref resolved)

    $value = Get-ThemeProperty $ThemeObject $PropertyPath $null "Any" # Get raw value first

 

    # If Get-ThemeProperty returned null or empty string, use the default hex

    if ([string]::IsNullOrEmpty($value)) {

        $value = $DefaultColor

    }

 

    # Handle $null specifically - means "no style" / reset for that layer

    if ($null -eq $value) { return "" }

 

    # Check if it's an RGB Hex value

    if ($value -is [string] -and $value -match '^#([A-Fa-f0-9]{6})$') {

        try {

            $r = [System.Convert]::ToInt32($matches[1].Substring(0, 2), 16)

            $g = [System.Convert]::ToInt32($matches[1].Substring(2, 2), 16)

            $b = [System.Convert]::ToInt32($matches[1].Substring(4, 2), 16)

 

            # Construct the appropriate PSStyle RGB object string

            if ($StyleType -eq "Foreground") {

                return $PSStyle.Foreground.FromRgb($r, $g, $b)

            } else { # Background

                return $PSStyle.Background.FromRgb($r, $g, $b)

            }

        } catch {

            Write-AppLog "Invalid RGB Hex '$value' for '$PropertyPath'. Using default '$DefaultColor'." "WARN"

            # Fallback to default if conversion fails

            $value = $DefaultColor # Try processing the default

            if ($value -match '^#([A-Fa-f0-9]{6})$') {

                 $r = [System.Convert]::ToInt32($matches[1].Substring(0, 2), 16)

                 $g = [System.Convert]::ToInt32($matches[1].Substring(2, 2), 16)

                 $b = [System.Convert]::ToInt32($matches[1].Substring(4, 2), 16)

                 if ($StyleType -eq "Foreground") { return $PSStyle.Foreground.FromRgb($r, $g, $b) }

                 else { return $PSStyle.Background.FromRgb($r, $g, $b) }

            } else {

                 return "" # Cannot parse default either

            }

        }

    }

 

     # Check if it's a named PSStyle color (case-insensitive)

    if ($value -is [string]) {

         $lowerValue = $value.ToLower()

         if ($StyleType -eq "Foreground") {

             $fgProp = $PSStyle.Foreground.PSObject.Properties | Where-Object { $_.Name -eq $lowerValue }

             if ($fgProp) { Write-AppLog "Matched named FG color: $lowerValue" "DEBUG"; return $PSStyle.Foreground.$($fgProp.Name) }

         } else { # Background

             $bgProp = $PSStyle.Background.PSObject.Properties | Where-Object { $_.Name -eq $lowerValue }

             if ($bgProp) { Write-AppLog "Matched named BG color: $lowerValue" "DEBUG"; return $PSStyle.Background.$($bgProp.Name) }

             # Allow specifying background via "OnColor" convention too

             $onProp = $PSStyle.Background.PSObject.Properties | Where-Object { $_.Name -eq "on$lowerValue" }

             if ($onProp) { Write-AppLog "Matched named BG 'On' color: on$lowerValue" "DEBUG"; return $PSStyle.Background.$($onProp.Name) }

         }

    }

 

    # If it's not a recognized format, return empty string (no style)

    Write-AppLog "Unrecognized PSStyle value '$value' for '$PropertyPath'. Applying no style." "DEBUG"

    return ""

}

 

# Helper to apply FG/BG styles using PSStyle objects/strings

Function Apply-PSStyle {

    param(

        [string]$Text,

        # Parameters now expect the PSStyle object/string as returned by Get-PSStyleValue

        [string]$FG = "", # e.g., $PSStyle.Foreground.Red or $PSStyle.Foreground.FromRgb(...)

        [string]$BG = ""  # e.g., $PSStyle.Background.OnBlue or $PSStyle.Background.FromRgb(...)

    )

    # Simple concatenation, relies on Get-PSStyleValue providing valid PSStyle sequences

    # If FG or BG is empty string (""), it adds nothing.

    # Ensure Reset is always applied at the end.

    return "$FG$BG$Text$($PSStyle.Reset)"

}

 

# Helper to get border chars

function Get-BorderStyleChars {

    param([string]$StyleName)

    if ($Global:borderStyles.ContainsKey($StyleName)) {

        return $Global:borderStyles[$StyleName]

    } else {

        Write-AppLog "Border style '$StyleName' not found. Falling back to 'Single'." "WARN"

        return $Global:borderStyles["Single"]

    }

}

#endregion

 

#region JSON Data Handling Functions (Copied from PMCV8iv - No changes needed)

# --- ENHANCED Load-ProjectTodoJson: More Robust Array Handling ---
function Load-ProjectTodoJson {
    $filePath = $Global:AppConfig.projectsFile
    if (-not (Test-Path $FilePath)) { Write-AppLog "Project file not found: $filePath" "INFO"; return @() }
    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8 -EA Stop
        if ([string]::IsNullOrWhiteSpace($content)) { Write-AppLog "Project file empty: $filePath" "WARN"; return @() }

        # Attempt to convert from JSON
        $jsonData = $content | ConvertFrom-Json -ErrorAction Stop

        # Ensure $jsonData is always treated as an array, even if JSON contained a single root object
        $dataArray = @($jsonData)

        $processedData = foreach ($proj in $dataArray) {
            # Work with the current project object
            $currentProject = $proj

            # --- Robust Todos Handling ---
            if (-not $currentProject.PSObject.Properties.Name.Contains('Todos')) {
                # Add the Todos property if it doesn't exist at all
                $currentProject | Add-Member -MemberType NoteProperty -Name 'Todos' -Value @() -Force
                 Write-AppLog "Project '$($currentProject.ID2)' missing Todos property. Added empty array." "DEBUG"
            } elseif ($null -eq $currentProject.Todos) {
                # Set Todos to an empty array if it exists but is null
                $currentProject.Todos = @()
                 Write-AppLog "Project '$($currentProject.ID2)' Todos property was null. Reset to empty array." "DEBUG"
            } elseif ($currentProject.Todos -isnot [array]) {
                # >>> CRITICAL FIX: Convert to array if it exists but isn't one <<<
                 Write-AppLog "Project '$($currentProject.ID2)' Todos property was not an array ($($currentProject.Todos.GetType().Name)). Converting to array." "DEBUG"
                $currentProject.Todos = @($currentProject.Todos)
            }
            # --- End Robust Todos Handling ---

            # Optional: Ensure nested Todos are PSCustomObjects (less critical now with robust handling above)
            if ($currentProject.Todos -is [array]) {
                $currentProject.Todos = @($currentProject.Todos | ForEach-Object {
                    if ($_ -is [hashtable]) { [PSCustomObject]$_ } else { $_ }
                })
            }

            $currentProject # Output the processed object
        }
        return $processedData
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Loading/Parsing Projects JSON '$filePath'"
        return @() # Return empty array on error
    }
}

function Save-ProjectTodoJson { param([Parameter(Mandatory=$true)][array]$ProjectData); $filePath = $Global:AppConfig.projectsFile; $backupPath = "$filePath.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"; try { if (Test-Path $FilePath) { Copy-Item -Path $FilePath -Destination $backupPath -Force -EA SilentlyContinue }; $ProjectData | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8 -Force -EA Stop; Write-AppLog "Saved project data to $filePath" "INFO"; return $true } catch { Handle-Error -ErrorRecord $_ -Context "Saving Projects JSON '$filePath'"; if (Test-Path -LiteralPath $backupPath) { try { Copy-Item -Path $backupPath -Destination $filePath -Force -EA Stop; Write-AppLog "Restored backup $backupPath due to save error." "WARN" } catch { Handle-Error -ErrorRecord $_ -Context "Restoring backup $backupPath" } }; return $false } }

#endregion

 

#region Dynamic Hour Calculation (Copied from PMCV8iv - No changes needed)

function Get-ProjectHoursMapByID2 { $hoursMap = @{}; $timeEntries = Get-CsvDataSafely -FilePath $Global:AppConfig.timeTrackingFile; if ($null -eq $timeEntries -or $timeEntries.Count -eq 0) { return $hoursMap }; if ($timeEntries.Count -gt 0 -and (-not $timeEntries[0].PSObject.Properties.Name.Contains('ID2') -or -not $timeEntries[0].PSObject.Properties.Name.Contains('Hours'))) { Write-AppLog "Time tracking CSV missing ID2/Hours columns." "ERROR"; Show-Error "Time tracking CSV missing 'ID2' or 'Hours'."; return $hoursMap }; foreach ($entry in $timeEntries) { $id2 = $entry.ID2; if ([string]::IsNullOrWhiteSpace($id2) -or $id2 -ieq "CUSTOM") { continue }; $hoursValue = 0.0; if (-not ([double]::TryParse($entry.Hours, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$hoursValue))) { $entryDateStr = if($entry.PSObject.Properties.Name.Contains('Date')) {$entry.Date} else {'?'}; Write-AppLog "Invalid hours '$($entry.Hours)' for ID2 '$id2' on date '$entryDateStr'." "WARN"; continue }; if ($hoursMap.ContainsKey($id2)) { $hoursMap[$id2] += $hoursValue } else { $hoursMap[$id2] = $hoursValue } }; return $hoursMap }

#endregion

 

#region UI Helper Functions (Using PSStyle versions)

 

function Draw-Title {

    param ([string]$Title)

 

    $theme = $global:currentTheme

    # Get styles first

    $titleFG = Get-PSStyleValue $theme "WindowTitle.FG" "#FFFFFF" "Foreground"

    $titleBG = Get-PSStyleValue $theme "WindowTitle.BG" $null "Background"

    $borderFG = Get-PSStyleValue $theme "WindowTitle.Border.FG" "#FFFFFF" "Foreground"

    $linesAbove = Get-ThemeProperty $theme "WindowTitle.LinesAbove" 1 "Integer"

    $linesBelow = Get-ThemeProperty $theme "WindowTitle.LinesBelow" 1 "Integer"

    $borderStyleName = Get-ThemeProperty $theme "WindowTitle.Border.Style" "Single" "String"

    $borderChars = Get-BorderStyleChars -StyleName $borderStyleName

    $width = 80; try { $width = $Host.UI.RawUI.WindowSize.Width - 1 } catch {}; if ($width -lt 10) { $width = 80 }

 

    # --- NEW: Check for Pre-rendered Blocky Title ---

    if ($Global:BlockyTitles.ContainsKey($Title)) {

        $blockyArt = $Global:BlockyTitles[$Title]

        # Optional: Draw borders around the blocky art

        $borderLineText = $borderChars.Horizontal * $width

        $borderLine = Apply-PSStyle -Text $borderLineText -FG $borderFG

 

        if ($linesAbove -gt 0) { Write-Host ("`n" * $linesAbove) } else { Write-Host "" }

        Write-Host $borderLine # Top border

        # Render the blocky art line by line, centered (approximately)

        $blockyArt.Split("`n") | ForEach-Object {

             $line = $_

             $padLength = $width - ($line | Measure-Object -Character).Count

             $leftPad = [Math]::Max(0, [Math]::Floor($padLength / 2))

             $paddedLine = (" " * $leftPad) + $line

             Write-Host (Apply-PSStyle -Text $paddedLine.PadRight($width) -FG $titleFG -BG $titleBG)

        }

        Write-Host $borderLine # Bottom border

        if ($linesBelow -gt 0) { Write-Host ("`n" * $linesBelow) } else { Write-Host "" }

        return # Exit function after displaying blocky art

    }

    # --- END NEW BLOCK ---

 

    # --- Original Draw-Title logic for standard text titles ---

    # Get other properties needed for standard text rendering

    $textCase = Get-ThemeProperty $theme "WindowTitle.TextCase" "Uppercase" "String"

    $padding = Get-ThemeProperty $theme "WindowTitle.Pad" 1 "Integer"

    $asciiArt = Get-ThemeProperty $theme "WindowTitle.AsciiArt" "" "String" # Standard ASCII art property

 

    # Handle standard ASCII Art (different from blocky title)

    if (-not [string]::IsNullOrEmpty($asciiArt)) {

        if ($linesAbove -gt 0) { Write-Host ("`n" * ($linesAbove -1)) }

        $asciiArt.Split("`n") | ForEach-Object { Write-Host (Apply-PSStyle -Text $_ -FG $titleFG -BG $titleBG) }

        if ($linesBelow -gt 0) { Write-Host ("`n" * $linesBelow) }

        return

    }

 

    # Standard Title Drawing (centering padded text between border chars)

    $borderLineText = $borderChars.Horizontal * $width

    $borderLine = Apply-PSStyle -Text $borderLineText -FG $borderFG

 

    $displayTitle = switch ($textCase.ToLower()) { "uppercase" { $Title.ToUpper() } default { $Title } }

    $paddedTitle = (" " * $padding) + $displayTitle + (" " * $padding)

    $plainPaddedTitleLength = ($paddedTitle | Measure-Object -Character).Count

    if ($plainPaddedTitleLength -gt $width) {

        $paddedTitle = $paddedTitle.Substring(0, $width - 4) + "... "

        $plainPaddedTitleLength = ($paddedTitle | Measure-Object -Character).Count

    }

 

    $paddingLength = $width - $plainPaddedTitleLength

    $leftPadChars = $borderChars.Horizontal * [Math]::Max(0, [Math]::Floor($paddingLength / 2))

    $rightPadChars = $borderChars.Horizontal * [Math]::Max(0, [Math]::Ceiling($paddingLength / 2))

    $titleLineContent = $leftPadChars + $paddedTitle + $rightPadChars

    if ($titleLineContent.Length -lt $width) {

        $titleLineContent += $borderChars.Horizontal * ($width - $titleLineContent.Length)

    } elseif ($titleLineContent.Length -gt $width) {

        $titleLineContent = $titleLineContent.Substring(0, $width)

    }

    $titleLine = Apply-PSStyle -Text $titleLineContent -FG $titleFG -BG $titleBG

 

    # Output standard title

    if ($linesAbove -gt 0) { Write-Host ("`n" * $linesAbove) } else { Write-Host "" }

    Write-Host $borderLine

    Write-Host $titleLine

    Write-Host $borderLine

    if ($linesBelow -gt 0) { Write-Host ("`n" * $linesBelow) } else { Write-Host "" }

}

 

function Get-InputWithPrompt {

    param (

        [string]$Prompt,

        [string]$DefaultValue = "",

        [switch]$ForceDefaultFormat = $false # Keep for date formatting

    )

    $theme = $global:currentTheme

    # Get PSStyle values

    $promptStyle = Get-PSStyleValue $theme "InputControl.Prompt.FG" "#FFFFFF" "Foreground"

    $defaultStyle = Get-PSStyleValue $theme "InputControl.Default.FG" "#808080" "Foreground"

    $userInputStyle = Get-PSStyleValue $theme "InputControl.UserInput.FG" "#FFFFFF" "Foreground"

    # Get text parts

    $promptSuffix = Get-ThemeProperty $theme "InputControl.Prompt.Suffix" ": " "String"

    $defaultPrefix = Get-ThemeProperty $theme "InputControl.Default.Prefix" " [" "String"

    $defaultSuffix = Get-ThemeProperty $theme "InputControl.Default.Suffix" "]" "String"

 

    # Construct styled prompt parts

    $promptText = Apply-PSStyle -Text $Prompt -FG $promptStyle # Apply style only to prompt text

    $defaultText = ""

    $displayDefault = $DefaultValue

    if ($DefaultValue) {

        # Apply date formatting if requested

        if ($ForceDefaultFormat -and $DefaultValue -match '^\d{8}$') {

            try { $displayDefault = [datetime]::ParseExact($DefaultValue, $global:DATE_FORMAT_INTERNAL, $null).ToString($global:AppConfig.displayDateFormat) } catch { $displayDefault = "$DefaultValue(err)" }

        } elseif ($ForceDefaultFormat -and $DefaultValue -match '^\d{4}-\d{2}-\d{2}$') {

             $displayDefault = $DefaultValue # Already in display format

        }

        # Apply style to the default value hint

        $defaultText = Apply-PSStyle -Text "$defaultPrefix$displayDefault$defaultSuffix" -FG $defaultStyle

    }

    $suffixText = Apply-PSStyle -Text $promptSuffix -FG $promptStyle # Style the suffix same as prompt

 

    # Write styled prompt (without user input style yet)

    Write-Host "$promptText$defaultText$suffixText" -NoNewline

 

    # Read-Host cannot be styled directly while typing with PSStyle

    # We can apply style *after* input is read if needed, but usually not desired.

    $input = Read-Host

    # No need for explicit ansiReset here as Apply-PSStyle includes it, and Read-Host resets.

 

    if ([string]::IsNullOrWhiteSpace($input) -and $DefaultValue -ne $null) {

        return $DefaultValue

    } else {

        # Return the trimmed input, user input styling happens implicitly via terminal defaults

        return $input.Trim()

    }

}

 

function Show-Message {

    param(

        [string]$Message,

        [ValidateSet("Success", "Error", "Warning", "Info")][string]$Type = "Info"

    )

    $theme = $global:currentTheme

    # Get the specific style info for the message type

    $styleInfo = Get-ThemeProperty $theme "StatusMessage.Types.$Type" $null "Hashtable"

    if ($null -eq $styleInfo) {

        Write-Warning "Theme missing StatusMessage definition for type '$Type'. Using basic output."

        Write-Host "[$Type] $Message"

        return

    }

 

    # Get PSStyle values for FG/BG from the styleInfo hashtable

    # Use fallback colors if specific keys are missing in the theme

    $styleFG = Get-PSStyleValue $styleInfo "FG" "#FFFFFF" "Foreground"

    $styleBG = Get-PSStyleValue $styleInfo "BG" $null "Background" # Default to no background

 

    # Get other properties

    $prefix = Get-ThemeProperty $styleInfo "Prefix" "[$($Type.ToUpper())] " "String"

    $fullWidthBG = Get-ThemeProperty $styleInfo "FullWidth" $false "Boolean" # Key used in PSStyle structure

 

    $consoleWidth = 80; try { $consoleWidth = $Host.UI.RawUI.WindowSize.Width } catch {};

    $fullMessage = "$prefix$Message"

 

    # Pad only if BG is set and fullWidth is true

    if ($styleBG -ne "" -and $fullWidthBG) {

        $plainTextLength = ($fullMessage | Measure-Object -Character).Count

        if ($plainTextLength -lt ($consoleWidth -1)) {

             $fullMessage = $fullMessage.PadRight($consoleWidth - 1)

        }

    }

 

    # Apply styles using Apply-PSStyle helper

    Write-Host (Apply-PSStyle -Text $fullMessage -FG $styleFG -BG $styleBG)

}

function Show-Success { param([string]$Message) Show-Message -Message $Message -Type Success }

function Show-Error   { param([string]$Message) Show-Message -Message $Message -Type Error   }

function Show-Warning { param([string]$Message) Show-Message -Message $Message -Type Warning }

function Show-Info    { param([string]$Message) Show-Message -Message $Message -Type Info    }

 

function Pause-Screen {

    param([string]$Message = "Press Enter to continue...")

    $theme = $global:currentTheme

    # Get secondary FG color for the pause message

    $pauseStyleFG = Get-PSStyleValue $theme "Palette.SecondaryFG" "#808080" "Foreground"

    # Get primary BG (or null)

    $pauseStyleBG = Get-PSStyleValue $theme "Palette.PrimaryBG" $null "Background"

 

    Write-Host "" # Ensure it's on a new line

    # Apply style to the message

    Write-Host (Apply-PSStyle -Text $Message -FG $pauseStyleFG -BG $pauseStyleBG) -NoNewline

    $null = Read-Host

    # No explicit reset needed after Read-Host typically

}

 

function Show-ExcelProgress { param( [string]$Activity = "Processing Excel Operation", [int]$PercentComplete = -1, [string]$Status = "", [int]$Current = 0, [int]$Total = 100, [switch]$Complete = $false, [int]$ID = 1 ); if ($Complete) { Write-Progress -Activity $Activity -Status "Complete" -PercentComplete 100 -Completed -Id $ID; return }; if ($PercentComplete -eq -1 -and $Total -gt 0) { $PercentComplete = [Math]::Min([Math]::Floor(($Current / $Total) * 100), 100) }; if ([string]::IsNullOrEmpty($Status) -and $Total -gt 0) { $Status = "Processing $Current of $Total items" }; $PercentComplete = [Math]::Max(0, [Math]::Min(100, $PercentComplete)); Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $ID }

#endregion

 

#region Table Function (Using PSStyle Version)

function Format-TableUnicode {

    param(

        [string]$ViewType,

        [array]$Data,

        [hashtable]$RowColors = @{} # Expects semantic keys ('Overdue', 'Selected') or cell-specific overrides {'_CELL_3' = 'DueSoon'}

    )

 

    $Data = @($Data) # Ensure $Data is always an array

    if (-not $global:tableConfig.Columns.ContainsKey($ViewType)) {

        Write-AppLog "Invalid ViewType for table: $ViewType" "ERROR"

        Show-Error "Invalid table ViewType specified: $ViewType"

        return

    }

 

    $theme = $global:currentTheme

    $columns = $global:tableConfig.Columns.$ViewType

 

    # --- Get Styles using PSStyle Helpers ---

    $borderStyleName = Get-ThemeProperty $theme "DataTable.BorderStyle" "Single" "String"

    $borderChars = Get-BorderStyleChars -StyleName $borderStyleName

    $borderStyle = Get-PSStyleValue $theme "DataTable.BorderFG" "#FFFFFF" "Foreground" # Get PSStyle string for border

 

    $colPad = Get-ThemeProperty $theme "DataTable.Pad" 1 "Integer"

 

    # Header Styles

    $headerStyleFG = Get-PSStyleValue $theme "DataTable.Header.FG" "#FFFFFF" "Foreground"

    $headerStyleBG = Get-PSStyleValue $theme "DataTable.Header.BG" $null "Background"

    $headerSeparator = Get-ThemeProperty $theme "DataTable.Header.Separator" $true "Boolean"

    $headerCase = Get-ThemeProperty $theme "DataTable.Header.Case" "Default" "String"

 

    # Data Row Styles

    $dataStyleFG = Get-PSStyleValue $theme "DataTable.DataRow.FG" "#FFFFFF" "Foreground"

    $dataStyleBG = Get-PSStyleValue $theme "DataTable.DataRow.BG" $null "Background"

    $altStyleFG = Get-PSStyleValue $theme "DataTable.AltRow.FG" $dataStyleFG "Foreground" # Fallback to data style if AltRow.FG not defined

    $altStyleBG = Get-PSStyleValue $theme "DataTable.AltRow.BG" $dataStyleBG "Background" # Fallback to data style if AltRow.BG not defined

    $useAltRows = ($altStyleBG -ne $dataStyleBG) -or ($altStyleFG -ne $dataStyleFG) # Check if alt style is actually different

 

    $cellInnerWidths = @($columns | ForEach-Object { $_.Width })

    $cellOuterWidths = @($columns | ForEach-Object { $_.Width + (2 * $colPad) })

 

    # --- Draw Top Border ---

    $topBorder = $borderChars.TopLeft

    for ($i = 0; $i -lt $columns.Count; $i++) {

        $topBorder += $borderChars.Horizontal * $cellOuterWidths[$i]

        if ($i -lt $columns.Count - 1) { $topBorder += $borderChars.TopJoin }

    }

    $topBorder += $borderChars.TopRight

    # Apply border style to the entire line

    Write-Host "$borderStyle$topBorder$($PSStyle.Reset)"

 

    # --- Draw Header ---

    $headerLine = "$borderStyle$($borderChars.Vertical)$($PSStyle.Reset)" # Start with styled vertical border

    for ($i = 0; $i -lt $columns.Count; $i++) {

        $col = $columns[$i]

        $title = switch ($headerCase.ToLower()) {

            "uppercase" { $col.Title.ToUpper() }

            default     { $col.Title }

        }

        # Truncate if necessary

        if (($title | Measure-Object -Character).Count -gt $cellInnerWidths[$i]) {

            $title = $title.Substring(0, $cellInnerWidths[$i] - 1) + "…"

        } else {

            $title = $title.PadRight($cellInnerWidths[$i])

        }

        $cellContent = (" " * $colPad) + $title + (" " * $colPad)

        # Apply header styles to cell content

        $headerCell = Apply-PSStyle -Text $cellContent -FG $headerStyleFG -BG $headerStyleBG

        $headerLine += $headerCell + "$borderStyle$($borderChars.Vertical)$($PSStyle.Reset)" # Add styled vertical border

    }

    Write-Host $headerLine

 

    # --- Draw Header Separator ---

    if ($headerSeparator) {

        $separatorLine = "$borderStyle$($borderChars.LeftJoin)" # Start with styled join

        for ($i = 0; $i -lt $columns.Count; $i++) {

            $separatorLine += $borderChars.Horizontal * $cellOuterWidths[$i]

            if ($i -lt $columns.Count - 1) { $separatorLine += $borderChars.Cross }

        }

        $separatorLine += $borderChars.RightJoin

        # Apply border style to the entire separator line

        Write-Host "$borderStyle$separatorLine$($PSStyle.Reset)"

    }

 

    # --- Draw Data Rows ---

    if ($Data.Count -eq 0) {

        $emptyLine = "$borderStyle$($borderChars.Vertical)$($PSStyle.Reset)"

        $emptyWidth = ($cellOuterWidths | Measure-Object -Sum).Sum + ($columns.Count - 1)

        $emptyText = " No data available "

        $padLen = [Math]::Max(0, $emptyWidth - $emptyText.Length)

        $emptyTextPadded = (" " * [Math]::Floor($padLen / 2)) + $emptyText + (" " * [Math]::Ceiling($padLen / 2))

        if ($emptyTextPadded.Length -gt $emptyWidth) { $emptyTextPadded = $emptyTextPadded.Substring(0, $emptyWidth) }

        elseif ($emptyTextPadded.Length -lt $emptyWidth) { $emptyTextPadded = $emptyTextPadded.PadRight($emptyWidth) }

 

        $emptyStyle = Get-PSStyleValue $theme "Palette.DisabledFG" "#808080" "Foreground"

        $emptyCell = Apply-PSStyle -Text $emptyTextPadded -FG $emptyStyle

        $emptyLine += $emptyCell + "$borderStyle$($borderChars.Vertical)$($PSStyle.Reset)"

        Write-Host $emptyLine

    } else {

        for ($rowIndex = 0; $rowIndex -lt $Data.Count; $rowIndex++) {

            $row = $Data[$rowIndex]

            # Ensure row is an array for consistent indexing

            if (-not ($row -is [System.Array])) {

                if ($row -is [PSCustomObject]) {

                    $tempRow = @()

                    # Take properties based on the number of defined columns for the view

                    $propsToTake = $columns.Count

                    $propNames = $row.PSObject.Properties.Name

                    $propsToTake = [Math]::Min($propsToTake, $propNames.Count)

                    $propNames | Select-Object -First $propsToTake | ForEach-Object { $tempRow += $row.$_ }

                    # Pad with empty strings if object has fewer properties than columns

                    while($tempRow.Count -lt $columns.Count) { $tempRow += "" }

                    $row = $tempRow

                } else {

                    # Handle single value case - treat as first column

                    $row = @($row) + @("") * ($columns.Count -1)

                }

            } elseif ($row.Count -lt $columns.Count) {

                 # Pad existing array if it's shorter than columns

                 $row = @($row) + @("") * ($columns.Count - $row.Count)

            }

 

            $rowLine = "$borderStyle$($borderChars.Vertical)$($PSStyle.Reset)" # Start row with styled border

 

            # Determine Base Styles (Alternating Rows)

            $baseStyleFG = $dataStyleFG

            $baseStyleBG = $dataStyleBG

            if ($useAltRows -and ($rowIndex % 2 -ne 0)) {

                $baseStyleFG = $altStyleFG

                $baseStyleBG = $altStyleBG

            }

 

            # Check for Row-Specific Highlighting defined by semantic key or direct colors

            $rowHighlightStyle = $null

            $cellSpecificStyles = @{} # Store cell overrides: Index -> @{FG=..., BG=...}

            if ($RowColors.ContainsKey($rowIndex)) {

                $colorInfo = $RowColors[$rowIndex]

 

                if ($colorInfo -is [string]) {

                    # Semantic key for the whole row (e.g., "Overdue", "Selected")

                    $rowHighlightStyle = Get-ThemeProperty $theme "DataTable.Highlight.$colorInfo" $null "Hashtable"

                    if ($rowHighlightStyle) {

                         $baseStyleFG = Get-PSStyleValue $rowHighlightStyle "FG" $baseStyleFG "Foreground"

                         $baseStyleBG = Get-PSStyleValue $rowHighlightStyle "BG" $baseStyleBG "Background"

                    }

                } elseif ($colorInfo -is [hashtable]) {

                    # Hashtable contains overrides for row or specific cells

                    if ($colorInfo.ContainsKey("_ROW_FG")) { $baseStyleFG = Get-PSStyleValue $colorInfo "_ROW_FG" $baseStyleFG "Foreground" }

                    if ($colorInfo.ContainsKey("_ROW_BG")) { $baseStyleBG = Get-PSStyleValue $colorInfo "_ROW_BG" $baseStyleBG "Background" }

 

                    # Check for cell overrides (semantic or direct)

                    foreach ($key in $colorInfo.Keys) {

                         if ($key -match '^(_?CELL_)?(\d+)$') { # Match _CELL_1, CELL_1, or just 1

                             $cellIdx = [int]$matches[2]

                             $cellValue = $colorInfo[$key]

                             if ($cellValue -is [string]) { # Semantic key for cell

                                 $cellHighlight = Get-ThemeProperty $theme "DataTable.Highlight.$cellValue" $null "Hashtable"

                                 if ($cellHighlight) {

                                     $cellSpecificStyles[$cellIdx] = @{

                                         FG = Get-PSStyleValue $cellHighlight "FG" $null "Foreground" # Get override or null

                                         BG = Get-PSStyleValue $cellHighlight "BG" $null "Background"

                                     }

                                 }

                             } elseif ($cellValue -is [hashtable]) { # Direct FG/BG for cell

                                 $cellSpecificStyles[$cellIdx] = @{

                                     FG = Get-PSStyleValue $cellValue "FG" $null "Foreground"

                                     BG = Get-PSStyleValue $cellValue "BG" $null "Background"

                                 }

                             }

                         }

                    }

                }

                # Deprecated: Direct integer color codes are no longer supported with PSStyle

                # elseif ($colorInfo -is [int]) { ... }

            }

 

            # Loop through columns to build the row

            for ($i = 0; $i -lt $columns.Count; $i++) {

                $colInnerWidth = $cellInnerWidths[$i]

                $value = if ($i -ge $row.Count -or $row[$i] -eq $null) { "" } else { $row[$i].ToString() }

 

                # Truncate value if needed

                $displayValue = $value

                if (($displayValue | Measure-Object -Character).Count -gt $colInnerWidth) {

                    $displayValue = $displayValue.Substring(0, $colInnerWidth - 1) + "…"

                } else {

                    $displayValue = $displayValue.PadRight($colInnerWidth)

                }

 

                # Determine final cell style, applying overrides

                $cellStyleFG = $baseStyleFG

                $cellStyleBG = $baseStyleBG

                if ($cellSpecificStyles.ContainsKey($i)) {

                     # Apply overrides only if they are not null/empty

                     if (-not [string]::IsNullOrEmpty($cellSpecificStyles[$i].FG)) { $cellStyleFG = $cellSpecificStyles[$i].FG }

                     if (-not [string]::IsNullOrEmpty($cellSpecificStyles[$i].BG)) { $cellStyleBG = $cellSpecificStyles[$i].BG }

                }

 

                # Construct styled cell content

                $cellContent = (" " * $colPad) + $displayValue + (" " * $colPad)

                $dataCell = Apply-PSStyle -Text $cellContent -FG $cellStyleFG -BG $cellStyleBG

 

                # Append styled cell and border to the row line

                $rowLine += $dataCell + "$borderStyle$($borderChars.Vertical)$($PSStyle.Reset)"

            }

            Write-Host $rowLine # Output the completed, styled row

        } # End row loop

    } # End else (Data.Count > 0)

 

    # --- Draw Bottom Border ---

    $bottomBorder = $borderChars.BottomLeft

    for ($i = 0; $i -lt $columns.Count; $i++) {

        $bottomBorder += $borderChars.Horizontal * $cellOuterWidths[$i]

        if ($i -lt $columns.Count - 1) { $bottomBorder += $borderChars.BottomJoin }

    }

    $bottomBorder += $borderChars.BottomRight

    # Apply border style to the entire line

    Write-Host "$borderStyle$bottomBorder$($PSStyle.Reset)"

}

#endregion

 

#region Data Helper Functions (Copied from PMCV8iv - No changes needed)

 

function Format-DateSafeDisplay {

    param ([string]$DateStringInternal)

 

    # --- Initial Checks ---

    if ([string]::IsNullOrWhiteSpace($DateStringInternal)) { return "" }

 

    # Define a safe, hardcoded fallback format

    $fallbackDisplayFormat = "yyyy-MM-dd"

    $formatToUse = $fallbackDisplayFormat # Default to fallback

 

    # --- Check Global Config and displayDateFormat property at runtime ---

    if ($null -eq $Global:AppConfig) {

        Write-AppLog "Format-DateSafeDisplay: Global:AppConfig is NULL. Using fallback format '$fallbackDisplayFormat'." "WARN"

    } elseif (-not $Global:AppConfig.PSObject.Properties.Name.Contains('displayDateFormat')) {

        Write-AppLog "Format-DateSafeDisplay: Global:AppConfig is missing 'displayDateFormat' property. Using fallback format '$fallbackDisplayFormat'." "WARN"

    } elseif ($null -eq $Global:AppConfig.displayDateFormat) {

        Write-AppLog "Format-DateSafeDisplay: Global:AppConfig.displayDateFormat is NULL. Using fallback format '$fallbackDisplayFormat'." "WARN"

    } elseif ($Global:AppConfig.displayDateFormat -isnot [string]) {

        $actualType = $Global:AppConfig.displayDateFormat.GetType().FullName

        Write-AppLog "Format-DateSafeDisplay: Global:AppConfig.displayDateFormat is not a String (Type: $actualType). Using fallback format '$fallbackDisplayFormat'." "WARN"

    } elseif ([string]::IsNullOrWhiteSpace($Global:AppConfig.displayDateFormat)) {

        Write-AppLog "Format-DateSafeDisplay: Global:AppConfig.displayDateFormat is empty or whitespace. Using fallback format '$fallbackDisplayFormat'." "WARN"

    } else {

        # Config value seems structurally okay, try using it

        $formatToUse = $Global:AppConfig.displayDateFormat

        Write-AppLog "Format-DateSafeDisplay: Using configured display format '$formatToUse'." "DEBUG"

    }

    # --- End Runtime Check ---

 

 

    # --- Attempt Parsing and Formatting ---

    if ($DateStringInternal -match "^\d{8}$") {

        try {

            # Parse the internal format

            $parsedDate = [datetime]::ParseExact($DateStringInternal, $global:DATE_FORMAT_INTERNAL, [System.Globalization.CultureInfo]::InvariantCulture)

 

            # Attempt to format using the determined format string ($formatToUse)

            try {

                return $parsedDate.ToString($formatToUse)

            } catch {

                # Log the error if formatting fails even with the determined format string

                Write-AppLog "ERROR formatting date '$DateStringInternal' using format '$formatToUse': $($_.Exception.Message). Falling back to '$fallbackDisplayFormat'." "ERROR"

                # Attempt formatting with the hardcoded fallback as a last resort

                try {

                    return $parsedDate.ToString($fallbackDisplayFormat)

                } catch {

                    # If even the fallback fails (shouldn't happen with yyyy-MM-dd), return something indicative

                    Write-AppLog "CRITICAL ERROR: Failed to format date '$DateStringInternal' even with fallback format '$fallbackDisplayFormat': $($_.Exception.Message)." "ERROR"

                    return "FormatErr"

                }

            }

        } catch {

             # This catch handles the ParseExact failure

             Write-AppLog "Error parsing date '$DateStringInternal' using internal format '$($global:DATE_FORMAT_INTERNAL)': $($_.Exception.Message)" "WARN"

             return "InvalidDate"

        }

    }

 

    # Handle cases where input might already be in a display format (less critical for this specific error)

    # Check against the format we decided to use

    if ($DateStringInternal -match "^\d{4}-\d{2}-\d{2}$") { # Basic check, might need adjustment if $formatToUse is very different

        try {

            [void][datetime]::ParseExact($DateStringInternal, $formatToUse, [System.Globalization.CultureInfo]::InvariantCulture)

            # If it parses successfully using the target format, return it as is

            return $DateStringInternal

        } catch {}

    }

 

    # If none of the above match or parse correctly

    Write-AppLog "Format-DateSafeDisplay received unhandled format: '$DateStringInternal'" "DEBUG"

    return "InvalidFmt"

}

 

function Parse-DateSafeInternal { param ([string]$DateStringInput); if ([string]::IsNullOrWhiteSpace($DateStringInput)) { return "" }; if ($DateStringInput -match "^\d{4}-\d{2}-\d{2}$") { try { return [datetime]::ParseExact($DateStringInput, $Global:AppConfig.displayDateFormat, $null).ToString($global:DATE_FORMAT_INTERNAL) } catch { } }; if ($DateStringInput -match "^\d{8}$") { try { [void][datetime]::ParseExact($DateStringInput, $global:DATE_FORMAT_INTERNAL, $null); return $DateStringInput } catch { return "" } }; return "" }

 

function Get-CsvDataSafely { param([string]$FilePath); if (-not (Test-Path $FilePath)) { Write-AppLog "CSV file not found: $FilePath" "WARN"; return @() }; try { $fileContent = Get-Content -Path $FilePath -Encoding utf8 -EA Stop; if ($fileContent.Count -le 0) { Write-AppLog "CSV file empty: $FilePath" "WARN"; return @() }; if ($fileContent.Count -eq 1 -and -not ([string]::IsNullOrWhiteSpace($fileContent[0]))) { if ($fileContent[0] -match ',') { Write-AppLog "CSV only header: $FilePath" "INFO" } else { Write-AppLog "CSV single line invalid header: $FilePath" "WARN" }; return @() }; $data = Import-Csv -Path $FilePath -Encoding utf8 -EA Stop; return @($data) } catch { Handle-Error -ErrorRecord $_ -Context "Reading CSV '$FilePath'"; return @() } }

function Get-CsvData { param([string]$FilePath) return Get-CsvDataSafely -FilePath $FilePath }

function Set-CsvData { param( [string]$FilePath, [array]$Data ); $Data = @($Data); try { $dir = Split-Path $FilePath -Parent; if (-not (Ensure-DirectoryExists -DirectoryPath $dir)) { return $false }; $backupPath = ""; if (Test-Path $FilePath) { $backupPath = "$FilePath.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"; try { Copy-Item -Path $FilePath -Destination $backupPath -Force -EA Stop; Write-AppLog "Backed up CSV: $backupPath" "INFO" } catch { Handle-Error $_ "Backing up CSV '$FilePath'" } }; if ($Data.Count -gt 0) { $firstItem = $Data[0]; if ($firstItem -is [PSCustomObject] -and $firstItem.PSObject.Properties.Count -eq 0) { Write-AppLog "SAFETY: Aborted saving CSV data with empty object. Path: $FilePath." "ERROR"; Show-Error "Safety Check: Aborted saving potentially corrupt data (empty object) to $FilePath."; return $false } }; if ($Data.Count -gt 0) { $Data | Export-Csv -Path $FilePath -NoTypeInformation -Encoding utf8 -Force -EA Stop } else { $headerString = ""; if ($FilePath -eq $Global:AppConfig.timeTrackingFile) { $headerString = "Date,ID2,Hours,Description" } else { if(Test-Path $FilePath){ try { $headerString = Get-Content $FilePath -TotalCount 1 -Encoding utf8 -EA Stop } catch { Write-AppLog "Could not read header from existing empty file '$FilePath'" "WARN" } } }; if(-not [string]::IsNullOrWhiteSpace($headerString)){ $headerString | Out-File $FilePath -Encoding utf8 -Force -EA Stop } else { Set-Content -Path $FilePath -Value "" -Encoding utf8 -Force -EA Stop; Write-AppLog "Saving empty data to '$FilePath' without known headers." "WARN" } }; Write-AppLog "Saved CSV data to $FilePath" "INFO"; return $true } catch { Handle-Error $_ "Writing CSV '$FilePath'"; if (Test-Path $backupPath) { try { Copy-Item -Path $backupPath -Destination $FilePath -Force -EA Stop; Write-AppLog "Restored CSV backup $backupPath due to save error." "WARN" } catch { Handle-Error $_ "Restoring CSV backup $backupPath" } }; return $false } }

#endregion

 

#region Excel Interaction Helpers (Required by New-ProjectFromRequest - No changes needed from original)

 

# --- Test-FileLocked, Validate-ExcelOperation, Release-ComObjects ---

# (Keep the existing versions of these functions as provided in the original script)

function Test-FileLocked { param([string]$FilePath); if (-not (Test-Path $FilePath)) { return $false }; $locked = $false; $fileStream = $null; try { $fileInfo = New-Object System.IO.FileInfo $FilePath; $fileStream = $fileInfo.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) } catch [System.IO.IOException] { $locked = $true } catch { Write-AppLog "Test-FileLocked non-IO exception for '$FilePath': $($_.Exception.Message)" "DEBUG"; $locked = $true } finally { if ($null -ne $fileStream) { try { $fileStream.Close() } catch {}; try { $fileStream.Dispose() } catch {} } }; return $locked }

function Validate-ExcelOperation { param( [string]$FilePath, [switch]$RequireWriteAccess = $false ); $errors = @(); if (-not (Test-Path $FilePath -PathType Leaf)) { $errors += "File not found/is dir: $FilePath"; return $errors }; $extension = [System.IO.Path]::GetExtension($FilePath).ToLower(); if ($extension -notin @('.xlsx', '.xlsm', '.xls', '.xlsb')) { $errors += "Not Excel extension: $extension" }; try { if ((Get-Item $FilePath -ErrorAction Stop).Length -eq 0) { $errors += "File empty: $FilePath" } } catch { $errors += "Could not get size: $($_.Exception.Message)" }; if (Test-FileLocked -FilePath $FilePath) { $errors += "File locked: $FilePath"; $RequireWriteAccess = $false }; if ($RequireWriteAccess) { try { if ((Get-Item $FilePath -ErrorAction Stop).IsReadOnly) { $errors += "File read-only." } } catch { $errors += "Could not check read-only: $($_.Exception.Message)" }; $folder = Split-Path -Path $FilePath -Parent; try { $testFilePath = Join-Path -Path $folder -ChildPath "pmc_writetest_$([Guid]::NewGuid().ToString()).tmp"; [System.IO.File]::Create($testFilePath).Close(); Remove-Item -Path $testFilePath -Force -EA SilentlyContinue } catch { $errors += "Write permission denied: $folder" } }; return $errors }

function Release-ComObjects { param([array]$ComObjects); if ($null -eq $ComObjects -or $ComObjects.Count -eq 0) { return }; foreach ($obj in $ComObjects) { if ($null -ne $obj -and [System.Runtime.InteropServices.Marshal]::IsComObject($obj)) { try { if ($obj.PSObject.Methods.Name -contains "Close") { try { $obj.Close($false) } catch { Write-AppLog "Non-critical: Error closing workbook COM object." "DEBUG" } } elseif ($obj.PSObject.Methods.Name -contains "Quit") { try { $obj.Quit() } catch { Write-AppLog "Non-critical: Error quitting Excel COM object." "DEBUG"} }; $refCount = 0; do { $refCount = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) } while ($refCount -gt 0) } catch { Write-AppLog "Failed during COM object release attempt: $($_.Exception.Message)" "WARN" } } }; [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers() }

 

# --- Process-ExcelWithTempCopy ---

# (Keep the existing version)

function Process-ExcelWithTempCopy {

    param(

        [string]$OriginalFilePath,

        [scriptblock]$ProcessingLogic,

        [switch]$UpdateOriginal = $false

    )

    $tempFilePath = $null

    try {

        Show-ExcelProgress -Activity "Excel Op" -Status "Validating..." -PercentComplete 5 -ID 2

        $validationErrors = Validate-ExcelOperation -FilePath $OriginalFilePath -RequireWriteAccess $UpdateOriginal

        if ($validationErrors.Count -gt 0) {

            foreach ($errorMsg in $validationErrors) { Show-Error $errorMsg }

            Show-ExcelProgress -Complete -ID 2

            return $false

        }

        $tempDir = [System.IO.Path]::GetTempPath()

        $tempFileName = "$(New-Guid)$([System.IO.Path]::GetExtension($OriginalFilePath))"

        $tempFilePath = Join-Path -Path $tempDir -ChildPath $tempFileName

        Show-ExcelProgress -Status "Copying..." -PercentComplete 15 -ID 2

        Copy-Item -Path $OriginalFilePath -Destination $tempFilePath -Force -EA Stop

        Show-ExcelProgress -Status "Processing..." -PercentComplete 30 -ID 2

        # Execute the provided scriptblock, passing the temp file path

        $result = & $ProcessingLogic -FilePath $tempFilePath

        if ($UpdateOriginal -and $result) {

            Show-ExcelProgress -Status "Updating original..." -PercentComplete 80 -ID 2

            if (Test-FileLocked -FilePath $OriginalFilePath) {

                Write-AppLog "Cannot update original Excel - became locked: $OriginalFilePath" "ERROR"

                Show-Error "Cannot update original file - became locked: $OriginalFilePath"

                Show-ExcelProgress -Complete -ID 2

                return $false

            }

            Copy-Item -Path $tempFilePath -Destination $OriginalFilePath -Force -EA Stop

            Write-AppLog "Updated original Excel file: $OriginalFilePath" "INFO"

        } elseif ($UpdateOriginal -and (-not $result)) {

            Write-AppLog "Processing logic failed. Original Excel NOT updated: $OriginalFilePath" "WARN"

        }

        Show-ExcelProgress -Status "Complete" -PercentComplete 100 -ID 2

        Show-ExcelProgress -Complete -ID 2

        return $result

    } catch {

        Handle-Error -ErrorRecord $_ -Context "Processing Excel with temp copy for '$OriginalFilePath'"

        Show-ExcelProgress -Complete -ID 2

        return $false

    } finally {

        if ($null -ne $tempFilePath -and (Test-Path $tempFilePath)) {

            try {

                Remove-Item -Path $tempFilePath -Force -EA SilentlyContinue

                Write-AppLog "Removed temporary Excel file: $tempFilePath" "DEBUG"

            } catch {

                Write-AppLog "Could not remove temp Excel file: $tempFilePath. Error: $($_.Exception.Message)" "WARN"

            }

        }

    }

}

 

# --- Find-CellByLabel, Get-CellValueTyped ---

# (Keep the existing versions)

function Find-CellByLabel { param( $Worksheet, [string]$LabelText, [int]$OffsetColumn = 0, [int]$OffsetRow = 0 ); if ($null -eq $Worksheet -or [string]::IsNullOrWhiteSpace($LabelText)) { return $null }; $foundRange = $null; try { $foundRange = $Worksheet.UsedRange.Find( $LabelText, $null, [System.Reflection.Missing]::Value, 1, 1, 1, $false ); if ($null -ne $foundRange) { if ($OffsetColumn -ne 0 -or $OffsetRow -ne 0) { $targetRow = $foundRange.Row + $OffsetRow; $targetCol = $foundRange.Column + $OffsetColumn; if($targetRow -gt 0 -and $targetCol -gt 0 -and $targetRow -le $Worksheet.Rows.Count -and $targetCol -le $Worksheet.Columns.Count) { return $Worksheet.Cells.Item($targetRow, $targetCol) } else { Write-AppLog "Offset ($OffsetRow, $OffsetColumn) for label '$LabelText' results in invalid cell address." "DEBUG"; return $null } } else { return $foundRange } } else { Write-AppLog "Label '$LabelText' not found in worksheet '$($Worksheet.Name)'." "DEBUG"; return $null } } catch { Write-AppLog "Error finding cell with label '$LabelText' in '$($Worksheet.Name)': $($_.Exception.Message)" "WARN"; return $null } }

function Get-CellValueTyped { param( $Worksheet, $Address, [ValidateSet("String", "Number", "Date", "Boolean")] [string]$Type = "String" ); $cell = $null; try { if ($Address -is [string]) { $cell = $Worksheet.Range($Address) } elseif ($Address -is [Object] -and $Address -is [System.__ComObject]) { $cell = $Address } else { Write-AppLog "GetVal: Invalid address type provided." "DEBUG"; return $null }; if ($null -eq $cell) { Write-AppLog "GetVal: Could not resolve '$Address' to cell." "DEBUG"; return $null }; $rawValue = $cell.Value2; if ($null -eq $rawValue -or ($rawValue -is [string] -and [string]::IsNullOrWhiteSpace($rawValue)) -or $rawValue -is [System.DBNull]) { return $null }; if($rawValue -is [int] -and $rawValue -le -2146826281 -and $rawValue -ge -2146826246) { Write-AppLog "GetVal: Cell '$($cell.Address())' contains Excel error." "DEBUG"; return $null }; switch ($Type.ToLower()) { "string" { return [string]$rawValue.ToString().Trim() } "number" { $number = 0.0; if ([double]::TryParse($rawValue.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) { return $number }; Write-AppLog "GetVal: Failed parse '$rawValue' as Number." "DEBUG"; return $null } "date" { try { if ($rawValue -is [double]) { return [DateTime]::FromOADate($rawValue) } elseif ($rawValue -is [datetime]) { return $rawValue } else { return [DateTime]::Parse($rawValue.ToString()) } } catch { Write-AppLog "GetVal: Failed parse '$rawValue' as Date." "DEBUG"; return $null } } "boolean" { if ($rawValue -is [bool]) { return $rawValue }; $strValue = $rawValue.ToString().ToLower().Trim(); if ($strValue -in @("yes", "true", "1", "y", "-1")) { return $true }; if ($strValue -in @("no", "false", "0", "n")) { return $false }; Write-AppLog "GetVal: Failed parse '$rawValue' as Boolean." "DEBUG"; return $null } } } catch { $cellAddress = "(unknown)"; try { $cellAddress = $cell.Address() } catch {}; Handle-Error -ErrorRecord $_ -Context "Getting cell value from '$cellAddress'"; return $null }; return $null }

 

# --- Invoke-ExcelOperation ---

# (Keep the existing version)

function Invoke-ExcelOperation {

    param(

        [string]$FilePath,

        [scriptblock]$ScriptBlock,

        [switch]$Visible = $false,

        [switch]$ReadOnly = $false

    )

    $excel = $null

    $workbook = $null

    $comObjects = @()

    try {

        Show-ExcelProgress -Activity "Excel Op" -Status "Starting..." -PercentComplete 5 -ID 3

        try {

            $excel = New-Object -ComObject Excel.Application -EA Stop

        } catch {

            Handle-Error -ErrorRecord $_ -Context "Starting Excel Application"

            Show-ExcelProgress -Complete -ID 3

            return $null

        }

        $comObjects += $excel

        $excel.Visible = $Visible

        $excel.DisplayAlerts = $false

        $excel.UserControl = $Visible

        $excel.ScreenUpdating = $Visible # Should be $false unless $Visible is $true for debugging

        if (-not $Visible) { $excel.ScreenUpdating = $false }

 

 

        Show-ExcelProgress -Status "Opening: $(Split-Path $FilePath -Leaf)" -PercentComplete 20 -ID 3

        $workbook = $excel.Workbooks.Open($FilePath, 0, $ReadOnly)

        if ($null -eq $workbook) { throw "Failed open workbook: $FilePath" }

        $comObjects += $workbook

 

 

        Show-ExcelProgress -Status "Processing..." -PercentComplete 50 -ID 3

        # Execute the main logic, passing Excel and Workbook objects

        $result = & $ScriptBlock -Excel $excel -Workbook $workbook

 

 

        # Auto-save if not visible, not read-only, and changes were made

        if (-not $Visible -and $workbook.Saved -eq $false -and (-not $ReadOnly)) {

            Write-AppLog "Auto-saving workbook: $FilePath" "DEBUG"

            try { $workbook.Save() }

            catch { Handle-Error -ErrorRecord $_ -Context "Auto-saving workbook '$FilePath'" }

        }

 

 

        Show-ExcelProgress -Status "Finishing..." -PercentComplete 90 -ID 3

        return $result

    } catch {

        Handle-Error -ErrorRecord $_ -Context "Invoking Excel Operation on '$FilePath'"

        Show-ExcelProgress -Complete -ID 3

        return $null

    } finally {

        Show-ExcelProgress -Status "Cleaning up..." -PercentComplete 95 -ID 3

        # Ensure workbook is closed if opened, before quitting Excel

        if ($workbook -ne $null -and $workbook.PSObject.Methods.Name -contains 'Close') {

             try { $workbook.Close($false) } catch { Write-AppLog "Non-critical: Error closing workbook during cleanup." "DEBUG" }

        }

        # Quit Excel if we created it

        if ($excel -ne $null -and $excel.PSObject.Methods.Name -contains 'Quit') {

             try { $excel.Quit() } catch { Write-AppLog "Non-critical: Error quitting Excel during cleanup." "DEBUG" }

        }

        # Release COM objects in reverse order of creation (roughly)

        $objectsToRelease = @()

        if ($workbook -ne $null) { $objectsToRelease += $workbook }

        if ($excel -ne $null) { $objectsToRelease += $excel }

        # Combine with any others tracked (though $comObjects should contain these)

        $allObjects = $comObjects + $objectsToRelease | Select-Object -Unique

        [array]::Reverse($allObjects)

        Release-ComObjects -ComObjects $allObjects

        Show-ExcelProgress -Complete -ID 3

    }

}

 

#endregion Excel Interaction Helpers

 

 

#region Project Management Functions (Corrected New-ProjectFromRequest)

 

function New-ProjectFromRequest {
    Clear-Host; Draw-Title "NEW PROJECT FROM REQUEST"
    Show-Info "Select source Request XLSM file."
    # Use PSStyle file browser
    $sourceRequestPath = Browse-FilesNumeric -Title "Select Source Request File" -StartPath "C:\" -Filter "*.xlsm"
    if (-not $sourceRequestPath) { Write-AppLog "New project cancelled - no request file selected." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

    $validationErrors = Validate-ExcelOperation -FilePath $sourceRequestPath
    if ($validationErrors.Count -gt 0) { Write-AppLog "Request file validation failed: $($validationErrors -join '; ')" "ERROR"; foreach ($errorMsg in $validationErrors) { Show-Error $errorMsg }; Pause-Screen; return }

    Show-Info "Select PARENT folder for the new project directory."
    # Use PSStyle directory browser
    $parentFolder = Browse-DirectoriesNumeric -Title "Select Parent Project Folder" -StartPath "C:\"
    if (-not $parentFolder) { Write-AppLog "New project cancelled - no parent folder selected." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }
    if (-not (Test-Path $parentFolder -PathType Container)) { Write-AppLog "Invalid parent folder selected: $parentFolder" "ERROR"; Show-Error "Invalid parent path selected: '$parentFolder'"; Pause-Screen; return }

    Write-AppLog "Starting project creation from '$sourceRequestPath' in '$parentFolder'" "INFO"
    Show-Info "Extracting data from request file..."
    $extractedData = @{ FullName = ""; ClientID = ""; Address1 = ""; Address2 = ""; Address3 = ""; Description = "" } # Initialize hash
    $extractionMappings = $global:excelMappings.Extraction

    # Process Excel using helper (uses Show-ExcelProgress)
    # Extract data from the SOURCE request file (read-only)
    $extractResult = Process-ExcelWithTempCopy -OriginalFilePath $sourceRequestPath -ProcessingLogic {
        param($TempFilePath) # Path to the temporary copy of the request file
        # Invoke Excel operation on the temporary request file
        return Invoke-ExcelOperation -FilePath $TempFilePath -ReadOnly $true -ScriptBlock {
            param($Excel, $Workbook) # Parameters provided by Invoke-ExcelOperation
            $extracted = @{ FullName = ""; ClientID = ""; Address1 = ""; Address2 = ""; Address3 = ""; Description = "" } # Ensure keys exist
            $sourceSheet = $null
            # Determine source sheet name using mapping (default to SVI-CAS or first sheet)
            $sourceSheetName = $using:global:excelMappings.Copying[0].SourceSheet # Use mapping if available
            if ([string]::IsNullOrWhiteSpace($sourceSheetName)) { $sourceSheetName = "SVI-CAS" } # Default sheet name
            try {
                $sourceSheet = $Workbook.Worksheets.Item($sourceSheetName)
            } catch {
                try {
                    $sourceSheet = $Workbook.Worksheets.Item(1)
                    Write-AppLog "Excel Extraction: Sheet '$sourceSheetName' not found, using first sheet '$($sourceSheet.Name)'." "WARN"
                } catch {
                    throw "No valid worksheet found in '$($Workbook.Name)'."
                }
            }
            if ($null -eq $sourceSheet) { throw "Failed to get worksheet from '$($Workbook.Name)'." }

            # Use combined mappings for extraction
            $allMappings = $using:extractionMappings # Access outer scope variable
            foreach ($mapping in $allMappings) {
                try {
                    $targetVar = $mapping.TargetVariable
                    # Skip if already extracted (prefer Label over Fixed if both exist for same var)
                    if (-not $extracted.ContainsKey($targetVar) -or [string]::IsNullOrEmpty($extracted[$targetVar])) {
                         $value = $null
                         if ($mapping.Type -eq 'Label') {
                             $offsetCol = if ($mapping.PSObject.Properties.Name -contains 'OffsetColumn') { $mapping.OffsetColumn } else { 1 }
                             $offsetRow = if ($mapping.PSObject.Properties.Name -contains 'OffsetRow') { $mapping.OffsetRow } else { 0 }
                             $valueCell = Find-CellByLabel -Worksheet $sourceSheet -LabelText $mapping.Source -OffsetColumn $offsetCol -OffsetRow $offsetRow
                             if ($valueCell) { $value = Get-CellValueTyped -Worksheet $sourceSheet -Address $valueCell -Type String }
                         } elseif ($mapping.Type -eq 'Fixed') {
                             $value = Get-CellValueTyped -Worksheet $sourceSheet -Address $mapping.Source -Type String
                         }
                         # Assign if value found and not empty
                         if (-not [string]::IsNullOrEmpty($value)) { $extracted[$targetVar] = $value; Write-AppLog "Extracted '$targetVar' using $($mapping.Type) '$($mapping.Source)'" "DEBUG" }
                         else { Write-AppLog "$($mapping.Type) '$($mapping.Source)' not found or empty for '$targetVar'." "DEBUG" }
                    } else { Write-AppLog "Already extracted '$targetVar', skipping $($mapping.Type) '$($mapping.Source)'." "DEBUG"}
                } catch { Write-AppLog "Excel Extraction Failed: Type '$($mapping.Type)' Source '$($mapping.Source)' for Var '$($mapping.TargetVariable)'. Error: $($_.Exception.Message)" "WARN" }
            }
            return $extracted # Return the hashtable of extracted data
        } # End Invoke-ExcelOperation ScriptBlock for extraction
    } # End Process-ExcelWithTempCopy for extraction

    if (-not $extractResult -is [hashtable] -or $extractResult.Count -eq 0 -or [string]::IsNullOrWhiteSpace($extractResult.FullName) -or [string]::IsNullOrWhiteSpace($extractResult.ClientID)) {
        Write-AppLog "Failed to extract required data (FullName, ClientID) from request file." "ERROR"
        Show-Error "Could not extract required data (Full Name, Client ID/ID2) from the request file. Please check the file content and mappings."
        Pause-Screen; return
    }
    # Update local data with extracted results
    foreach ($key in $extractResult.Keys) { if ($extractedData.ContainsKey($key)) { $extractedData[$key] = $extractResult[$key] } }

    $fullAddress = @($extractedData.Address1, $extractedData.Address2, $extractedData.Address3) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Join-String -Separator ", "

    # --- Confirm Details & Get Remaining Info ---
    Clear-Host; Draw-Title "CONFIRM PROJECT DETAILS"
    Show-Info "Data extracted from request file. Please confirm or provide details."
    # Use Apply-PSStyle for extracted data display
    $theme = $global:currentTheme
    $labelStyle = Get-PSStyleValue $theme "Palette.SecondaryFG" "#808080" "Foreground"
    $valueStyle = Get-PSStyleValue $theme "Palette.DataFG" "#FFFFFF" "Foreground"
    Write-Host (Apply-PSStyle -Text " Extracted Full Name : " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $extractedData.FullName -FG $valueStyle)
    Write-Host (Apply-PSStyle -Text " Extracted Client ID : " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $extractedData.ClientID -FG $valueStyle)
    Write-Host (Apply-PSStyle -Text " Extracted Address   : " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $fullAddress -FG $valueStyle)
    Write-Host (Apply-PSStyle -Text " Extracted Desc      : " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $extractedData.Description -FG $valueStyle)
    Write-Host ""

    $fullName = $extractedData.FullName # Use extracted name as default
    $id2 = $extractedData.ClientID # Use extracted ClientID as default ID2

    $allProjects = Load-ProjectTodoJson
    if ($allProjects | Where-Object { $_.ID2 -eq $id2 }) { Write-AppLog "Project creation failed - ID2 '$id2' already exists." "ERROR"; Show-Error "Project ID2 '$id2' already exists. Cannot create duplicate."; Pause-Screen; return }

    $id1 = Get-InputWithPrompt "Enter ID1 (Optional)" # Get optional ID1
    $defaultAssignedInternal = (Get-Date).ToString($global:DATE_FORMAT_INTERNAL)
    $assignedDateInput = Get-InputWithPrompt "Assigned date ($($global:AppConfig.displayDateFormat))" $defaultAssignedInternal -ForceDefaultFormat
    $assignedDateInternal = Parse-DateSafeInternal $assignedDateInput
    if ([string]::IsNullOrEmpty($assignedDateInternal)) { Write-AppLog "Invalid assigned date input '$assignedDateInput', defaulting to today." "WARN"; $assignedDateInternal = $defaultAssignedInternal }
    try { $assignedDate = [datetime]::ParseExact($assignedDateInternal, $global:DATE_FORMAT_INTERNAL, $null) } catch { Handle-Error $_ "Parsing assigned date '$assignedDateInternal'"; Pause-Screen; return }

    # Calculate default due date (e.g., 6 weeks / 42 days later)
    $defaultDueInternal = $assignedDate.AddDays(42).ToString($global:DATE_FORMAT_INTERNAL)
    $dueDateInput = Get-InputWithPrompt "Due date ($($global:AppConfig.displayDateFormat))" $defaultDueInternal -ForceDefaultFormat
    $dueDateInternal = Parse-DateSafeInternal $dueDateInput
    if ([string]::IsNullOrEmpty($dueDateInternal)) { Write-AppLog "Invalid due date input '$dueDateInput', using default." "WARN"; $dueDateInternal = $defaultDueInternal }

    # BF Date (Optional)
    $bfDateInput = Get-InputWithPrompt "BF date ($($global:AppConfig.displayDateFormat) or Enter skip)"
    $bfDateInternal = Parse-DateSafeInternal $bfDateInput
    if (-not [string]::IsNullOrEmpty($bfDateInput) -and [string]::IsNullOrEmpty($bfDateInternal)) { Show-Warning "Invalid BF date format entered. Skipping BF date." }

    # --- Create Folders ---
    Show-Info "Creating folder structure..."
    $sanitizedFolderName = $id2 -replace '[\\/:*?"<>|]+', '_' # Basic sanitization
    $projectFolder = Join-Path $parentFolder $sanitizedFolderName
    $docsFolder = Join-Path $projectFolder "__DOCS__"
    $casDocsFolder = Join-Path $docsFolder "__CAS_DOCS__"
    $tpDocsFolder = Join-Path $docsFolder "__TP_DOCS__"

    if (Test-Path $projectFolder) { Write-AppLog "Project folder '$projectFolder' already exists." "ERROR"; Show-Error "Target project folder '$projectFolder' already exists. Cannot continue."; Pause-Screen; return }

    try {
        if (-not (Ensure-DirectoryExists -DirectoryPath $projectFolder)) { throw "Failed ensure project folder" }
        if (-not (Ensure-DirectoryExists -DirectoryPath $docsFolder)) { throw "Failed ensure docs folder" }
        if (-not (Ensure-DirectoryExists -DirectoryPath $casDocsFolder)) { throw "Failed ensure cas_docs folder" }
        if (-not (Ensure-DirectoryExists -DirectoryPath $tpDocsFolder)) { throw "Failed ensure tp_docs folder" }
        Show-Success "Created project folder structure in '$parentFolder'."
    } catch { Handle-Error $_ "Creating project folders for '$id2'"; Pause-Screen; return }

    # --- Copy Files ---
    Show-Info "Copying files (CAA Template, Request)..."
    $targetCaaName = ""; $targetCaaPath = ""; $targetRequestName = ""; $targetRequestPath = ""

    # Copy CAA Template
    if ($Global:AppConfig.caaTemplatePath -and (Test-Path $Global:AppConfig.caaTemplatePath -PathType Leaf)) {
        $targetCaaName = "CAA - $sanitizedFolderName.xlsm" # Construct target name
        $targetCaaPath = Join-Path $casDocsFolder $targetCaaName
        $templateValidationErrors = Validate-ExcelOperation -FilePath $Global:AppConfig.caaTemplatePath
        if ($templateValidationErrors.Count -gt 0) { Write-AppLog "CAA Template validation failed: $($templateValidationErrors -join '; ')" "ERROR"; Show-Error "CAA Template invalid: $($templateValidationErrors -join '; ')"; $targetCaaName = ""; $targetCaaPath = "" }
        else {
            try { Copy-Item -Path $Global:AppConfig.caaTemplatePath -Destination $targetCaaPath -Force -EA Stop; Write-AppLog "Copied CAA Template to '$targetCaaPath'" "INFO" }
            catch {
                # <<< MODIFIED ERROR HANDLING >>>
                Handle-Error $_ "Copying CAA Template"
                Write-AppLog "CRITICAL: Failed to copy CAA Template from '$($Global:AppConfig.caaTemplatePath)' to '$targetCaaPath'. Check config and permissions." "ERROR"
                Show-Error "Failed to copy CAA Template. Check path in Configure Settings and file permissions."
                $targetCaaName = ""; $targetCaaPath = ""
                # Consider pausing or returning here if CAA is absolutely critical
                # Pause-Screen; return
            }
        }
    } else { Write-AppLog "CAA Template path invalid or not set ('$($Global:AppConfig.caaTemplatePath)'). Skipping copy." "WARN"; Show-Warning "CAA Template not found or path invalid. Skipping CAA copy." }

    # Copy Request File
    $targetRequestName = Split-Path -Leaf $sourceRequestPath
    $targetRequestPath = Join-Path $casDocsFolder $targetRequestName
    try { Copy-Item -Path $sourceRequestPath -Destination $targetRequestPath -Force -EA Stop; Write-AppLog "Copied Request file to '$targetRequestPath'" "INFO" }
    catch { Handle-Error $_ "Copying Request file"; $targetRequestName = "" } # Clear name if copy fails

    # --- Create Project Object (Initial) ---
    $newProject = [PSCustomObject]@{
        ID2=$id2; ID1=$id1; FullName=$fullName
        AssignedDate=$assignedDateInternal; DueDate=$dueDateInternal; BFDate=$bfDateInternal
        Status="Active"; CompletedDate=""
        ProjFolder=$projectFolder # Store full path
        CAAName=$targetCaaName; RequestName=$targetRequestName; T2020="" # T2020 name set later
        Todos=@() # Initialize empty Todos array
    }

    # --- Copy Data from Request to CAA (if files available) ---
    if ($targetCaaPath -and $targetRequestPath -and (Test-Path $targetCaaPath) -and (Test-Path $targetRequestPath)) {
        Write-AppLog "Starting Excel data copy Request -> CAA for '$id2'" "INFO"
        Show-Info "Copying data from Request to CAA..."
        # Process the TARGET CAA file, updating it with data from the SOURCE request file
        $copyResult = Process-ExcelWithTempCopy -OriginalFilePath $targetCaaPath -UpdateOriginal $true -ProcessingLogic {
            param($TempCaaPath) # Parameter for this scriptblock is the temp CAA path

            # Nested ScriptBlock passed to Invoke-ExcelOperation
            # This scriptblock operates on the temporary CAA file ($TempCaaPath)
            # It needs to OPEN the source request file ($using:targetRequestPath) to read data
            return Invoke-ExcelOperation -FilePath $TempCaaPath -ScriptBlock {
                param($Excel, $CaaWorkbook) # Parameters are for the TARGET CAA workbook
                $requestWorkbook = $null
                $copySuccess = $true
                try {
                    Show-ExcelProgress -Activity "Excel Copy" -Status "Opening request..." -PercentComplete 60 -ID 4
                    # Open the SOURCE request file (read-only) using the path from the outer scope
                    # $using: is essential here
                    $requestWorkbook = $Excel.Workbooks.Open($using:targetRequestPath, 0, $true)
                    if ($null -eq $requestWorkbook) { throw "Failed open request '$using:targetRequestPath'." }

                    # Get mappings from the outer scope using $using:
                    $copyMappings = $using:global:excelMappings.Copying
                    $staticEntries = $using:global:excelMappings.StaticEntries

                    # --- Get-Sheet Helper Function (Local Scope) ---
                    $sheetCache = @{}
                    Function Get-Sheet {
                        param($Workbook, $SheetNameOrIndex)
                        $cacheKey = "$($Workbook.Name)_$SheetNameOrIndex"
                        if ($sheetCache.ContainsKey($cacheKey)) { return $sheetCache[$cacheKey] }
                        $sheet = $null
                        try { $sheet = $Workbook.Worksheets.Item($SheetNameOrIndex) } catch {}
                        if ($null -eq $sheet -and $SheetNameOrIndex -is [string]) {
                            try {
                                $sheet = $Workbook.Worksheets.Item(1)
                                Write-AppLog "Sheet '$SheetNameOrIndex' not found in '$($Workbook.Name)', using first sheet '$($sheet.Name)'." "WARN"
                            } catch { throw "Cannot find sheet '$SheetNameOrIndex' or fallback first sheet in workbook '$($Workbook.Name)'" }
                        }
                        if ($null -eq $sheet) { throw "Cannot find sheet '$SheetNameOrIndex' in workbook '$($Workbook.Name)'" }
                        $sheetCache[$cacheKey] = $sheet
                        return $sheet
                    } # End Get-Sheet

                    # Pre-load sheets mentioned in mappings to fail early if sheets are missing
                    try {
                        $copyMappings | ForEach-Object { if($_.SourceSheet){ Get-Sheet $requestWorkbook $_.SourceSheet }; if($_.DestinationSheet){ Get-Sheet $CaaWorkbook $_.DestinationSheet } }
                        $staticEntries | ForEach-Object { if($_.DestinationSheet){ Get-Sheet $CaaWorkbook $_.DestinationSheet } }
                    } catch { throw "Failed to access required sheets. Aborting copy. Error: $($_.Exception.Message)" }

                    Show-ExcelProgress -Status "Copying mapped data..." -PercentComplete 70 -ID 4
                    foreach ($mapping in $copyMappings) {
                        try {
                             $sourceSheet = Get-Sheet $requestWorkbook $mapping.SourceSheet
                             $destSheet = Get-Sheet $CaaWorkbook $mapping.DestinationSheet
                             switch ($mapping.Type) {
                                'LabelToLabel' {
                                     $offsetCol=if($mapping.PSObject.Properties.Name -contains 'OffsetColumn'){$mapping.OffsetColumn}else{1}
                                     $offsetRow=if($mapping.PSObject.Properties.Name -contains 'OffsetRow'){$mapping.OffsetRow}else{0}
                                     $sourceValueCell=Find-CellByLabel -Worksheet $sourceSheet -LabelText $mapping.Source -OffsetColumn $offsetCol -OffsetRow $offsetRow
                                     $destValueCell=Find-CellByLabel -Worksheet $destSheet -LabelText $mapping.Destination -OffsetColumn $offsetCol -OffsetRow $offsetRow
                                     if ($sourceValueCell -and $destValueCell) { $destValueCell.Value2 = $sourceValueCell.Value2; Write-AppLog "Copied L2L: '$($mapping.Source)' ($($sourceSheet.Name)) to '$($mapping.Destination)' ($($destSheet.Name))" "DEBUG" }
                                     else { Write-AppLog "Skip L2L: Source:'$($mapping.Source)' ($($sourceSheet.Name)) or Dest:'$($mapping.Destination)' ($($destSheet.Name)) not found." "DEBUG" }
                                 }
                                'Range' {
                                     $sourceRange = $sourceSheet.Range($mapping.Source)
                                     $destRangeStart = $destSheet.Range($mapping.Destination)
                                     $destRangeStart.Resize($sourceRange.Rows.Count, $sourceRange.Columns.Count).Value2 = $sourceRange.Value2
                                     Write-AppLog "Copied Range: $($mapping.Source) ($($sourceSheet.Name)) to $($mapping.Destination) ($($destSheet.Name))" "DEBUG"
                                 }
                                'FixedToFixed' {
                                     $sourceValue = Get-CellValueTyped -Worksheet $sourceSheet -Address $mapping.Source -Type String
                                     if ($sourceValue -ne $null) { $destSheet.Range($mapping.Destination).Value2 = $sourceValue; Write-AppLog "Copied F2F: $($mapping.Source) ($($sourceSheet.Name)) to $($mapping.Destination) ($($destSheet.Name))" "DEBUG" }
                                     else { Write-AppLog "Skip F2F: Source '$($mapping.Source)' ($($sourceSheet.Name)) is empty." "DEBUG" }
                                 }
                                default { Write-AppLog "Unsupported copy type: $($mapping.Type)" "WARN" }
                             }
                        } catch { Write-AppLog "Excel Copy map error: Type '$($mapping.Type)' Source '$($mapping.Source)' Dest '$($mapping.Destination)'. Error: $($_.Exception.Message)" "WARN"; $copySuccess = $false }
                    } # End foreach mapping

                    Show-ExcelProgress -Status "Setting static entries..." -PercentComplete 80 -ID 4
                    foreach($entry in $staticEntries) {
                        try { $destSheet = Get-Sheet $CaaWorkbook $entry.DestinationSheet; $destSheet.Range($entry.Destination).Value2 = $entry.Value; Write-AppLog "Set Static: $($entry.Destination) ($($destSheet.Name)) to '$($entry.Value)'" "DEBUG" }
                        catch { Write-AppLog "Excel Static entry error at $($entry.Destination): $($_.Exception.Message)" "WARN"; $copySuccess = $false }
                    } # End foreach static entry

                    # Let Invoke-ExcelOperation handle saving based on changes unless errors occurred
                    if ($copySuccess) {
                        Show-ExcelProgress -Status "Saving CAA..." -PercentComplete 85 -ID 4
                        Write-AppLog "CAA Workbook changes applied successfully for '$($using:id2)'. Save handled by Invoke-ExcelOperation." "INFO"
                    } else {
                        Write-AppLog "Errors during Excel copy for '$($using:id2)'. CAA changes might be incomplete. Check logs." "WARN"
                        # $CaaWorkbook.Saved = $true # Explicitly prevent saving if errors occurred
                    }
                } catch { Handle-Error -ErrorRecord $_ -Context "Excel data copy Request->CAA for '$($using:id2)'"; $copySuccess = $false }
                finally { if ($requestWorkbook -ne $null) { try { $requestWorkbook.Close($false) } catch {} } }
                return $copySuccess # Return status to Process-ExcelWithTempCopy
            } # End Invoke-ExcelOperation ScriptBlock for copy
        } # End Process-ExcelWithTempCopy Call for copy

        if (-not $copyResult) { Show-Warning "Excel data copying from Request to CAA encountered errors or was skipped. Check logs." }
        else { Show-Success "Data copied from Request to CAA successfully." }
    } else {
        Write-AppLog "Skipping Excel data copy for '$id2' (CAA or Request file missing/copy failed)." "INFO"
        Show-Warning "Skipping data copy from Request to CAA as one or both files are missing or failed validation/copy."
    }

    # --- Create T2020 File ---
    Write-AppLog "Creating T2020 file for '$id2'" "INFO"
    $t2020FileName = "t2020 - $sanitizedFolderName.txt" # Consistent naming
    $t2020FilePath = Join-Path $casDocsFolder $t2020FileName # Place in CAS_DOCS
    # Build T2020 content string
    $t2020Content = @"
Project: $($extractedData.FullName)
Client ID: $($extractedData.ClientID)
Address: $fullAddress
Description: $($extractedData.Description)

Assigned: $(Format-DateSafeDisplay $assignedDateInternal)
Due: $(Format-DateSafeDisplay $dueDateInternal)
ID1: $id1
ID2: $id2
"@
    try {
        # Ensure directory exists before writing file (already created above, but good practice)
        if (Ensure-DirectoryExists -DirectoryPath (Split-Path $t2020FilePath -Parent)) {
            $t2020Content | Out-File -FilePath $t2020FilePath -Encoding UTF8 -Force -EA Stop
            Write-AppLog "Created T2020 file: $t2020FilePath" "INFO"
            $newProject.T2020 = $t2020FileName # Store relative name in project data
        } else { throw "Could not ensure directory for T2020 file: $(Split-Path $t2020FilePath -Parent)" }
    } catch { Handle-Error -ErrorRecord $_ -Context "Creating T2020 file for '$id2'"; $newProject.T2020 = "" }

    # --- Final Save ---
    Write-AppLog "Saving new project '$id2' to JSON data file." "INFO"
    $allProjects += $newProject # Add the newly created project object
    if (Save-ProjectTodoJson -ProjectData $allProjects) {
        Show-Success "Project '$($newProject.ID2)' created successfully!"
    } else { Show-Error "CRITICAL: Failed to save the new project '$($newProject.ID2)' to the JSON file. Project files/folders were created but the entry is not saved." }
    Pause-Screen
}

function Add-ManualProject {
    Clear-Host; Draw-Title "ADD PROJECT MANUALLY"
    Show-Info "Enter project details. Press Enter to skip optional fields."
    $allProjects = Load-ProjectTodoJson # Load existing projects to check for ID2 uniqueness

    $newProjectData = [ordered]@{} # Use ordered dictionary for predictable property order

    # --- Get Required Fields ---
    $newProjectData.FullName = Get-InputWithPrompt "Full Name (Required)"
    if ([string]::IsNullOrWhiteSpace($newProjectData.FullName)) { Write-AppLog "Manual Add cancelled - Full Name required." "INFO"; Show-Error "Project Full Name is required."; Pause-Screen; return }

    while ($true) {
        $newProjectData.ID2 = Get-InputWithPrompt "Project ID2 (Unique, Required)"
        if ([string]::IsNullOrWhiteSpace($newProjectData.ID2)) { Show-Warning "Project ID2 cannot be empty."; continue }
        if ($allProjects | Where-Object { $_.ID2 -eq $newProjectData.ID2 }) { Show-Warning "Project ID2 '$($newProjectData.ID2)' already exists. Please enter a unique ID." }
        else { break } # Unique ID2 entered
    }

    # --- Get Optional Fields ---
    $newProjectData.ID1 = Get-InputWithPrompt "ID1 (Optional)"

    # Dates (with validation loop)
    $defaultAssignedInternal = (Get-Date).ToString($global:DATE_FORMAT_INTERNAL)
    while($true){
        $assignedInput = Get-InputWithPrompt "Assigned Date ($($global:AppConfig.displayDateFormat))" $defaultAssignedInternal -ForceDefaultFormat
        $newProjectData.AssignedDate = Parse-DateSafeInternal $assignedInput
        if (-not [string]::IsNullOrEmpty($newProjectData.AssignedDate)) { break }
        Show-Warning "Invalid date format. Please use format: $($global:AppConfig.displayDateFormat)"
    }
    try { $assignedDT = [datetime]::ParseExact($newProjectData.AssignedDate, $global:DATE_FORMAT_INTERNAL, $null) }
    catch { Handle-Error $_ "Parsing manual assigned date"; Pause-Screen; return } # Should not happen after loop

    $defaultDueInternal = $assignedDT.AddDays(42).ToString($global:DATE_FORMAT_INTERNAL)
    while($true){
        $dueInput = Get-InputWithPrompt "Due Date ($($global:AppConfig.displayDateFormat))" $defaultDueInternal -ForceDefaultFormat
        $newProjectData.DueDate = Parse-DateSafeInternal $dueInput
        if (-not [string]::IsNullOrEmpty($newProjectData.DueDate)) { break }
        Show-Warning "Invalid date format. Please use format: $($global:AppConfig.displayDateFormat)"
    }

    while($true){
        $bfInput = Get-InputWithPrompt "BF Date ($($global:AppConfig.displayDateFormat) or Enter to skip)"
        if([string]::IsNullOrWhiteSpace($bfInput)) { $newProjectData.BFDate = ""; break }
        $newProjectData.BFDate = Parse-DateSafeInternal $bfInput
        if (-not [string]::IsNullOrEmpty($newProjectData.BFDate)) { break }
        Show-Warning "Invalid date format. Please use format: $($global:AppConfig.displayDateFormat)"
    }

    # Status and Folder
    $newProjectData.Status = "Active"
    $newProjectData.CompletedDate = ""

    Show-Info "Select the main project folder (optional)."
    $parentFolderSelected = Browse-DirectoriesNumeric -Title "Select Parent Directory for Project Folder" -StartPath "C:\"
    $newProjectData.ProjFolder = "" # Initialize ProjFolder path

    if ($parentFolderSelected) {
        Show-Info "Parent folder selected: $parentFolderSelected"
        # Create the actual project folder based on ID2 within the selected parent
        $sanitizedFolderName = $newProjectData.ID2 -replace '[\\/:*?"<>|]+', '_'
        $projectFolder = Join-Path $parentFolderSelected $sanitizedFolderName
        $newProjectData.ProjFolder = $projectFolder # Store the calculated full path

        # <<< MODIFICATION: Create Folder Structure >>>
        Show-Info "Creating folder structure for '$($newProjectData.ID2)'..."
        $docsFolder = Join-Path $projectFolder "__DOCS__"
        $casDocsFolder = Join-Path $docsFolder "__CAS_DOCS__"
        $tpDocsFolder = Join-Path $docsFolder "__TP_DOCS__"

        if (Test-Path $projectFolder) {
            Write-AppLog "Manual Project: Target folder '$projectFolder' already exists." "WARN"
            Show-Warning "Target project folder '$projectFolder' already exists. Not recreating structure."
        } else {
            try {
                if (-not (Ensure-DirectoryExists -DirectoryPath $projectFolder)) { throw "Failed ensure project folder" }
                if (-not (Ensure-DirectoryExists -DirectoryPath $docsFolder)) { throw "Failed ensure docs folder" }
                if (-not (Ensure-DirectoryExists -DirectoryPath $casDocsFolder)) { throw "Failed ensure cas_docs folder" }
                if (-not (Ensure-DirectoryExists -DirectoryPath $tpDocsFolder)) { throw "Failed ensure tp_docs folder" }
                Show-Success "Created project folder structure at '$projectFolder'."
            } catch { Handle-Error $_ "Creating manual project folders for '$($newProjectData.ID2)'"; Pause-Screen; return } # Stop if folder creation fails
        }
        # <<< END MODIFICATION >>>

    } else {
        Show-Info "No parent folder selected. Project folder path will not be set."
    }


    # File Names (relative to project folder expected, but paths are not validated here)
    Show-Warning "Enter relative filenames (e.g., 'MyCAA.xlsm') or leave blank."
    $newProjectData.CAAName = Get-InputWithPrompt "CAA Filename (optional, relative)"
    $newProjectData.RequestName = Get-InputWithPrompt "Request Filename (optional, relative)"
    $newProjectData.T2020 = Get-InputWithPrompt "T2020 Filename (optional, relative)"

    # Initialize empty Todos array
    $newProjectData.Todos = @()

    # --- Confirmation ---
    Clear-Host; Draw-Title "REVIEW MANUAL PROJECT"
    # Use PSStyle for display
    $theme = $global:currentTheme
    $labelStyle = Get-PSStyleValue $theme "Palette.SecondaryFG" "#808080" "Foreground"
    $valueStyle = Get-PSStyleValue $theme "Palette.DataFG" "#FFFFFF" "Foreground"
    $newProjectData.GetEnumerator() | ForEach-Object {
        $displayValue = if ($_.Name -match 'Date' -and -not [string]::IsNullOrEmpty($_.Value)) { Format-DateSafeDisplay $_.Value } else { $_.Value }
        Write-Host (Apply-PSStyle -Text " $($_.Name.PadRight(15)): " -FG $labelStyle) -NoNewline
        Write-Host (Apply-PSStyle -Text $displayValue -FG $valueStyle)
    }
    Write-Host ("-" * 40)

    $confirm = Confirm-ActionNumeric -ActionDescription "Save this manually added project?"
    if ($confirm -ne $true) { Write-AppLog "Manual project add cancelled by user after review." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

    # Create object and save
    $newProjectObject = [PSCustomObject]$newProjectData
    $allProjects = @($allProjects) + $newProjectObject # Add to the loaded list

    Write-AppLog "Attempting to save manually added project '$($newProjectObject.ID2)'" "INFO"
    if (Save-ProjectTodoJson -ProjectData $allProjects) {
        Show-Success "Project '$($newProjectObject.ID2)' added manually."
    } else {
        Show-Error "Failed to save manually added project." # Error handled by Save func
    }
    Pause-Screen
}
# --- Other Project Management Functions ---

# Add-ManualProject, Show-ProjectList, Set-Project, Set-ProjectComplete,

# Remove-Project, Open-ProjectFiles

# (Keep the existing versions of these functions as provided in the original script)

 

#endregion Project Management Functions

 

 

# --- END REPLACEMENT CODE ---

 

 

#region Numeric Input Helpers (Copied from PMCV8iv - Use PSStyle UI Helpers)

function Get-NumericChoice {

    param(

        [string]$Prompt,

        [int]$MinValue,

        [int]$MaxValue,

        [string]$CancelOption = "0",

        [string]$CancelText = "Cancel"

    )

    $theme = $global:currentTheme

    # Construct the full prompt string including range and cancel option

    $fullPrompt = "$Prompt ($MinValue-$MaxValue"

    if (-not [string]::IsNullOrEmpty($CancelOption)) {

        $fullPrompt += ", $CancelOption=$CancelText"

    }

    $fullPrompt += ")"

 

    while ($true) {

        # Use the PSStyle version of Get-InputWithPrompt

        $input = Get-InputWithPrompt -Prompt $fullPrompt

 

        if (-not [string]::IsNullOrEmpty($CancelOption) -and $input -eq $CancelOption) {

            return $null # Return null for cancellation

        }

        $choice = 0

        if ([int]::TryParse($input, [ref]$choice)) {

            if ($choice -ge $MinValue -and $choice -le $MaxValue) {

                return $choice # Return the valid integer choice

            } else {

                Show-Warning "Input '$input' is outside the allowed range ($MinValue-$MaxValue)."

            }

        } else {

            Show-Warning "Invalid input '$input'. Please enter a number."

        }

    }

}

 

function Confirm-ActionNumeric {

    param(

        [string]$ActionDescription,

        [string]$YesText = "Yes",

        [string]$NoText = "No",

        [string]$CancelText = "Cancel"

    )

    # Use 1=Yes, 2=No, 0=Cancel convention

    $promptText = "$ActionDescription ([1] $YesText / [2] $NoText / [0] $CancelText)"

    # Call Get-NumericChoice with the defined range and cancel option

    $choice = Get-NumericChoice -Prompt $promptText -MinValue 0 -MaxValue 2 -CancelOption "0" -CancelText $CancelText

 

    # Return true for Yes (1), false for No (2), null for Cancel (0 or invalid input)

    switch ($choice) {

        1 { return $true }

        2 { return $false }

        default { return $null } # Handles 0 and null case

    }

}

#endregion

 

#region Initialization (Copied from PMCV8iv - Uses PSStyle UI Helpers)

function Initialize-DataDirectory {

    if ($null -eq $Global:AppConfig) {

         Write-Error "FATAL: Cannot initialize data directory - AppConfig is null."

         return $false

    }

    $projectDataDir = Split-Path -Path $Global:AppConfig.projectsFile -Parent -ErrorAction SilentlyContinue

    if (-not $projectDataDir -or -not (Ensure-DirectoryExists -DirectoryPath $projectDataDir)) {

         Show-Error "Cannot proceed without project data directory '$projectDataDir'. Check config.json. Exiting."

         Pause-Screen

         exit 1

    }

 

    $commandsDir = $Global:AppConfig.commandsFolder

    if (-not $commandsDir -or -not (Ensure-DirectoryExists -DirectoryPath $commandsDir)) {

        Show-Warning "Could not ensure Commands directory exists: '$commandsDir'."

    }

 

    # Ensure core CSV files have basic structure

    Ensure-CsvStructure -FilePath $Global:AppConfig.timeTrackingFile -Headers "Date,ID2,Hours,Description"

    # Add checks for other essential files if needed

 

    # Validate CAA Template Path

    if (-not $Global:AppConfig.caaTemplatePath -or -not (Test-Path $Global:AppConfig.caaTemplatePath -PathType Leaf)) {

        Write-AppLog "CAA Template path invalid or file not found: '$($Global:AppConfig.caaTemplatePath)'" "ERROR"

        Show-Error "Master CAA Template file not found or path invalid: '$($Global:AppConfig.caaTemplatePath)'"

        Show-Error "Please update using 'Configure Settings' (Option C) or edit config.json."

        Pause-Screen

        # Decide if this is fatal or just a warning for functionality

        # return $false # If fatal

    } else {

        Write-AppLog "CAA Template found: $($Global:AppConfig.caaTemplatePath)" "INFO"

    }

    return $true # Indicate successful initialization checks (or non-fatal issues)

}

 

function Ensure-CsvStructure {

    param(

        [string]$FilePath,

        [string[]]$Headers

    )

    $headerString = $Headers -join ','

    $dirPath = Split-Path -Path $FilePath -Parent -ErrorAction SilentlyContinue

 

    # Ensure directory exists first

    if (-not $dirPath -or -not (Ensure-DirectoryExists -DirectoryPath $dirPath)) {

        Write-AppLog "Cannot ensure CSV structure for '$FilePath', directory failed." "ERROR"

        return $false

    }

 

    # If file doesn't exist, create it with headers

    if (-not (Test-Path $FilePath)) {

        try {

            Set-Content -Path $FilePath -Value $headerString -Encoding UTF8 -Force -ErrorAction Stop

            Write-AppLog "Created new CSV with headers: $FilePath" "INFO"

            return $true

        } catch {

            Handle-Error $_ "Creating CSV file '$FilePath'"

            return $false

        }

    }

 

    # File exists, check header

    try {

        # Read only the first line efficiently

        $currentHeaderLine = Get-Content $FilePath -TotalCount 1 -Encoding UTF8 -ErrorAction Stop

 

        # Handle empty or whitespace-only file

        if ($currentHeaderLine -eq $null -or [string]::IsNullOrWhiteSpace($currentHeaderLine)) {

             Write-AppLog "CSV file '$FilePath' is empty or has blank header. Writing headers." "WARN"

             Set-Content -Path $FilePath -Value $headerString -Encoding UTF8 -Force -ErrorAction Stop

             return $true

        }

 

        # Compare headers (case-insensitive, ignoring whitespace)

        $existingHeaders = $currentHeaderLine.Trim() -split ',' | ForEach-Object { $_.Trim() }

        $requiredHeaders = $Headers | ForEach-Object { $_.Trim() }

 

        if ($existingHeaders -join ',' -eq $requiredHeaders -join ',') {

            # Headers match exactly (order and content)

            Write-AppLog "CSV structure verified: $FilePath" "DEBUG"

            return $true

        } else {

            # Headers differ, attempt safe update (if possible) or warn

            Write-AppLog "CSV header mismatch for '$FilePath'. Expected: '$($requiredHeaders -join ',')', Found: '$($existingHeaders -join ',')'" "WARN"

            # For critical files like time tracking, potentially backup and overwrite if simple

            if($FilePath -eq $Global:AppConfig.timeTrackingFile) {

                # Decide on recovery strategy: Overwrite if empty/small, otherwise warn strongly

                 $fileInfo = Get-Item $FilePath

                 if ($fileInfo.Length -lt 100 -and (Get-Content $FilePath | Measure-Object).Count -le 1) {

                      Write-AppLog "Overwriting small/empty time tracking CSV with incorrect header." "WARN"

                      $backupPath = "$FilePath.backup_headerfix_$(Get-Date -Format 'yyyyMMddHHmmss')"

                      Copy-Item -Path $FilePath -Destination $backupPath -Force -EA SilentlyContinue

                      Set-Content -Path $FilePath -Value $headerString -Encoding UTF8 -Force -EA Stop

                      Show-Warning "Time tracking file header was incorrect and has been reset."

                      return $true

                 } else {

                      Show-Error "CRITICAL: Time tracking file '$FilePath' header is incorrect. Manual check required!"

                      Pause-Screen

                      return $false # Indicate failure for critical file mismatch

                 }

            } else {

                # For non-critical files, just warn

                 Show-Warning "CSV file '$FilePath' header does not match expected structure. Functionality may be affected."

                 return $true # Allow continuation but log the issue

            }

        }

    } catch {

        Handle-Error $_ "Validating CSV structure for '$FilePath'"

        return $false

    }

}

#endregion

 

#region File Browsers (Uses PSStyle UI Helpers)

function Browse-DirectoriesNumeric {

    param (

        [string]$StartPath = "C:\",

        [string]$Title = "Select a directory"

    )

    $theme = $global:currentTheme

    # Get PSStyle colors using helper

    $highlightStyle = Get-PSStyleValue $theme "Palette.HighlightBG" "#005FFF" "Background" # Use BG for full line highlight

    $highlightFgStyle = Get-PSStyleValue $theme "Palette.HighlightFG" "#FFFFFF" "Foreground"

    $optionStyle = Get-PSStyleValue $theme "Menu.Option.FG" "#FFFFFF" "Foreground"

    $disabledStyle = Get-PSStyleValue $theme "Palette.DisabledFG" "#808080" "Foreground"

    $dataStyle = Get-PSStyleValue $theme "Palette.DataFG" "#FFFFFF" "Foreground"

    $promptStyle = Get-PSStyleValue $theme "Palette.InputPrompt" "#00D7FF" "Foreground" # Palette used InputPrompt

    $successStyle = Get-PSStyleValue $theme "Palette.SuccessFG" "#5FFF87" "Foreground"

    $warnStyle = Get-PSStyleValue $theme "Palette.WarningFG" "#FFFF00" "Foreground"

 

    $currentPath = $StartPath

    try {

        $currentPath = (Resolve-Path $currentPath -EA Stop).ProviderPath

        if (-not (Test-Path $currentPath -PathType Container)) {

            $currentPath = Split-Path $currentPath -Parent

            if (-not (Test-Path $currentPath -PathType Container)) { $currentPath = "C:\" } # Fallback to root

        }

    } catch { $currentPath = "C:\" } # Fallback to root on error

 

    $pageSize = 15; try { $pageSize = ($Host.UI.RawUI.WindowSize.Height - 12) } catch {}; if ($pageSize -lt 5) { $pageSize = 15 }

    $page = 0

 

    while ($true) {

        Clear-Host

        Draw-Title $Title

        # Apply highlight style to current path display

        $width = 80; try { $width = $Host.UI.RawUI.WindowSize.Width } catch {};

        $currentPathDisplay = "Current: $currentPath".PadRight($width-1)

        Write-Host (Apply-PSStyle -Text $currentPathDisplay -FG $highlightFgStyle -BG $highlightStyle)

        Write-Host ""

 

        $parent = ""; $canGoUp = $false

        try {

            $parentInfo = Get-Item $currentPath | Get-Item -PSProvider Filesystem | Select -Expand Parent

            if ($parentInfo) {

                $parent = $parentInfo.FullName

                if ($parent -ne $currentPath) { $canGoUp = $true }

            }

        } catch {}

 

        $displayItems = @{} # Map display number to action/path

        $displayIndex = 1

 

        # Option 0: Up directory or Top Level

        if ($canGoUp) {

            Write-Host (Apply-PSStyle -Text " 0. [Up to '$((Split-Path $parent -Leaf) -replace '^$','Root')']" -FG $optionStyle)

            $displayItems[0] = @{ Action = "Up"; Path = $parent }

        } else {

            Write-Host (Apply-PSStyle -Text " 0. [Top Level]" -FG $disabledStyle)

            $displayItems[0] = @{ Action = "None" }

        }

 

        # Get directories for current page

        $allDirs = @(); $accessError = $null

        try {

            # Filter out hidden/system dirs if desired: -Attributes !Hidden,!System

            $allDirs = @(Get-ChildItem -Path $currentPath -Directory -EA SilentlyContinue -ErrorVariable +accessError)

        } catch {

            Handle-Error -ErrorRecord $_ -Context "Accessing path '$currentPath' in directory browser"

            Pause-Screen; if ($canGoUp) { $currentPath = $parent; continue } else { return $null }

        }

        if ($accessError) {

            foreach($err in $accessError){

                 # Only show specific permission errors to user, log others

                 if ($err.CategoryInfo.Reason -eq 'UnauthorizedAccessException') {

                     Show-Warning "Access denied listing some items in '$currentPath'."

                 } else {

                     Write-AppLog "Error listing directories in '$currentPath': $($err.Exception.Message)" "WARN"

                 }

            }

        }

 

        $totalDirs = $allDirs.Count

        $totalPages = [Math]::Ceiling($totalDirs / $pageSize)

        if ($page -ge $totalPages -and $page -gt 0) { $page = $totalPages - 1 } # Adjust page if out of bounds

 

        $dirs = $allDirs | Sort-Object Name | Select-Object -Skip ($page * $pageSize) -First $pageSize

 

        # Display directories for the current page

        foreach ($dir in $dirs) {

            Write-Host (Apply-PSStyle -Text "$($displayIndex). $($dir.Name)" -FG $dataStyle)

            $displayItems[$displayIndex] = @{ Action = "Enter"; Path = $dir.FullName }

            $displayIndex++

        }

 

        if ($dirs.Count -eq 0 -and $totalDirs -gt 0) { Write-Host (Apply-PSStyle -Text " (No directories on this page)" -FG $disabledStyle) }

        elseif ($totalDirs -eq 0) { Write-Host (Apply-PSStyle -Text " (No sub-directories)" -FG $disabledStyle) }

 

        # Pagination and Selection Options

        $maxItemIndex = $displayIndex - 1 # Highest number for directory selection

        $pagePrompt = ""; $allowedMax = $maxItemIndex; $showPageOpts = $false

 

        # Add pagination options if multiple pages

        if ($totalPages -gt 1) {

            $showPageOpts = $true

            $pagePrompt = " Page $($page + 1)/$totalPages"

            if ($page -gt 0) {

                Write-Host (Apply-PSStyle -Text "98. Previous Page" -FG $promptStyle)

                $displayItems[98] = @{ Action = "PrevPage" }; $allowedMax = 99

            }

            if ($page -lt $totalPages - 1) {

                Write-Host (Apply-PSStyle -Text "99. Next Page" -FG $promptStyle)

                $displayItems[99] = @{ Action = "NextPage" }; $allowedMax = 99

            }

        }

 

        # Add standard options

        Write-Host (Apply-PSStyle -Text "97. Select Current Directory '$((Split-Path $currentPath -Leaf) -replace '^$','Root')'" -FG $successStyle)

        $displayItems[97] = @{ Action = "SelectCurrent"; Path = $currentPath }; $allowedMax = 99

        Write-Host (Apply-PSStyle -Text "96. Cancel" -FG $warnStyle)

        $displayItems[96] = @{ Action = "Cancel" }; $allowedMax = 99

 

        # Get user choice

        $choice = Get-NumericChoice -Prompt "Enter choice$pagePrompt" -MinValue 0 -MaxValue $allowedMax -CancelOption "96"

 

        if ($choice -eq $null) { return $null } # Cancelled via '96' or invalid input in Get-NumericChoice

 

        if ($displayItems.ContainsKey($choice)) {

            $selectedAction = $displayItems[$choice].Action

            $selectedPath = $displayItems[$choice].Path

 

            switch ($selectedAction) {

                "Up" { $currentPath = $selectedPath; $page = 0 }

                "Enter" {

                    try {

                        # Quick check if directory is accessible before changing path

#                        [void](Get-ChildItem -Path $selectedPath -LiteralPath -EA Stop | Select-Object -First 1)

                        [void](Get-ChildItem -LiteralPath $selectedPath -EA Stop | Select-Object -First 1)

                        $currentPath = $selectedPath; $page = 0

                    } catch {

                        Handle-Error -ErrorRecord $_ -Context "Accessing selected directory '$selectedPath'"

                        Pause-Screen # Stay in current directory

                    }

                }

                "PrevPage" { if ($page -gt 0) { $page-- } }

                "NextPage" { if ($page -lt $totalPages - 1) { $page++ } }

                "SelectCurrent" { return $selectedPath } # Return the currently selected directory

                "Cancel" { return $null }

                "None" { } # Do nothing for 'Top Level' option 0

                default { Show-Warning "Invalid internal action: $selectedAction" } # Should not happen

            }

        } else {

             # This case should be rare now Get-NumericChoice handles range

            Show-Warning "Invalid number entered."

            Pause-Screen

        }

    } # End while loop

}

 

function Browse-FilesNumeric {

    param (

        [string]$StartPath = "C:\",

        [string]$Title = "Select a file",

        [string]$Filter = "*.*" # Allow filtering

    )

    # This function remains largely similar to Browse-DirectoriesNumeric

    # Key differences: Lists files, filter, selection returns file path

    $theme = $global:currentTheme

    $highlightStyle = Get-PSStyleValue $theme "Palette.HighlightBG" "#005FFF" "Background"

    $highlightFgStyle = Get-PSStyleValue $theme "Palette.HighlightFG" "#FFFFFF" "Foreground"

    $optionStyle = Get-PSStyleValue $theme "Menu.Option.FG" "#FFFFFF" "Foreground"

    $disabledStyle = Get-PSStyleValue $theme "Palette.DisabledFG" "#808080" "Foreground"

    $dataStyle = Get-PSStyleValue $theme "Palette.DataFG" "#FFFFFF" "Foreground"

    $promptStyle = Get-PSStyleValue $theme "Palette.InputPrompt" "#00D7FF" "Foreground"

    $successStyle = Get-PSStyleValue $theme "Palette.SuccessFG" "#5FFF87" "Foreground"

    $warnStyle = Get-PSStyleValue $theme "Palette.WarningFG" "#FFFF00" "Foreground"

 

    $currentPath = $StartPath

    try { # Resolve starting path, ensure it's a directory

        $resolved = Resolve-Path $currentPath -ErrorAction Stop

        if ($resolved.ProviderPath -ne $resolved.Path -and (Test-Path $resolved.ProviderPath -PathType Container)) {

             $currentPath = $resolved.ProviderPath # Use provider path if different and valid dir

        } elseif (Test-Path $resolved.Path -PathType Container) {

             $currentPath = $resolved.Path

        } else {

             $currentPath = Split-Path $resolved.Path -Parent

        }

        if (-not (Test-Path $currentPath -PathType Container)) { $currentPath = "C:\" }

    } catch { $currentPath = "C:\" }

 

    $pageSize = 15; try { $pageSize = ($Host.UI.RawUI.WindowSize.Height - 12) } catch {}; if ($pageSize -lt 5) { $pageSize = 15 }

    $page = 0

 

    while ($true) {

        Clear-Host

        Draw-Title $Title

        $width = 80; try { $width = $Host.UI.RawUI.WindowSize.Width } catch {};

        $currentPathDisplay = "Current: $currentPath Filter: $Filter".PadRight($width-1)

        Write-Host (Apply-PSStyle -Text $currentPathDisplay -FG $highlightFgStyle -BG $highlightStyle)

        Write-Host ""

 

        $parent = ""; $canGoUp = $false

        try {

            $parentInfo = Get-Item $currentPath | Get-Item -PSProvider Filesystem | Select -Expand Parent

            if ($parentInfo) { $parent = $parentInfo.FullName; if ($parent -ne $currentPath) { $canGoUp = $true } }

        } catch {}

 

        $displayItems = @{}

        $displayIndex = 1

 

        # Option 0: Up directory

        if ($canGoUp) {

            Write-Host (Apply-PSStyle -Text " 0. [Up to '$((Split-Path $parent -Leaf) -replace '^$','Root')']" -FG $optionStyle)

            $displayItems[0] = @{ Action = "Up"; Path = $parent }

        } else {

            Write-Host (Apply-PSStyle -Text " 0. [Top Level]" -FG $disabledStyle)

            $displayItems[0] = @{ Action = "None" }

        }

 

        # Get Files and Directories

        $allItems = @(); $accessError = $null

        try {

            # Get directories first, then files matching filter

            $dirs = @(Get-ChildItem -Path $currentPath -Directory -EA SilentlyContinue -ErrorVariable +accessError)

            $files = @(Get-ChildItem -Path $currentPath -File -Filter $Filter -EA SilentlyContinue -ErrorVariable +accessError)

            $allItems = @($dirs) + @($files)

        } catch {

            Handle-Error -ErrorRecord $_ -Context "Accessing path '$currentPath' in file browser"

            Pause-Screen; if ($canGoUp) { $currentPath = $parent; continue } else { return $null }

        }

         if ($accessError) {

            foreach($err in $accessError){

                 if ($err.CategoryInfo.Reason -eq 'UnauthorizedAccessException') {

                     Show-Warning "Access denied listing some items in '$currentPath'."

                 } else {

                     Write-AppLog "Error listing items in '$currentPath': $($err.Exception.Message)" "WARN"

                 }

            }

        }

 

 

        $totalItems = $allItems.Count

        $totalPages = [Math]::Ceiling($totalItems / $pageSize)

        if ($page -ge $totalPages -and $page -gt 0) { $page = $totalPages - 1 }

 

        # Sort: Dirs first, then files, alphabetically within each group

        $itemsToShow = $allItems | Sort-Object @{Expression={$_.PSIsContainer}; Descending=$true}, Name | Select-Object -Skip ($page * $pageSize) -First $pageSize

 

        # Display items

        foreach ($item in $itemsToShow) {

            $isDir = $item.PSIsContainer

            $prefix = if ($isDir) { "[DIR] " } else { "      " }

            $itemText = "$($prefix)$($item.Name)"

            $itemStyle = if ($isDir) { $optionStyle } else { $dataStyle } # Style dirs like options, files like data

 

            Write-Host (Apply-PSStyle -Text "$($displayIndex). $itemText" -FG $itemStyle)

 

            if ($isDir) {

                $displayItems[$displayIndex] = @{ Action = "EnterDir"; Path = $item.FullName }

            } else {

                $displayItems[$displayIndex] = @{ Action = "SelectFile"; Path = $item.FullName }

            }

            $displayIndex++

        }

 

        if ($itemsToShow.Count -eq 0 -and $totalItems -gt 0) { Write-Host (Apply-PSStyle -Text " (No items match filter on this page)" -FG $disabledStyle) }

        elseif ($totalItems -eq 0) { Write-Host (Apply-PSStyle -Text " (No items in this directory)" -FG $disabledStyle) }

 

        # Pagination and Cancel Options

        $maxItemIndex = $displayIndex - 1

        $pagePrompt = ""; $allowedMax = $maxItemIndex;

 

        if ($totalPages -gt 1) {

            $pagePrompt = " Page $($page + 1)/$totalPages"

            if ($page -gt 0) { Write-Host (Apply-PSStyle -Text "98. Previous Page" -FG $promptStyle); $displayItems[98] = @{ Action = "PrevPage" }; $allowedMax = 99 }

            if ($page -lt $totalPages - 1) { Write-Host (Apply-PSStyle -Text "99. Next Page" -FG $promptStyle); $displayItems[99] = @{ Action = "NextPage" }; $allowedMax = 99 }

        }

        Write-Host (Apply-PSStyle -Text "96. Cancel" -FG $warnStyle)

        $displayItems[96] = @{ Action = "Cancel" }; $allowedMax = 99

 

        # Get user choice

        $choice = Get-NumericChoice -Prompt "Select file/dir #$pagePrompt" -MinValue 0 -MaxValue $allowedMax -CancelOption "96"

 

        if ($choice -eq $null) { return $null }

 

        if ($displayItems.ContainsKey($choice)) {

            $selectedAction = $displayItems[$choice].Action

            $selectedPath = $displayItems[$choice].Path

 

            switch ($selectedAction) {

                "Up" { $currentPath = $selectedPath; $page = 0 }

                "EnterDir" {

#                     try { [void](Get-ChildItem -Path $selectedPath -LiteralPath -EA Stop | Select -First 1); $currentPath = $selectedPath; $page = 0 }

                     try { [void](Get-ChildItem -LiteralPath $selectedPath -EA Stop | Select -First 1); $currentPath = $selectedPath; $page = 0 }

                     catch { Handle-Error -ErrorRecord $_ -Context "Accessing directory '$selectedPath'"; Pause-Screen }

                 }

                "SelectFile" { return $selectedPath } # Return the selected file path

                "PrevPage" { if ($page -gt 0) { $page-- } }

                "NextPage" { if ($page -lt $totalPages - 1) { $page++ } }

                "Cancel" { return $null }

                "None" { }

                default { Show-Warning "Invalid internal action: $selectedAction" }

            }

        } else {

            Show-Warning "Invalid number entered."

            Pause-Screen

        }

    } # End while loop

}

#endregion

 

#region Selection Helpers (Uses PSStyle UI Helpers)

function Select-ItemFromList {

    param(

        [string]$Title,

        [string]$Prompt = "Select item number",

        [array]$Items,

        [string]$ViewType # Determines columns via $global:tableConfig

    )

    $Items = @($Items) # Ensure array

    if ($Items.Count -eq 0) {

        Show-Warning "No items available for selection."

        return $null

    }

 

    $theme = $global:currentTheme

    # Get styles using PSStyle helpers

    $promptStyle = Get-PSStyleValue $theme "Palette.InputPrompt" "#00D7FF" "Foreground"

    $warnStyle = Get-PSStyleValue $theme "Palette.WarningFG" "#FFFF00" "Foreground"

    $infoStyle = Get-PSStyleValue $theme "Palette.InfoFG" "#5FD7FF" "Foreground"

 

    $pageSize = 15; try { $pageSize = ($Host.UI.RawUI.WindowSize.Height - 10) } catch {}; if ($pageSize -lt 5) { $pageSize = 10 }

    $page = 0

    $totalPages = [Math]::Ceiling($Items.Count / $pageSize)

 

    while($true) {

        Clear-Host

        Draw-Title $Title

 

        $startIndex = $page * $pageSize

        $pagedItems = $Items | Select-Object -Skip $startIndex -First $pageSize

 

        $tableData = @() # Data to pass to Format-TableUnicode

        $itemMap = @{}   # Maps the displayed number (1..) to the original item

        $displayIndex = 1

 

        for ($i = 0; $i -lt $pagedItems.Count; $i++) {

            $item = $pagedItems[$i]

            $row = @($displayIndex.ToString()) # Start row with the selection number

 

            # Build the rest of the row based on ViewType

            switch ($ViewType) {

                "ProjectSelection" {

                    $status = if ([string]::IsNullOrEmpty($item.CompletedDate)) { "Active" } else { "Done $(Format-DateSafeDisplay $item.CompletedDate)" }

                    $row += $item.ID2, $item.FullName, $status

                }

                "TodoSelection" {

                    $row += $item.Task, $item.Status, (Format-DateSafeDisplay $item.DueDate), $item.Priority

                }

                "CommandSelection" {

                    $name = $item.BaseName # Assumes item is FileInfo or PSCustomObject with BaseName

                    $description = ""

                    # Attempt to get description from PSCustomObject or file content

                    if ($item -is [System.IO.FileInfo]) {

                         try {

                            $content = Get-Content -Path $item.FullName -TotalCount 5 -Encoding utf8 -EA SilentlyContinue

                            $descLine = $content | Where-Object { $_ -match '^\s*#\s*Description:\s*(.+)' } | Select-Object -First 1

                            if ($descLine) { $description = $matches[1].Trim() }

                         } catch {}

                    } elseif ($item.PSObject.Properties.Name -contains 'Description') {

                         $description = $item.Description

                    }

                    $row += $name, $description

                }

                "NoteSelection" { # Assumes item is FileInfo

                    $modTime = try { $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm') } catch { "N/A" }

                    $row += $item.Name, $modTime

                }

                default {

                    Write-AppLog "Unsupported ViewType for selection list: $ViewType" "ERROR"

                    Show-Error "Unsupported list ViewType: $ViewType"

                    Pause-Screen

                    return $null

                }

            }

            $tableData += ,$row       # Add the complete row to table data

            $itemMap[$displayIndex] = $item # Map the display number to the actual item

            $displayIndex++

        }

 

        # Display the table using the PSStyle version

        Format-TableUnicode -ViewType $ViewType -Data $tableData # RowColors could be added here if needed

 

        Write-Host "" # Spacer

 

        # Build prompt text with pagination info

        $promptSuffix = "(1-$($pagedItems.Count)"

        $allowedMin = 1

        $allowedMax = $pagedItems.Count

        $options = @()

 

        if ($totalPages -gt 1) {

            $promptSuffix += ", "

            if ($page -gt 0) {

                $options += "98=Prev"

                $allowedMax = 99

            } else { $options += "        " } # Placeholder for alignment

            if ($page -lt ($totalPages - 1)) {

                $options += "99=Next"

                $allowedMax = 99

            } else { $options += "        " }

            $promptSuffix += "98/99=Page"

            # Apply style to page info line

            Write-Host (Apply-PSStyle -Text " Page $($page + 1) of $totalPages ($($options -join ', '))" -FG $infoStyle)

        }

 

        $promptSuffix += ", 0=Cancel)"

        # Apply style to Cancel option

        Write-Host (Apply-PSStyle -Text " 0. Cancel Selection" -FG $warnStyle)

 

        # Get choice using PSStyle prompt helper

        $choice = Get-NumericChoice -Prompt "$Prompt $promptSuffix" -MinValue 0 -MaxValue $allowedMax -CancelOption "0"

 

        if ($choice -eq $null) { return $null } # User cancelled

 

        switch ($choice) {

            0  { return $null } # Explicit cancel

            98 { if ($page -gt 0) { $page-- } } # Prev page

            99 { if ($page -lt ($totalPages - 1)) { $page++ } } # Next page

            default {

                if ($itemMap.ContainsKey($choice)) {

                    return $itemMap[$choice] # Return the selected item object

                } else {

                    Show-Warning "Invalid selection number."

                    Pause-Screen # Pause briefly before re-displaying

                }

            }

        }

    } # End while loop

}

#endregion

 

#region Project Management Functions (Keep PMCV8iv logic, update UI calls to PSStyle)

function New-ProjectFromRequest {

    Clear-Host; Draw-Title "NEW PROJECT FROM REQUEST"

    Show-Info "Select source Request XLSM file."

    # Use PSStyle file browser

    $sourceRequestPath = Browse-FilesNumeric -Title "Select Source Request File" -StartPath "C:\" -Filter "*.xlsm"

    if (-not $sourceRequestPath) { Write-AppLog "New project cancelled - no request file selected." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

 

    $validationErrors = Validate-ExcelOperation -FilePath $sourceRequestPath

    if ($validationErrors.Count -gt 0) { Write-AppLog "Request file validation failed: $($validationErrors -join '; ')" "ERROR"; foreach ($errorMsg in $validationErrors) { Show-Error $errorMsg }; Pause-Screen; return }

 

    Show-Info "Select PARENT folder for the new project directory."

    # Use PSStyle directory browser

    $parentFolder = Browse-DirectoriesNumeric -Title "Select Parent Project Folder" -StartPath "C:\"

    if (-not $parentFolder) { Write-AppLog "New project cancelled - no parent folder selected." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

    if (-not (Test-Path $parentFolder -PathType Container)) { Write-AppLog "Invalid parent folder selected: $parentFolder" "ERROR"; Show-Error "Invalid parent path selected: '$parentFolder'"; Pause-Screen; return }

 

    Write-AppLog "Starting project creation from '$sourceRequestPath' in '$parentFolder'" "INFO"

    Show-Info "Extracting data from request file..."

    $extractedData = @{ FullName = ""; ClientID = ""; Address1 = ""; Address2 = ""; Address3 = ""; Description = "" } # Initialize hash

    $extractionMappings = $global:excelMappings.Extraction

 

    # Process Excel using helper (uses Show-ExcelProgress)

    $extractResult = Process-ExcelWithTempCopy -OriginalFilePath $sourceRequestPath -ProcessingLogic {

        param($TempFilePath)

        return Invoke-ExcelOperation -FilePath $TempFilePath -ReadOnly $true -ScriptBlock {

            param($Excel, $Workbook)

            $extracted = @{ FullName = ""; ClientID = ""; Address1 = ""; Address2 = ""; Address3 = ""; Description = "" } # Ensure keys exist

            $sourceSheet = $null; $sourceSheetName = $using:global:excelMappings.Copying[0].SourceSheet; if ([string]::IsNullOrWhiteSpace($sourceSheetName)) { $sourceSheetName = "SVI-CAS" } # Default sheet name

            try { $sourceSheet = $Workbook.Worksheets.Item($sourceSheetName) } catch { try { $sourceSheet = $Workbook.Worksheets.Item(1); Write-AppLog "Excel Extraction: Sheet '$sourceSheetName' not found, using first." "WARN" } catch { throw "No valid worksheet found in '$($Workbook.Name)'." } }

            if ($null -eq $sourceSheet) { throw "Failed to get worksheet from '$($Workbook.Name)'." }

 

            # Use combined mappings for extraction

            $allMappings = $using:extractionMappings

            foreach ($mapping in $allMappings) {

                try {

                    $targetVar = $mapping.TargetVariable

                    # Skip if already extracted (prefer Label over Fixed if both exist for same var)

                    if (-not $extracted.ContainsKey($targetVar) -or [string]::IsNullOrEmpty($extracted[$targetVar])) {

                         $value = $null

                         if ($mapping.Type -eq 'Label') {

                             $offsetCol = if ($mapping.PSObject.Properties.Name -contains 'OffsetColumn') { $mapping.OffsetColumn } else { 1 }

                             $offsetRow = if ($mapping.PSObject.Properties.Name -contains 'OffsetRow') { $mapping.OffsetRow } else { 0 }

                             $valueCell = Find-CellByLabel -Worksheet $sourceSheet -LabelText $mapping.Source -OffsetColumn $offsetCol -OffsetRow $offsetRow

                             if ($valueCell) { $value = Get-CellValueTyped -Worksheet $sourceSheet -Address $valueCell -Type String }

                         } elseif ($mapping.Type -eq 'Fixed') {

                             $value = Get-CellValueTyped -Worksheet $sourceSheet -Address $mapping.Source -Type String

                         }

                         # Assign if value found and not empty

                         if (-not [string]::IsNullOrEmpty($value)) { $extracted[$targetVar] = $value; Write-AppLog "Extracted '$targetVar' using $($mapping.Type) '$($mapping.Source)'" "DEBUG" }

                         else { Write-AppLog "$($mapping.Type) '$($mapping.Source)' not found or empty for '$targetVar'." "DEBUG" }

                    } else { Write-AppLog "Already extracted '$targetVar', skipping $($mapping.Type) '$($mapping.Source)'." "DEBUG"}

                } catch { Write-AppLog "Excel Extraction Failed: Type '$($mapping.Type)' Source '$($mapping.Source)' for Var '$($mapping.TargetVariable)'. Error: $($_.Exception.Message)" "WARN" }

            }

            return $extracted

        }

    }

 

    if (-not $extractResult -is [hashtable] -or $extractResult.Count -eq 0 -or [string]::IsNullOrWhiteSpace($extractResult.FullName) -or [string]::IsNullOrWhiteSpace($extractResult.ClientID)) {

        Write-AppLog "Failed to extract required data (FullName, ClientID) from request file." "ERROR"

        Show-Error "Could not extract required data (Full Name, Client ID/ID2) from the request file. Please check the file content and mappings."

        Pause-Screen; return

    }

    # Update local data with extracted results

    foreach ($key in $extractResult.Keys) { if ($extractedData.ContainsKey($key)) { $extractedData[$key] = $extractResult[$key] } }

 

    $fullAddress = @($extractedData.Address1, $extractedData.Address2, $extractedData.Address3) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Join-String -Separator ", "

 

    # --- Confirm Details & Get Remaining Info ---

    Clear-Host; Draw-Title "CONFIRM PROJECT DETAILS"

    Show-Info "Data extracted from request file. Please confirm or provide details."

    # Use Apply-PSStyle for extracted data display

    $theme = $global:currentTheme

    $labelStyle = Get-PSStyleValue $theme "Palette.SecondaryFG" "#808080" "Foreground"

    $valueStyle = Get-PSStyleValue $theme "Palette.DataFG" "#FFFFFF" "Foreground"

    Write-Host (Apply-PSStyle -Text " Extracted Full Name : " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $extractedData.FullName -FG $valueStyle)

    Write-Host (Apply-PSStyle -Text " Extracted Client ID : " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $extractedData.ClientID -FG $valueStyle)

    Write-Host (Apply-PSStyle -Text " Extracted Address   : " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $fullAddress -FG $valueStyle)

    Write-Host (Apply-PSStyle -Text " Extracted Desc      : " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $extractedData.Description -FG $valueStyle)

    Write-Host ""

 

    $fullName = $extractedData.FullName # Use extracted name as default

    $id2 = $extractedData.ClientID # Use extracted ClientID as default ID2

 

    $allProjects = Load-ProjectTodoJson

    if ($allProjects | Where-Object { $_.ID2 -eq $id2 }) { Write-AppLog "Project creation failed - ID2 '$id2' already exists." "ERROR"; Show-Error "Project ID2 '$id2' already exists. Cannot create duplicate."; Pause-Screen; return }

 

    $id1 = Get-InputWithPrompt "Enter ID1 (Optional)" # Get optional ID1

    $defaultAssignedInternal = (Get-Date).ToString($global:DATE_FORMAT_INTERNAL)

    $assignedDateInput = Get-InputWithPrompt "Assigned date ($($global:AppConfig.displayDateFormat))" $defaultAssignedInternal -ForceDefaultFormat

    $assignedDateInternal = Parse-DateSafeInternal $assignedDateInput

    if ([string]::IsNullOrEmpty($assignedDateInternal)) { Write-AppLog "Invalid assigned date input '$assignedDateInput', defaulting to today." "WARN"; $assignedDateInternal = $defaultAssignedInternal }

    try { $assignedDate = [datetime]::ParseExact($assignedDateInternal, $global:DATE_FORMAT_INTERNAL, $null) } catch { Handle-Error $_ "Parsing assigned date '$assignedDateInternal'"; Pause-Screen; return }

 

    # Calculate default due date (e.g., 6 weeks / 42 days later)

    $defaultDueInternal = $assignedDate.AddDays(42).ToString($global:DATE_FORMAT_INTERNAL)

    $dueDateInput = Get-InputWithPrompt "Due date ($($global:AppConfig.displayDateFormat))" $defaultDueInternal -ForceDefaultFormat

    $dueDateInternal = Parse-DateSafeInternal $dueDateInput

    if ([string]::IsNullOrEmpty($dueDateInternal)) { Write-AppLog "Invalid due date input '$dueDateInput', using default." "WARN"; $dueDateInternal = $defaultDueInternal }

 

    # BF Date (Optional)

    $bfDateInput = Get-InputWithPrompt "BF date ($($global:AppConfig.displayDateFormat) or Enter skip)"

    $bfDateInternal = Parse-DateSafeInternal $bfDateInput

    if (-not [string]::IsNullOrEmpty($bfDateInput) -and [string]::IsNullOrEmpty($bfDateInternal)) { Show-Warning "Invalid BF date format entered. Skipping BF date." }

 

    # --- Create Folders ---

    Show-Info "Creating folder structure..."

    $sanitizedFolderName = $id2 -replace '[\\/:*?"<>|]+', '_' # Basic sanitization

    $projectFolder = Join-Path $parentFolder $sanitizedFolderName

    $docsFolder = Join-Path $projectFolder "__DOCS__"

    $casDocsFolder = Join-Path $docsFolder "__CAS_DOCS__"

    $tpDocsFolder = Join-Path $docsFolder "__TP_DOCS__"

 

    if (Test-Path $projectFolder) { Write-AppLog "Project folder '$projectFolder' already exists." "ERROR"; Show-Error "Target project folder '$projectFolder' already exists. Cannot continue."; Pause-Screen; return }

 

    try {

        if (-not (Ensure-DirectoryExists -DirectoryPath $projectFolder)) { throw "Failed ensure project folder" }

        if (-not (Ensure-DirectoryExists -DirectoryPath $docsFolder)) { throw "Failed ensure docs folder" }

        if (-not (Ensure-DirectoryExists -DirectoryPath $casDocsFolder)) { throw "Failed ensure cas_docs folder" }

        if (-not (Ensure-DirectoryExists -DirectoryPath $tpDocsFolder)) { throw "Failed ensure tp_docs folder" }

        Show-Success "Created project folder structure in '$parentFolder'."

    } catch { Handle-Error $_ "Creating project folders for '$id2'"; Pause-Screen; return }

 

    # --- Copy Files ---

    Show-Info "Copying files (CAA Template, Request)..."

    $targetCaaName = ""; $targetCaaPath = ""; $targetRequestName = ""; $targetRequestPath = ""

 

    # Copy CAA Template

    if ($Global:AppConfig.caaTemplatePath -and (Test-Path $Global:AppConfig.caaTemplatePath -PathType Leaf)) {

        $targetCaaName = "CAA - $sanitizedFolderName.xlsm" # Construct target name

        $targetCaaPath = Join-Path $casDocsFolder $targetCaaName

        $templateValidationErrors = Validate-ExcelOperation -FilePath $Global:AppConfig.caaTemplatePath

        if ($templateValidationErrors.Count -gt 0) { Write-AppLog "CAA Template validation failed: $($templateValidationErrors -join '; ')" "ERROR"; Show-Error "CAA Template invalid: $($templateValidationErrors -join '; ')"; $targetCaaName = ""; $targetCaaPath = "" }

        else {

            try { Copy-Item -Path $Global:AppConfig.caaTemplatePath -Destination $targetCaaPath -Force -EA Stop; Write-AppLog "Copied CAA Template to '$targetCaaPath'" "INFO" }

            catch { Handle-Error $_ "Copying CAA Template"; $targetCaaName = ""; $targetCaaPath = "" }

        }

    } else { Write-AppLog "CAA Template path invalid or not set ('$($Global:AppConfig.caaTemplatePath)'). Skipping copy." "WARN"; Show-Warning "CAA Template not found or path invalid. Skipping CAA copy." }

 

    # Copy Request File

    $targetRequestName = Split-Path -Leaf $sourceRequestPath

    $targetRequestPath = Join-Path $casDocsFolder $targetRequestName

    try { Copy-Item -Path $sourceRequestPath -Destination $targetRequestPath -Force -EA Stop; Write-AppLog "Copied Request file to '$targetRequestPath'" "INFO" }

    catch { Handle-Error $_ "Copying Request file"; $targetRequestName = "" } # Clear name if copy fails

 

    # --- Create Project Object (Initial) ---

    $newProject = [PSCustomObject]@{

        ID2=$id2; ID1=$id1; FullName=$fullName

        AssignedDate=$assignedDateInternal; DueDate=$dueDateInternal; BFDate=$bfDateInternal

        Status="Active"; CompletedDate=""

        ProjFolder=$projectFolder # Store full path

        CAAName=$targetCaaName; RequestName=$targetRequestName; T2020="" # T2020 name set later

        Todos=@() # Initialize empty Todos array

    }

 

    # --- Copy Data from Request to CAA (if files available) ---

# --- Copy Data from Request to CAA (if files available) ---

    if ($targetCaaPath -and $targetRequestPath -and (Test-Path $targetCaaPath) -and (Test-Path $targetRequestPath)) {

        Write-AppLog "Starting Excel data copy Request -> CAA for '$id2'" "INFO"

        Show-Info "Copying data from Request to CAA..."

#~~changes here      

        $copyResult = Process-ExcelWithTempCopy -OriginalFilePath $targetCaaPath -UpdateOriginal $true -ProcessingLogic {

            param($TempCaaPath) # Parameter for this scriptblock is the temp CAA path

 

            # --- NO ASSIGNMENTS NEEDED HERE ---

            # The $using: modifier is applied where the variables are READ below.

 

            # Nested ScriptBlock passed to Invoke-ExcelOperation

            # THIS is where $using: is needed to access variables from New-ProjectFromRequest's scope

            return Invoke-ExcelOperation -FilePath $TempCaaPath -ScriptBlock {

                param($Excel, $CaaWorkbook)

                $requestWorkbook = $null; $copySuccess = $true

                try {

                    Show-ExcelProgress -Activity "Excel Copy" -Status "Opening request..." -PercentComplete 60 -ID 4

                    # Use $using: here to access the variable from the outer scope

                    $requestWorkbook = $Excel.Workbooks.Open($using:targetRequestPath, 0, $true);

                    if ($null -eq $requestWorkbook) { throw "Failed open request '$using:targetRequestPath'." }

 

                    # Use $using: here

                    $copyMappings = $using:global:excelMappings.Copying

                    $staticEntries = $using:global:excelMappings.StaticEntries

 

                    # Get worksheet objects efficiently (cache within this specific invocation)

                    $sheetCache = @{}

                    Function Get-Sheet { param($Workbook, $SheetNameOrIndex)

                        # Access cache defined in this scope

                        if ($sheetCache.ContainsKey("$($Workbook.Name)_$SheetNameOrIndex")) { return $sheetCache["$($Workbook.Name)_$SheetNameOrIndex"] }

                        $sheet = $null

                        try { $sheet = $Workbook.Worksheets.Item($SheetNameOrIndex) } catch {}

                        if ($null -eq $sheet -and $SheetNameOrIndex -is [string]) { try { $sheet = $Workbook.Worksheets.Item(1); Write-AppLog "Sheet '$SheetNameOrIndex' not found, using first sheet." "WARN" } catch {}} # Fallback for string name

                        if ($null -eq $sheet) { throw "Cannot find sheet '$SheetNameOrIndex' in workbook '$($Workbook.Name)'" }

                        $sheetCache["$($Workbook.Name)_$SheetNameOrIndex"] = $sheet # Store in local cache

                        return $sheet

                    } # <<<<<<<< Corrected Brace placement for Get-Sheet function

 

                    # Pre-load sheets mentioned in mappings

                    $copyMappings | ForEach-Object { if($_.SourceSheet){ Get-Sheet $requestWorkbook $_.SourceSheet }; if($_.DestinationSheet){ Get-Sheet $CaaWorkbook $_.DestinationSheet } }

                    $staticEntries | ForEach-Object { if($_.DestinationSheet){ Get-Sheet $CaaWorkbook $_.DestinationSheet } }

 

                    Show-ExcelProgress -Status "Copying mapped data..." -PercentComplete 70 -ID 4

                    foreach ($mapping in $copyMappings) {

                        try {

                             $sourceSheet = Get-Sheet $requestWorkbook $mapping.SourceSheet

                             $destSheet = Get-Sheet $CaaWorkbook $mapping.DestinationSheet

                             # ... (rest of switch logic for L2L, Range, F2F)

                             switch ($mapping.Type) {

                                'LabelToLabel' {

                                     $offsetCol=if($mapping.PSObject.Properties.Name -contains 'OffsetColumn'){$mapping.OffsetColumn}else{1}

                                     $offsetRow=if($mapping.PSObject.Properties.Name -contains 'OffsetRow'){$mapping.OffsetRow}else{0}

                                     $sourceValueCell=Find-CellByLabel -Worksheet $sourceSheet -LabelText $mapping.Source -OffsetColumn $offsetCol -OffsetRow $offsetRow

                                     $destValueCell=Find-CellByLabel -Worksheet $destSheet -LabelText $mapping.Destination -OffsetColumn $offsetCol -OffsetRow $offsetRow

                                     if ($sourceValueCell -and $destValueCell) { $destValueCell.Value2 = $sourceValueCell.Value2; Write-AppLog "Copied L2L: '$($mapping.Source)' to '$($mapping.Destination)'" "DEBUG" }

                                     else { Write-AppLog "Skip L2L: Source:'$($mapping.Source)' or Dest:'$($mapping.Destination)' not found." "DEBUG" }

                                 }

                                'Range' {

                                     $sourceRange = $sourceSheet.Range($mapping.Source)

                                     $destRangeStart = $destSheet.Range($mapping.Destination)

                                     $destRangeStart.Resize($sourceRange.Rows.Count, $sourceRange.Columns.Count).Value2 = $sourceRange.Value2

                                     Write-AppLog "Copied Range: $($mapping.Source) to $($mapping.Destination)" "DEBUG"

                                 }

                                'FixedToFixed' { # Assuming this means direct cell-to-cell

                                     $sourceValue = Get-CellValueTyped -Worksheet $sourceSheet -Address $mapping.Source -Type String

                                     if ($sourceValue -ne $null) { $destSheet.Range($mapping.Destination).Value2 = $sourceValue; Write-AppLog "Copied F2F: $($mapping.Source) to $($mapping.Destination)" "DEBUG" }

                                     else { Write-AppLog "Skip F2F: Source '$($mapping.Source)' is empty." "DEBUG" }

                                 }

                                default { Write-AppLog "Unsupported copy type: $($mapping.Type)" "WARN" }

                             }

                        } catch { Write-AppLog "Excel Copy map error: $($mapping|Out-String) - Error: $($_.Exception.Message)" "WARN"; $copySuccess = $false }

                    }

 

                    Show-ExcelProgress -Status "Setting static entries..." -PercentComplete 80 -ID 4

                    foreach($entry in $staticEntries) {

                        try { $destSheet = Get-Sheet $CaaWorkbook $entry.DestinationSheet; $destSheet.Range($entry.Destination).Value2 = $entry.Value; Write-AppLog "Set Static: $($entry.Destination) to '$($entry.Value)'" "DEBUG" }

                        catch { Write-AppLog "Excel Static error at $($entry.Destination): $($_.Exception.Message)" "WARN"; $copySuccess = $false }

                    }

 

                    if ($copySuccess) { Show-ExcelProgress -Status "Saving CAA..." -PercentComplete 85 -ID 4; $CaaWorkbook.Save(); Write-AppLog "CAA Workbook saved successfully for '$($using:id2)'" "INFO" } # Use $using: here

                    else { Write-AppLog "Errors during Excel copy for '$($using:id2)'. CAA changes NOT saved automatically." "WARN" } # Use $using: here

                } catch { Handle-Error -ErrorRecord $_ -Context "Excel data copy Request->CAA for '$($using:id2)'" ; $copySuccess = $false } # Use $using: here

                finally { if ($requestWorkbook -ne $null) { try { $requestWorkbook.Close($false) } catch {} } }

                return $copySuccess

            } # End Invoke-ExcelOperation ScriptBlock

        } # End Process-ExcelWithTempCopy Call

 

        if (-not $copyResult) { Show-Warning "Excel data copying from Request to CAA encountered errors or was skipped." }

        else { Show-Success "Data copied from Request to CAA successfully." }

    } else {

        Write-AppLog "Skipping Excel data copy for '$id2' (CAA or Request file missing/copy failed)." "INFO"

        Show-Warning "Skipping data copy from Request to CAA as one or both files are missing."

    }

 

    # --- Create T2020 File ---

    Write-AppLog "Creating T2020 file for '$id2'" "INFO"

    $t2020FileName = "t2020 - $sanitizedFolderName.txt" # Consistent naming

    $t2020FilePath = Join-Path $casDocsFolder $t2020FileName # Place in CAS_DOCS

    # Build T2020 content string

    $t2020Content = @"

Project: $($extractedData.FullName)

Client ID: $($extractedData.ClientID)

Address: $fullAddress

Description: $($extractedData.Description)

 

Assigned: $(Format-DateSafeDisplay $assignedDateInternal)

Due: $(Format-DateSafeDisplay $dueDateInternal)

ID1: $id1

ID2: $id2

"@

    try {

        $t2020Content | Out-File -FilePath $t2020FilePath -Encoding UTF8 -Force -EA Stop

        Write-AppLog "Created T2020 file: $t2020FilePath" "INFO"

        $newProject.T2020 = $t2020FileName # Store relative name in project data

    } catch {

        Handle-Error -ErrorRecord $_ -Context "Creating T2020 file for '$id2'"

        $newProject.T2020 = "" # Ensure it's blank if creation failed

    }

 

    # --- Final Save ---

    Write-AppLog "Saving new project '$id2' to JSON data file." "INFO"

    $allProjects += $newProject # Add the newly created project object

    if (Save-ProjectTodoJson -ProjectData $allProjects) {

        Show-Success "Project '$($newProject.ID2)' created successfully!"

    } else {

        # Error handled by Save-ProjectTodoJson

        Show-Error "CRITICAL: Failed to save the new project '$($newProject.ID2)' to the JSON file. Project files/folders were created but the entry is not saved."

    }

    Pause-Screen

}


function Show-ProjectList {

    param ([switch]$IncludeCompleted)

 

    $title = if ($IncludeCompleted) { "PROJECTS LIST (ALL - Sorted by Assigned Date)" } else { "PROJECTS LIST (ACTIVE - Sorted by Assigned Date)" }

#    Clear-Host; Draw-Title $title

 

    $allProjects = Load-ProjectTodoJson

    if ($allProjects.Count -eq 0) { Show-Warning "No projects found in the data file."; Pause-Screen; return }

 

    $hoursMap = Get-ProjectHoursMapByID2 # Get hour totals

 

    $filteredProjects = $allProjects

    if (-not $IncludeCompleted) {

        $filteredProjects = $allProjects | Where-Object { [string]::IsNullOrEmpty($_.CompletedDate) }

    }

 

    if ($filteredProjects.Count -eq 0) { Show-Warning "No projects match the current filter (Active/All)."; Pause-Screen; return }

 

    # Sort projects by Assigned Date (handle potential errors)

    try {

        $sortedProjects = $filteredProjects | Sort-Object -Property @{ Expression = { try { [datetime]::ParseExact($_.AssignedDate, $global:DATE_FORMAT_INTERNAL, $null) } catch { [datetime]::MinValue } } } -ErrorAction Stop

    } catch {

        Handle-Error $_ "Sorting projects in Show-ProjectList"

        Show-Warning "Could not sort projects reliably, displaying in loaded order."

        $sortedProjects = $filteredProjects

    }

 

    # --- Prepare Data for Table ---

    $tableData = @()

    $rowColors = @{} # Hashtable for row/cell specific colors [rowIndex] = semanticKey or @{FG=...,BG=...} or @{_CELL_X=...}

    $theme = $global:currentTheme # Get current theme for default styles

    $rowIndex = 0

    $today = (Get-Date).Date

 

    foreach ($project in $sortedProjects) {

        $rowHighlightKey = "" # Semantic key for full row highlight (e.g., "Completed", "Overdue")

        $cellHighlights = @{} # Store cell specific highlights, e.g., $cellHighlights[3] = "DueSoon"

 

        # Determine row highlight based on status/due date

        if (-not [string]::IsNullOrEmpty($project.CompletedDate)) {

            $rowHighlightKey = "Completed"

        } else {

            # Check Overdue status for the whole row

            try {

                if ($project.DueDate -match '^\d{8}$') {

                    $dueDate = [datetime]::ParseExact($project.DueDate, $global:DATE_FORMAT_INTERNAL, $null)

                    if ($dueDate.Date -lt $today) {

                        $rowHighlightKey = "Overdue"

                    }

                }

            } catch { Write-AppLog "Invalid DueDate '$($project.DueDate)' in ProjectList for '$($project.ID2)'" "DEBUG" }

        }

 

        # Determine cell highlight for Due Date column if not already overdue/completed

        if ($rowHighlightKey -notin @("Completed", "Overdue")) {

             try {

                if ($project.DueDate -match '^\d{8}$') {

                    $dueDate = [datetime]::ParseExact($project.DueDate, $global:DATE_FORMAT_INTERNAL, $null)

                    if (($dueDate.Date - $today).Days -lt 7) { # Due within 7 days

                        $cellHighlights[3] = "DueSoon" # Highlight cell 3 (Due Date) with DueSoon style

                    }

                } else {

                     $cellHighlights[3] = "Warning" # Invalid date format gets warning style

                }

            } catch { $cellHighlights[3] = "Warning" } # Parsing error gets warning style

        }

 

 

        $calculatedHours = ($hoursMap.ContainsKey($project.ID2)) ? $hoursMap[$project.ID2] : 0.0

 

        # Get latest pending todo display text

        $newestPendingTaskDisplay = "---"

        if ($project.Todos -and $project.Todos.Count -gt 0) {

            $newestPending = $project.Todos | Where-Object { $_.Status -eq 'Pending' -and $_.CreatedDate -match '^\d{8}$'} | Sort-Object CreatedDate -Desc | Select-Object -First 1

            if ($newestPending) {

                $taskText = $newestPending.Task

                # Use column width from config for truncation length

                $latestTodoColWidth = ($global:tableConfig.Columns.Projects | Where-Object {$_.Title -eq 'Latest Todo'}).Width

                $maxLength = [Math]::Max(5, $latestTodoColWidth - 1) # Ensure positive length

                $newestPendingTaskDisplay = if ($taskText.Length -gt $maxLength) { $taskText.Substring(0, $maxLength - 1) + '…' } else { $taskText }

            }

        }

 

        # Format data for the row

        $assignedDisp = Format-DateSafeDisplay $project.AssignedDate

        $dueDisp = Format-DateSafeDisplay $project.DueDate

        $bfDisp = Format-DateSafeDisplay $project.BFDate

        $status = if($rowHighlightKey -eq "Completed"){"Done $(Format-DateSafeDisplay $project.CompletedDate)"}else{"Active"}

 

        # Add row data to the table array

        $tableData += ,@( $project.ID2, $project.FullName, $assignedDisp, $dueDisp, $bfDisp, $status, $calculatedHours.ToString("F1"), $newestPendingTaskDisplay )

 

        # Store row coloring information

        $rowColorInfo = @{}

        if($rowHighlightKey){ $rowColorInfo = $rowHighlightKey } # If whole row key exists, use it

        if ($cellHighlights.Count -gt 0) {

            # If cell highlights exist, merge them into the info

            if ($rowColorInfo -is [string]) { # Convert row key string to hashtable if needed

                 $tempKey = $rowColorInfo

                 $rowColorInfo = @{ "_ROW_KEY_" = $tempKey } # Store original key if needed

            }

            foreach($cellIdx in $cellHighlights.Keys) {

                 $rowColorInfo["_CELL_$cellIdx"] = $cellHighlights[$cellIdx] # Use _CELL_X syntax

            }

        }

        $rowColors[$rowIndex] = $rowColorInfo # Assign the final color info hash

 

        $rowIndex++

    }

 

    # Display the table using PSStyle formatter

    Format-TableUnicode -ViewType "Projects" -Data $tableData -RowColors $rowColors

 

    Write-Host "" # Spacer

 

    # Allow selecting a project to view details

    $selectedProject = Select-ItemFromList -Title "$title - VIEW DETAILS" -Items $sortedProjects -ViewType "ProjectSelection" -Prompt "Select project number to view details (0=Back)"

    if ($selectedProject) {

        # Call the PSStyle version of Show-ProjectDetail

        Show-ProjectDetail -Project $selectedProject

    }

    # No Pause-Screen here, flow returns to the caller (MainMenu or Dashboard)

}

 

function Set-Project {
    # <<< MODIFICATION: Added optional parameter >>>
    param ([PSCustomObject]$ProjectContext = $null)

    $allProjects = Load-ProjectTodoJson
    if ($allProjects.Count -eq 0) { Show-Warning "No projects exist to update."; Pause-Screen; return }

    $projectToUpdateOriginal = $null
    $projectToUpdate = $null
    $indexToUpdate = -1

    # <<< MODIFICATION: Use context if provided >>>
    if ($ProjectContext -ne $null) {
        # Find the project from context in the main list to ensure we modify the correct object reference
        for ($i = 0; $i -lt $allProjects.Count; $i++) {
            if ($allProjects[$i].ID2 -eq $ProjectContext.ID2) {
                $projectToUpdate = $allProjects[$i] # Get the object from the list
                $indexToUpdate = $i
                break
            }
        }
        if ($indexToUpdate -eq -1) {
            Write-AppLog "Consistency Error: Project context '$($ProjectContext.ID2)' provided to Set-Project not found in main list." "ERROR"
            Show-Error "Consistency Error: Provided project context not found. Please select manually."
            # Fall through to manual selection
        } else {
             Write-AppLog "Set-Project called with context: '$($ProjectContext.ID2)'" "INFO"
             $projectToUpdateOriginal = $projectToUpdate.PSObject.Copy() # Copy for comparison
        }
    }

    # <<< MODIFICATION: Select only if context wasn't provided or failed >>>
    if ($null -eq $projectToUpdate) {
        $activeProjects = @($allProjects | Where-Object { [string]::IsNullOrEmpty($_.CompletedDate) })
        if ($activeProjects.Count -eq 0) { Show-Warning "No active projects available to update."; Pause-Screen; return }

        try { $sortedActiveProjects = $activeProjects | Sort-Object -Property @{ Expression = { try { [datetime]::ParseExact($_.AssignedDate, $global:DATE_FORMAT_INTERNAL, $null) } catch { [datetime]::MinValue } } } -ErrorAction Stop }
        catch { Handle-Error $_ "Sorting active projects for update"; Show-Warning "Could not sort projects."; $sortedActiveProjects = $activeProjects }

        $projectToUpdateOriginal = Select-ItemFromList -Title "UPDATE PROJECT - SELECT ACTIVE PROJECT" -Items $sortedActiveProjects -ViewType "ProjectSelection" -Prompt "Select project to update (0=Cancel)"
        if (-not $projectToUpdateOriginal) { Write-AppLog "Project update cancelled at selection." "INFO"; Show-Warning "Update cancelled."; Pause-Screen; return }

        # Find the index in the *original* $allProjects list to update
        for ($i = 0; $i -lt $allProjects.Count; $i++) { if ($allProjects[$i].ID2 -eq $projectToUpdateOriginal.ID2) { $indexToUpdate = $i; break } }
        if ($indexToUpdate -eq -1) { Write-AppLog "Consistency Error finding selected project ID '$($projectToUpdateOriginal.ID2)' for update." "ERROR"; Show-Error "Consistency Error: Could not find selected project in the main list."; Pause-Screen; return }

        $projectToUpdate = $allProjects[$indexToUpdate] # Get the actual object to modify
        # Need to copy again here as $projectToUpdateOriginal was the selection item, not the live object's state
        $projectToUpdateOriginal = $projectToUpdate.PSObject.Copy()
    }
    # --- End Context/Selection Logic ---

    Clear-Host; Draw-Title "UPDATE PROJECT: $($projectToUpdate.ID2)"
    Show-Info "Editing project details. Press Enter to keep the current value."

    # --- Get Updated Values (rest of function remains the same) ---
    $projectToUpdate.FullName = Get-InputWithPrompt "Full name" $projectToUpdate.FullName
    $projectToUpdate.ID1 = Get-InputWithPrompt "ID1" $projectToUpdate.ID1

    # Dates (with validation)
    $assignedDateInput = Get-InputWithPrompt "Assigned date ($($global:AppConfig.displayDateFormat))" $projectToUpdate.AssignedDate -ForceDefaultFormat
    $newAssignedInternal = Parse-DateSafeInternal $assignedDateInput
    if (-not [string]::IsNullOrEmpty($newAssignedInternal)) { $projectToUpdate.AssignedDate = $newAssignedInternal }
    elseif (-not [string]::IsNullOrEmpty($assignedDateInput)) { Show-Warning "Invalid assigned date format. Keeping original." }

    $dueDateInput = Get-InputWithPrompt "Due date ($($global:AppConfig.displayDateFormat))" $projectToUpdate.DueDate -ForceDefaultFormat
    $newDueInternal = Parse-DateSafeInternal $dueDateInput
    if (-not [string]::IsNullOrEmpty($newDueInternal)) { $projectToUpdate.DueDate = $newDueInternal }
    elseif (-not [string]::IsNullOrEmpty($dueDateInput)) { Show-Warning "Invalid due date format. Keeping original." }

    $bfDateInput = Get-InputWithPrompt "BF date ($($global:AppConfig.displayDateFormat)) or '-' to clear" $projectToUpdate.BFDate -ForceDefaultFormat
    if($bfDateInput -eq '-') { $projectToUpdate.BFDate = "" }
    else {
        $newBfInternal = Parse-DateSafeInternal $bfDateInput
        if (-not [string]::IsNullOrEmpty($newBfInternal)) { $projectToUpdate.BFDate = $newBfInternal }
        elseif(-not [string]::IsNullOrEmpty($bfDateInput)) { Show-Warning "Invalid BF date format. Keeping original." }
    }

    # Project Folder
    $theme = $global:currentTheme # For styled prompt
    $labelStyle = Get-PSStyleValue $theme "Palette.SecondaryFG" "#808080" "Foreground"
    $valueStyle = Get-PSStyleValue $theme "Palette.DataFG" "#FFFFFF" "Foreground"
    Write-Host (Apply-PSStyle -Text "Current Folder: " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $projectToUpdate.ProjFolder -FG $valueStyle)
    if ((Confirm-ActionNumeric -ActionDescription "Update project folder path?") -eq $true) {
        $newProjFolder = Browse-DirectoriesNumeric -Title "Select New Project Folder" -StartPath ($projectToUpdate.ProjFolder -or "C:\")
        if ($newProjFolder) { $projectToUpdate.ProjFolder = $newProjFolder; Show-Info "Folder path updated." }
        else { Show-Warning "Folder path update cancelled or not selected." }
    }

    # Associated Files (only if project folder exists)
    $casDocsFolder = $null
    if (-not [string]::IsNullOrEmpty($projectToUpdate.ProjFolder) -and (Test-Path $projectToUpdate.ProjFolder -PathType Container)) {
         $casDocsFolder = Join-Path -Path $projectToUpdate.ProjFolder -ChildPath "__DOCS__\__CAS_DOCS__" # Standard path
         if (-not (Test-Path $casDocsFolder -PathType Container)) {
             Show-Warning "Standard subfolder '$casDocsFolder' not found. Cannot easily browse/verify relative files."
             $casDocsFolder = $null # Disable file browsing if structure isn't standard
         }
    } else {
         Show-Warning "Project folder path is invalid or not set. Cannot update relative file names."
    }

    if ($casDocsFolder) {
        # CAA File
        Write-Host (Apply-PSStyle -Text "Current CAA file: " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $projectToUpdate.CAAName -FG $valueStyle)
        if ((Confirm-ActionNumeric -ActionDescription "Update CAA file selection?") -eq $true) {
             $caaFile = Browse-FilesNumeric -Title "Select New CAA File" -StartPath $casDocsFolder -Filter "*.xls*"
             if ($caaFile) { $projectToUpdate.CAAName = Split-Path $caaFile -Leaf; Show-Info "CAA file name updated." } # Store relative name
             else { Show-Warning "CAA file selection cancelled or no file selected." }
        }
        # Request File
        Write-Host (Apply-PSStyle -Text "Current Request file: " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $projectToUpdate.RequestName -FG $valueStyle)
        if ((Confirm-ActionNumeric -ActionDescription "Update Request file selection?") -eq $true) {
             $reqFile = Browse-FilesNumeric -Title "Select New Request File" -StartPath $casDocsFolder # Assume any file type
             if ($reqFile) { $projectToUpdate.RequestName = Split-Path $reqFile -Leaf; Show-Info "Request file name updated." }
             else { Show-Warning "Request file selection cancelled or no file selected." }
        }
        # T2020 File
        Write-Host (Apply-PSStyle -Text "Current T2020 file: " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $projectToUpdate.T2020 -FG $valueStyle)
        if ((Confirm-ActionNumeric -ActionDescription "Update T2020 file selection?") -eq $true) {
             $t20File = Browse-FilesNumeric -Title "Select New T2020 File" -StartPath $casDocsFolder -Filter "*.txt"
             if ($t20File) { $projectToUpdate.T2020 = Split-Path $t20File -Leaf; Show-Info "T2020 file name updated." }
             else { Show-Warning "T2020 file selection cancelled or no file selected." }
        }
    }

    # --- Save Changes ---
    $changed = $false
    try {
        # Compare properties - Compare specific relevant properties
        $propsToCompare = 'FullName', 'ID1', 'AssignedDate', 'DueDate', 'BFDate', 'ProjFolder', 'CAAName', 'RequestName', 'T2020'
        $changed = Compare-Object -ReferenceObject $originalProjectData -DifferenceObject $projectToUpdate -Property $propsToCompare -IncludeEqual -PassThru | Where-Object {$_.SideIndicator -ne '=='} | Select-Object -First 1
    } catch {
        Write-AppLog "Error comparing project objects: $($_.Exception.Message)" "WARN"
        $changed = $true # Assume changed if comparison fails
    }


    if ($changed) {
         Write-AppLog "Attempting to save updated project '$($projectToUpdate.ID2)'" "INFO"
         # The object $projectToUpdate is already the reference from $allProjects[$indexToUpdate]
         # So we just need to save the $allProjects array
         if (Save-ProjectTodoJson -ProjectData $allProjects) { Show-Success "Project '$($projectToUpdate.ID2)' updated successfully." }
         else { Show-Error "Failed to save updated project '$($projectToUpdate.ID2)'." } # Save func handles error details
    } else {
         Show-Info "No changes detected for project '$($projectToUpdate.ID2)'."
    }
    Pause-Screen
}

function Set-ProjectComplete {
    # <<< MODIFICATION: Added optional parameter >>>
    param ([PSCustomObject]$ProjectContext = $null)

    $allProjects = Load-ProjectTodoJson
    if ($allProjects.Count -eq 0) { Show-Warning "No projects exist."; Pause-Screen; return }

    $projectToComplete = $null
    $indexToUpdate = -1

    # <<< MODIFICATION: Use context if provided >>>
    if ($ProjectContext -ne $null) {
        # Verify it's still active (can't complete an already completed project)
        if (-not [string]::IsNullOrEmpty($ProjectContext.CompletedDate)) {
            Show-Warning "Project '$($ProjectContext.ID2)' is already marked as complete."
            Pause-Screen
            return
        }
        # Find the project from context in the main list
        for ($i = 0; $i -lt $allProjects.Count; $i++) {
            if ($allProjects[$i].ID2 -eq $ProjectContext.ID2) {
                $projectToComplete = $allProjects[$i] # Get the live object
                $indexToUpdate = $i
                break
            }
        }
        if ($indexToUpdate -eq -1) {
            Write-AppLog "Consistency Error: Project context '$($ProjectContext.ID2)' provided to Set-ProjectComplete not found." "ERROR"
            Show-Error "Consistency Error: Provided project context not found. Please select manually."
             # Fall through to manual selection
             $projectToComplete = $null # Reset flag
        } else {
            Write-AppLog "Set-ProjectComplete called with context: '$($ProjectContext.ID2)'" "INFO"
        }
    }

    # <<< MODIFICATION: Select only if context wasn't provided or failed >>>
    if ($null -eq $projectToComplete) {
        $activeProjects = @($allProjects | Where-Object { [string]::IsNullOrEmpty($_.CompletedDate) })
        if ($activeProjects.Count -eq 0) { Show-Warning "No active projects to mark as complete."; Pause-Screen; return }

        try { $sortedActiveProjects = $activeProjects | Sort-Object -Property @{ Expression = { try { [datetime]::ParseExact($_.AssignedDate, $global:DATE_FORMAT_INTERNAL, $null) } catch { [datetime]::MinValue } } } -ErrorAction Stop }
        catch { Handle-Error $_ "Sorting active projects for completion"; Show-Warning "Could not sort projects."; $sortedActiveProjects = $activeProjects }

        $selection = Select-ItemFromList -Title "COMPLETE PROJECT - SELECT ACTIVE PROJECT" -Items $sortedActiveProjects -ViewType "ProjectSelection" -Prompt "Select project to mark complete (0=Cancel)"
        if (-not $selection) { Write-AppLog "Project completion cancelled at selection." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

        # Find the index in the *original* $allProjects list
        for ($i = 0; $i -lt $allProjects.Count; $i++) { if ($allProjects[$i].ID2 -eq $selection.ID2) { $indexToUpdate = $i; break } }
        if ($indexToUpdate -eq -1) { Write-AppLog "Consistency Error finding project ID '$($selection.ID2)' for completion." "ERROR"; Show-Error "Consistency Error: Could not find selected project in the main list."; Pause-Screen; return }
        $projectToComplete = $allProjects[$indexToUpdate] # Get the live object
    }
    # --- End Context/Selection Logic ---

    Clear-Host; Draw-Title "COMPLETE PROJECT: $($projectToComplete.ID2)"
    $confirm = Confirm-ActionNumeric -ActionDescription "Mark project '$($projectToComplete.FullName)' as complete?"
    if ($confirm -ne $true) { Write-AppLog "Project completion cancelled by user for '$($projectToComplete.ID2)'." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

    $completionDateInternal = (Get-Date).ToString($global:DATE_FORMAT_INTERNAL)
    $allProjects[$indexToUpdate].CompletedDate = $completionDateInternal
    $allProjects[$indexToUpdate].Status = "Completed" # Update status field as well

    Write-AppLog "Attempting to mark project '$($projectToComplete.ID2)' as complete in data file." "INFO"
    if (Save-ProjectTodoJson -ProjectData $allProjects) {
        Show-Success "Project '$($projectToComplete.ID2)' marked as complete."
    } else {
        Show-Error "Failed to save completion status for project '$($projectToComplete.ID2)'." # Save func handles details
        # Attempt to revert in memory if save failed? Or rely on next load? For now, just report failure.
    }
    Pause-Screen
}

function Remove-Project {
    # <<< MODIFICATION: Added optional parameter >>>
    param ([PSCustomObject]$ProjectContext = $null)

    $allProjects = Load-ProjectTodoJson
    if ($allProjects.Count -eq 0) { Show-Warning "No projects exist to remove."; Pause-Screen; return }

    $projectToRemove = $null

    # <<< MODIFICATION: Use context if provided >>>
    if ($ProjectContext -ne $null) {
        # Find the project from context in the main list to ensure we reference it correctly
        $foundInList = $allProjects | Where-Object { $_.ID2 -eq $ProjectContext.ID2 } | Select-Object -First 1
        if ($null -eq $foundInList) {
             Write-AppLog "Consistency Error: Project context '$($ProjectContext.ID2)' provided to Remove-Project not found." "ERROR"
             Show-Error "Consistency Error: Provided project context not found. Please select manually."
              # Fall through to manual selection
        } else {
            Write-AppLog "Remove-Project called with context: '$($ProjectContext.ID2)'" "INFO"
            $projectToRemove = $foundInList # Use the object found in the list
        }
    }

    # <<< MODIFICATION: Select only if context wasn't provided or failed >>>
    if ($null -eq $projectToRemove) {
        try { $sortedAllProjects = $allProjects | Sort-Object -Property @{ Expression = { try { [datetime]::ParseExact($_.AssignedDate, $global:DATE_FORMAT_INTERNAL, $null) } catch { [datetime]::MinValue } } } -ErrorAction Stop }
        catch { Handle-Error $_ "Sorting projects for removal"; Show-Warning "Could not sort projects."; $sortedAllProjects = $allProjects }

        $projectToRemove = Select-ItemFromList -Title "REMOVE PROJECT - SELECT PROJECT" -Items $sortedAllProjects -ViewType "ProjectSelection" -Prompt "Select project to REMOVE (0=Cancel)"
        if (-not $projectToRemove) { Write-AppLog "Project removal cancelled at selection." "INFO"; Show-Warning "Removal cancelled."; Pause-Screen; return }
    }
    # --- End Context/Selection Logic ---


    Clear-Host; Draw-Title "REMOVE PROJECT: $($projectToRemove.ID2)"
    $theme = $global:currentTheme
    $labelStyle = Get-PSStyleValue $theme "Palette.SecondaryFG" "#808080" "Foreground"
    $valueStyle = Get-PSStyleValue $theme "Palette.DataFG" "#FFFFFF" "Foreground"
    $status = if ([string]::IsNullOrEmpty($projectToRemove.CompletedDate)) { "ACTIVE" } else { "Completed $(Format-DateSafeDisplay $projectToRemove.CompletedDate)" }
    Write-Host (Apply-PSStyle -Text " Project: " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $projectToRemove.FullName -FG $valueStyle)
    Write-Host (Apply-PSStyle -Text " Status:  " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $status -FG $valueStyle)
    Write-Host ""
    Show-Warning "This action PERMANENTLY removes the project entry and its associated Todos from the JSON data file."
    Show-Warning "It does NOT delete the project folder on disk or remove time tracking entries automatically."

    $confirm1 = Confirm-ActionNumeric -ActionDescription "Confirm REMOVAL of project entry '$($projectToRemove.ID2)'?"
    if ($confirm1 -ne $true) { Write-AppLog "Project removal cancelled by user for '$($projectToRemove.ID2)'." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

    # Extra confirmation for ACTIVE projects
    if ([string]::IsNullOrEmpty($projectToRemove.CompletedDate)) {
        $doubleConfirm = Get-InputWithPrompt "This is an ACTIVE project. Type 'CONFIRM' (all caps) to proceed with removal"
        if ($doubleConfirm -ne "CONFIRM") { Write-AppLog "Project removal confirmation failed for active project '$($projectToRemove.ID2)'." "INFO"; Show-Warning "Confirmation failed. Removal cancelled."; Pause-Screen; return }
    }

    # Filter out the project to remove
    $updatedProjects = @($allProjects | Where-Object { $_.ID2 -ne $projectToRemove.ID2 })

    Write-AppLog "Attempting to remove project '$($projectToRemove.ID2)' from JSON data." "INFO"
    if (Save-ProjectTodoJson -ProjectData $updatedProjects) {
        Show-Success "Project '$($projectToRemove.ID2)' removed successfully from JSON data."

        # Optional: Ask to remove associated time entries
        $confirmTime = Confirm-ActionNumeric -ActionDescription "Also attempt to remove time tracking entries for ID2 '$($projectToRemove.ID2)' from CSV?"
        if ($confirmTime -eq $true) {
            Write-AppLog "Attempting to remove time entries for removed project '$($projectToRemove.ID2)'." "INFO"
            $timeEntries = Get-CsvDataSafely -FilePath $Global:AppConfig.timeTrackingFile
            if ($timeEntries.Count -gt 0) {
                $originalTimeCount = $timeEntries.Count
                $updatedTimeEntries = @($timeEntries | Where-Object { $_.ID2 -ne $projectToRemove.ID2 })
                $removedCount = $originalTimeCount - $updatedTimeEntries.Count
                if ($removedCount -gt 0) {
                    if (Set-CsvData -FilePath $Global:AppConfig.timeTrackingFile -Data $updatedTimeEntries) { Show-Success "Removed $removedCount time tracking entries." }
                    else { Show-Error "Failed to save updated time tracking data after removal." }
                } else {
                    Show-Info "No time tracking entries found for ID2 '$($projectToRemove.ID2)'."
                }
            } else {
                 Show-Info "Time tracking file is empty. No entries to remove."
            }
        }
    } else {
        Show-Error "Failed to save project list after removal. Project '$($projectToRemove.ID2)' might still be in the JSON file." # Save func handles details
    }
    Pause-Screen
}
 

function Open-ProjectFiles {

    param ([PSCustomObject]$SelectedProject = $null)

 

    $allProjects = $null # Only load if needed

 

    # If no project passed in, let user select one

    if ($null -eq $SelectedProject) {

        $allProjects = Load-ProjectTodoJson

        if ($allProjects.Count -eq 0) { Show-Warning "No projects exist."; Pause-Screen; return }

 

        try { $sortedAllProjects = $allProjects | Sort-Object -Property @{ Expression = { try { [datetime]::ParseExact($_.AssignedDate, $global:DATE_FORMAT_INTERNAL, $null) } catch { [datetime]::MinValue } } } -ErrorAction Stop }

        catch { Handle-Error $_ "Sorting projects for Open Files"; Show-Warning "Could not sort projects."; $sortedAllProjects = $allProjects }

 

        $SelectedProject = Select-ItemFromList -Title "OPEN FILES - SELECT PROJECT" -Items $sortedAllProjects -ViewType "ProjectSelection" -Prompt "Select project (0=Cancel)"

        if (-not $SelectedProject) { Write-AppLog "Open Project Files cancelled at selection." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

    }

 

    # Validate Project Folder Path

    if ([string]::IsNullOrEmpty($SelectedProject.ProjFolder)) { Write-AppLog "Cannot open files for '$($SelectedProject.ID2)' - no project folder path specified." "WARN"; Show-Error "No project folder path is specified for project '$($SelectedProject.ID2)'. Update project details."; Pause-Screen; return }

    if (-not (Test-Path $SelectedProject.ProjFolder -PathType Container)) {

        Write-AppLog "Project folder not found for '$($SelectedProject.ID2)': $($SelectedProject.ProjFolder)" "ERROR"

        Show-Error "Project folder not found at the specified path: $($SelectedProject.ProjFolder)"

        $confirmUpdate = Confirm-ActionNumeric -ActionDescription "Attempt to update the folder path now?"

        if ($confirmUpdate -eq $true) {

            # Call Set-Project to allow updating the path (will require re-selecting project)

            Show-Info "Redirecting to Update Project Details..."

            Pause-Screen

            Set-Project # User will need to re-select the project after updating path

            return # Exit Open-ProjectFiles as Set-Project handles flow

        } else { Pause-Screen; return } # Cancelled update

    }

 

    # Assume standard subfolder structure for relative files

    $casDocsFolder = Join-Path $SelectedProject.ProjFolder "__DOCS__\__CAS_DOCS__"

 

    Clear-Host; Draw-Title "OPEN FILES FOR: $($SelectedProject.ID2)"

    $theme = $global:currentTheme

    $options = @{} # Maps display number to action scriptblock

    $displayIndex = 1

 

    # Helper Function for adding file options

    function Add-FileOption {

        param(

            [ref]$IndexRef, # Pass index by reference to increment it

            [ref]$OptionsRef, # Pass options hashtable by reference

            [string]$FilePropName, # Name of the property in $SelectedProject holding the filename

            [string]$LabelPrefix, # Text label (e.g., "CAA", "Request")

            [PSCustomObject]$Project,

            [string]$BaseDocsPath, # Path to the folder containing the file (e.g., $casDocsFolder)

            [hashtable]$Theme # Pass the current theme for styling

        )

        $optionFG = Get-PSStyleValue $Theme "Menu.Option.FG" "#FFFFFF" "Foreground"

        $warnFG = Get-PSStyleValue $Theme "Palette.WarningFG" "#FFFF00" "Foreground"

        $disabledFG = Get-PSStyleValue $Theme "Palette.DisabledFG" "#808080" "Foreground"

 

        $fileName = $Project.$FilePropName

        $optIndex = $IndexRef.Value

 

        if (-not [string]::IsNullOrEmpty($fileName)) {

            $filePath = Join-Path $BaseDocsPath $fileName

            if (Test-Path $filePath -PathType Leaf) {

                $OptionsRef.Value[$optIndex] = @{ Label = "Open $LabelPrefix ($fileName)"; Action = { Start-Process $filePath } }

                Write-Host (Apply-PSStyle -Text "$optIndex. $($OptionsRef.Value[$optIndex].Label)" -FG $optionFG)

            } else {

                Write-AppLog "$LabelPrefix file not found for project '$($Project.ID2)': $filePath" "WARN"

                Write-Host (Apply-PSStyle -Text " $optIndex. $LabelPrefix file not found ($fileName)" -FG $warnFG)

            }

        } else {

            Write-Host (Apply-PSStyle -Text " $optIndex. ($LabelPrefix file not set in project data)" -FG $disabledFG)

        }

        $IndexRef.Value++ # Increment the display index

    }

 

    # Option 1: Open Project Folder

    $options[$displayIndex] = @{ Label = "Open Project Folder in Explorer"; Action = { Start-Process explorer.exe -ArgumentList $SelectedProject.ProjFolder } }

    $optionFG = Get-PSStyleValue $theme "Menu.Option.FG" "#FFFFFF" "Foreground" # Get style

    Write-Host (Apply-PSStyle -Text "$displayIndex. $($options[$displayIndex].Label)" -FG $optionFG)

    $displayIndex++

 

    # Options for specific files (CAA, Request, T2020) - only if standard subfolder exists

    if (Test-Path $casDocsFolder -PathType Container) {

        Add-FileOption -IndexRef ([ref]$displayIndex) -OptionsRef ([ref]$options) -FilePropName 'CAAName' -LabelPrefix 'CAA' -Project $SelectedProject -BaseDocsPath $casDocsFolder -Theme $theme

        Add-FileOption -IndexRef ([ref]$displayIndex) -OptionsRef ([ref]$options) -FilePropName 'RequestName' -LabelPrefix 'Request' -Project $SelectedProject -BaseDocsPath $casDocsFolder -Theme $theme

        Add-FileOption -IndexRef ([ref]$displayIndex) -OptionsRef ([ref]$options) -FilePropName 'T2020' -LabelPrefix 'T2020' -Project $SelectedProject -BaseDocsPath $casDocsFolder -Theme $theme

    } else {

        Write-AppLog "CAS Docs folder not found for '$($SelectedProject.ID2)': $casDocsFolder. Skipping file options." "WARN"

        Show-Warning "Standard subfolder '__DOCS__\__CAS_DOCS__' not found. Cannot list specific files."

    }

 

    # Cancel Option

    Write-Host ""

    $warnFG = Get-PSStyleValue $theme "Palette.WarningFG" "#FFFF00" "Foreground" # Get style

    Write-Host (Apply-PSStyle -Text " 0. Cancel" -FG $warnFG)

 

    # Get User Choice

    $choice = Get-NumericChoice -Prompt "Select action" -MinValue 0 -MaxValue ($displayIndex - 1) -CancelOption "0"

 

    if ($choice -eq $null -or $choice -eq 0) { return } # Cancelled

 

    if ($options.ContainsKey($choice)) {

        try {

            Write-AppLog "Executing file open action: $($options[$choice].Label)" "INFO"

            Invoke-Command -ScriptBlock $options[$choice].Action -ErrorAction Stop

            Show-Info "Attempted to open: $($options[$choice].Label)" # Feedback

        } catch {

            Handle-Error -ErrorRecord $_ -Context "Executing file open action '$($options[$choice].Label)'"

        }

    } else {

        Show-Error "Invalid choice selected."

    }

    Pause-Screen # Pause after attempting to open

}

#endregion

#region Time Tracking Functions (Uses PSStyle UI Helpers)

function Get-TimeSheet {
    Clear-Host; Draw-Title "TIME SHEET SUMMARY"

    # Get date range from user
    $defaultStartDateInternal = (Get-Date).Date # Start with DateTime object containing only date part
    while ($defaultStartDateInternal.DayOfWeek -ne [System.DayOfWeek]::Monday) { $defaultStartDateInternal = $defaultStartDateInternal.AddDays(-1) }
    # Convert the final calculated date to the internal string format for the default value
    $defaultStartDateStringInternal = $defaultStartDateInternal.ToString($global:DATE_FORMAT_INTERNAL)

    $startDateInput = Get-InputWithPrompt "Enter start date ($($global:AppConfig.displayDateFormat)) for week" $defaultStartDateStringInternal -ForceDefaultFormat
    $startDateInternal = Parse-DateSafeInternal $startDateInput

    # Check for valid date input before proceeding
    if ([string]::IsNullOrEmpty($startDateInternal)) {
        Show-Error "Invalid start date format entered or cancelled."
        Pause-Screen
        return
    }

    try {
        # Parse the internal string format back to a DateTime object
        $startDate = [datetime]::ParseExact($startDateInternal, $global:DATE_FORMAT_INTERNAL, $null)
    } catch {
        Handle-Error $_ "Parsing start date for timesheet"
        Pause-Screen
        return
    }

    # Ensure start date is a Monday for week view clarity (using the DateTime object)
    while ($startDate.DayOfWeek -ne [System.DayOfWeek]::Monday) { $startDate = $startDate.AddDays(-1) }
    $endDate = $startDate.AddDays(6) # Monday to Sunday

    # Use the .Date property and the configured displayDateFormat for the info message
    Show-Info "Displaying time entries for week starting: $($startDate.Date.ToString($global:AppConfig.displayDateFormat)) (Mon-Sun)"

    $allTimeEntries = Get-CsvDataSafely -FilePath $Global:AppConfig.timeTrackingFile
    # Check if any entries were loaded AFTER attempting to load
    if ($null -eq $allTimeEntries -or $allTimeEntries.Count -eq 0) {
        Show-Warning "No time entries found in the CSV file or file could not be read."
        Pause-Screen
        return
    }

    # Filter entries and create new objects for the specified week
    $processedEntriesForWeek = @()
    foreach ($entry in $allTimeEntries) {
        $entryDate = $null
        $hoursValue = 0.0

        # Validate Date format (YYYYMMDD) - Ensure entry has 'Date' property
        if (-not $entry.PSObject.Properties.Name.Contains('Date') -or $entry.Date -notmatch '^\d{8}$') {
            $id2ForLog = if ($entry.PSObject.Properties.Name.Contains('ID2')) {$entry.ID2} else {'(Unknown ID2)'}
            $dateForLog = if ($entry.PSObject.Properties.Name.Contains('Date')) {$entry.Date} else {'(Missing Date)'}
            Write-AppLog "Skipping time entry ID2 '$id2ForLog': Invalid or missing date format '$dateForLog' (Need YYYYMMDD)." "WARN"
            continue
        }

        # Validate Hours format (numeric) - Ensure entry has 'Hours' property
        if (-not $entry.PSObject.Properties.Name.Contains('Hours') -or -not ([double]::TryParse($entry.Hours, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$hoursValue))) {
             $id2ForLog = if ($entry.PSObject.Properties.Name.Contains('ID2')) {$entry.ID2} else {'(Unknown ID2)'}
             $hoursForLog = if ($entry.PSObject.Properties.Name.Contains('Hours')) {$entry.Hours} else {'(Missing Hours)'}
             Write-AppLog "Skipping time entry ID2 '$id2ForLog' Date '$($entry.Date)': Invalid or missing hours value '$hoursForLog'." "WARN"
             continue
        }

        # Try parsing the validated date string
        try {
            $entryDate = [datetime]::ParseExact($entry.Date, $global:DATE_FORMAT_INTERNAL, $null).Date # Ensure we store only the Date part
        } catch {
             Write-AppLog "Skipping time entry ID2 '$($entry.ID2)' Date '$($entry.Date)': Date parsing error '$($_.Exception.Message)'." "WARN"
             continue # Skip if date cannot be parsed even after format check
        }

        # Check if the parsed date falls within the selected week (using .Date explicitly)
        if ($entryDate.Date -ge $startDate.Date -and $entryDate.Date -le $endDate.Date) {
            # Ensure Description property exists, default to empty string if not
            $descriptionForEntry = if ($entry.PSObject.Properties.Name.Contains('Description')) {$entry.Description} else {""}

            # Create a new object for processing
            $processedEntriesForWeek += [PSCustomObject]@{
                ParsedDate  = $entryDate # Store the DateTime object (Date part only)
                DisplayDate = Format-DateSafeDisplay $entry.Date # Store display format too
                ID2         = $entry.ID2
                HoursValue  = $hoursValue
                Description = $descriptionForEntry
            }
        }
    } # End foreach loop

    # Check if entries were found specifically for THIS week
    if ($processedEntriesForWeek.Count -eq 0) {
        Show-Warning "No time entries found for this specific week."
        Pause-Screen
        return
    }

    # Prepare data for the table, grouped by day (using the ParsedDate DateTime object)
    try {
        $groupedEntries = $processedEntriesForWeek | Sort-Object ParsedDate | Group-Object -Property ParsedDate -ErrorAction Stop
    } catch {
        Handle-Error $_ "Grouping timesheet entries"
        Pause-Screen
        return
    }

    $tableData = @()
    $weeklyTotal = 0.0
    foreach ($dayGroup in $groupedEntries) {
        # Use the pre-formatted DisplayDate from one of the group's items for table display
        $dayDateStr = $dayGroup.Group[0].DisplayDate
        $dailyTotal = 0.0
        $isFirstEntryOfDay = $true
        foreach ($entry in $dayGroup.Group) { # Iterate through the already processed objects
            $idDisplay = if ($entry.ID2 -eq "CUSTOM") { "CUSTOM/Non-Proj" } else { $entry.ID2 }
            # Add row to table data
        $displayDate = if ($isFirstEntryOfDay) { $dayDateStr } else { "" }
           
            $tableData += ,@(
                $displayDate,
                $idDisplay,
                $entry.HoursValue.ToString("F1"),
                $entry.Description
            )
           
            $dailyTotal += $entry.HoursValue
            $isFirstEntryOfDay = $false
        }
        $weeklyTotal += $dailyTotal
    }

    # Add total row
    if ($tableData.Count > 0) { # Only add total if there was data
        $tableData += ,@("", "WEEKLY TOTAL:", $weeklyTotal.ToString("F1"), "")
        # Highlight the total row using semantic key
        $rowColors = @{ ($tableData.Count - 1) = "Selected" }
    } else {
        $rowColors = @{} # No data, no colors needed
    }


    # Display using PSStyle table formatter
    Format-TableUnicode -ViewType "TimeSheet" -Data $tableData -RowColors $rowColors
    Pause-Screen
}

#endregion

# ... (Keep Add-TimeEntryCore, Add-ProjectTimeInteractive, etc.) ...

#endregion

# --- MODIFIED Add-TimeEntryCore: Handle description based on ID2 ---
function Add-TimeEntryCore {
    param (
        [string]$ID2, # For projects, this is ID2. For non-project, this is the Description.
        [double]$Hours,
        [string]$DateInternal, # Expects YYYYMMDD
        [string]$Description = "" # For projects, optional. For non-project, this is redundant (in ID2).
    )
    if ($Hours -lt 0) { Show-Error "Hours worked cannot be negative."; return $false }
    if (-not ($DateInternal -match '^\d{8}$')) { Show-Error "Invalid internal date format '$DateInternal'. Expected YYYYMMDD."; return $false }
    try { [void][datetime]::ParseExact($DateInternal, $global:DATE_FORMAT_INTERNAL, $null) } catch { Handle-Error $_ "Parsing internal date '$DateInternal' for time entry"; return $false }

    $timeEntries = Get-CsvDataSafely -FilePath $Global:AppConfig.timeTrackingFile

    # Determine description based on whether ID2 looks like a custom task (now contains the description)
    # This logic assumes project ID2s don't typically contain spaces or look like sentences.
    $isCustomTask = $ID2 -match '\s' -or $ID2.Length -gt 20 # Heuristic: if ID2 has spaces or is long, treat as custom
    $entryDescription = if ($isCustomTask) { "" } else { $Description } # Keep original description for actual projects only

    Write-AppLog "Adding time entry: $Hours hrs for '$ID2' on $DateInternal" "INFO"
    $newEntry = [PSCustomObject]@{ Date = $DateInternal; ID2 = $ID2; Hours = $Hours.ToString("0.0"); Description = $entryDescription }
    $timeEntries = @($timeEntries) + $newEntry
    try { $timeEntries = @($timeEntries | Sort-Object Date, ID2 -ErrorAction Stop) } catch { Handle-Error $_ "Sorting time entries before save" } # Log error but proceed

    if (-not (Set-CsvData -FilePath $Global:AppConfig.timeTrackingFile -Data $timeEntries)) {
        # Error handled by Set-CsvData
        Show-Error "Failed to save time tracking data."
        return $false
    }

    Show-Success "Time entry ($($Hours.ToString('F1')) hours) added for '$ID2' on $(Format-DateSafeDisplay $DateInternal)."
    return $true
}

# --- MODIFIED Add-NonProjectTimeInteractive: Pass Description as ID2 ---
function Add-NonProjectTimeInteractive {
    Clear-Host; Draw-Title "TRACK NON-PROJECT TIME"

    # Get Description (Required) - This IS the "ID2" for non-project time
    $description = Get-InputWithPrompt "Task description (e.g., Admin, Meeting - Required)"
    if ([string]::IsNullOrWhiteSpace($description)) { Show-Error "Description is required for non-project time."; Pause-Screen; return }

    # Get Hours
    $hoursInput = Get-InputWithPrompt "Hours worked (e.g., 1.0, 2.25)"; $hours = 0.0
    if (-not ([double]::TryParse($hoursInput, [ref]$hours)) -or $hours -lt 0) { Show-Error "Invalid hours entered."; Pause-Screen; return }

    # Get Date
    $defaultDateInternal = (Get-Date).ToString($global:DATE_FORMAT_INTERNAL)
    $dateInput = Get-InputWithPrompt "Date ($($global:AppConfig.displayDateFormat))" $defaultDateInternal -ForceDefaultFormat
    $dateInternal = Parse-DateSafeInternal $dateInput
    if ([string]::IsNullOrEmpty($dateInternal)) { Show-Error "Invalid date entered."; Pause-Screen; return }

    # Call core function, passing the task description into the ID2 field
    # Pass empty string for the original 'Description' param as it's now redundant for non-project
    Add-TimeEntryCore -ID2 $description -Hours $hours -DateInternal $dateInternal -Description ""
    Pause-Screen
}

 

function Add-ProjectTimeInteractive {
    # <<< MODIFICATION: Added optional parameter >>>
    param ([PSCustomObject]$ProjectContext = $null)

    $projectID2 = $null
    $projectName = ""

    # <<< MODIFICATION: Use context if provided >>>
    if ($ProjectContext -ne $null) {
        $projectID2 = $ProjectContext.ID2
        $projectName = $ProjectContext.FullName
        Write-AppLog "Add-ProjectTimeInteractive called with context: '$projectID2'" "INFO"
    } else {
        # If no context, prompt for selection
        $allProjects = Load-ProjectTodoJson
        if ($allProjects.Count -eq 0) { Show-Warning "No projects exist to log time against."; Pause-Screen; return }

        $activeProjects = @($allProjects | Where-Object { [string]::IsNullOrEmpty($_.CompletedDate) })
        if ($activeProjects.Count -eq 0) { Show-Warning "No active projects available to log time against."; Pause-Screen; return }

        try { $sortedActiveProjects = $activeProjects | Sort-Object -Property @{ Expression = { try { [datetime]::ParseExact($_.AssignedDate, $global:DATE_FORMAT_INTERNAL, $null) } catch { [datetime]::MinValue } } } -ErrorAction Stop }
        catch { Handle-Error $_ "Sorting projects for time log"; Show-Warning "Could not sort projects."; $sortedActiveProjects = $activeProjects }

        $selectedProject = Select-ItemFromList -Title "LOG PROJECT TIME - SELECT PROJECT" -Items $sortedActiveProjects -ViewType "ProjectSelection" -Prompt "Select project (0=Cancel)"
        if (-not $selectedProject) { Write-AppLog "Log project time cancelled at selection." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

        $projectID2 = $selectedProject.ID2
        $projectName = $selectedProject.FullName
    }
    # --- End Context/Selection Logic ---

#    Clear-Host; Draw-Title "LOG TIME FOR PROJECT: $projectID2 ($projectName)"

    # Get Date
    $defaultDateInternal = (Get-Date).ToString($global:DATE_FORMAT_INTERNAL)
    $dateInput = Get-InputWithPrompt "Date ($($global:AppConfig.displayDateFormat))" $defaultDateInternal -ForceDefaultFormat
    $dateInternal = Parse-DateSafeInternal $dateInput
    # <<< MODIFICATION: Check for cancel/invalid date *before* asking for hours >>>
    if ([string]::IsNullOrEmpty($dateInternal)) {
        if (-not [string]::IsNullOrEmpty($dateInput)){ Show-Error "Invalid date entered." } # Only show error if they typed something invalid
        else { Show-Warning "Date entry cancelled or skipped." } # If they just pressed Enter on an empty prompt
        Pause-Screen; return
    }
    # --- End Date Check ---

    # Get Hours
    $hoursInput = Get-InputWithPrompt "Hours worked (e.g., 7.5, 0.5)"
    $hours = 0.0
    if (-not ([double]::TryParse($hoursInput, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$hours)) -or $hours -lt 0) {
        Show-Error "Invalid hours entered. Please enter a positive number."; Pause-Screen; return
    }

    # Get Description
    $description = Get-InputWithPrompt "Description (optional)"

    # Add the entry using the core function
    Add-TimeEntryCore -ID2 $projectID2 -Hours $hours -DateInternal $dateInternal -Description $description
    Pause-Screen
}

#endregion

 

function Add-NonProjectTimeInteractive {

    Clear-Host; Draw-Title "TRACK NON-PROJECT TIME"

 

    # Get Description (Required for non-project time)

    $description = Get-InputWithPrompt "Task description (e.g., Admin, Meeting - Required)"

    if ([string]::IsNullOrWhiteSpace($description)) { Show-Error "Description is required for non-project time."; Pause-Screen; return }

 

    # Get Hours

    $hoursInput = Get-InputWithPrompt "Hours worked (e.g., 1.0, 2.25)"

    $hours = 0.0

    if (-not ([double]::TryParse($hoursInput, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$hours)) -or $hours -lt 0) {

        Show-Error "Invalid hours entered. Please enter a positive number."; Pause-Screen; return

    }

 

    # Get Date

    $defaultDateInternal = (Get-Date).ToString($global:DATE_FORMAT_INTERNAL)

    $dateInput = Get-InputWithPrompt "Date ($($global:AppConfig.displayDateFormat))" $defaultDateInternal -ForceDefaultFormat

    $dateInternal = Parse-DateSafeInternal $dateInput

    if ([string]::IsNullOrEmpty($dateInternal)) { Show-Error "Invalid date entered."; Pause-Screen; return }

 

    # Add the entry using the core function with "CUSTOM" ID2

    Add-TimeEntryCore -ID2 "CUSTOM" -Hours $hours -DateInternal $dateInternal -Description $description

    Pause-Screen

}

 

function Remove-TimeEntry {

    # Implementation potentially complex: Need to list entries, select, confirm, rewrite CSV.

    Show-Warning "Remove time entry function is not fully implemented."

    Show-Info "To remove entries, please manually edit the CSV file:"

    Show-Info $Global:AppConfig.timeTrackingFile

    Pause-Screen

}

#endregion

 

#region Todo Helper Functions (Uses PSStyle UI Helpers)

function Add-TodoItemToProject {

    param([Parameter(Mandatory=$true)][PSCustomObject]$ProjectObject)

 

    Clear-Host; Draw-Title "ADD TODO TO PROJECT: $($ProjectObject.ID2)"

 

    # Get Task Description

    $Task = Get-InputWithPrompt "Task description (Required)"

    if ([string]::IsNullOrWhiteSpace($Task)) { Write-AppLog "Add Todo cancelled - task description required." "INFO"; Show-Warning "Task description cannot be empty."; return $null } # Return null indicates cancellation/failure

 

    # Get Due Date (Optional)

    $dueDateInternal = ""

    $dueDateInput = Get-InputWithPrompt "Due date ($($global:AppConfig.displayDateFormat)) or Enter for none"

    if (-not [string]::IsNullOrEmpty($dueDateInput)) {

        $dueDateInternal = Parse-DateSafeInternal $dueDateInput

        if ([string]::IsNullOrEmpty($dueDateInternal)) {

            Write-AppLog "Invalid due date entered for new Todo: $dueDateInput" "WARN"

            Show-Warning "Invalid due date format entered. No due date will be set."

        }

    }

 

    # Get Priority

    $priorityChoice = Get-NumericChoice -Prompt "Priority (1=High, 2=Normal, 3=Low)" -MinValue 1 -MaxValue 3 -CancelOption "0"

    if ($priorityChoice -eq $null) { Write-AppLog "Add Todo cancelled at priority selection." "INFO"; Show-Warning "Cancelled."; return $null }

    $priorityText = switch ($priorityChoice) { 1 {"High"} 2 {"Normal"} 3 {"Low"} default {"Normal"} }

 

    # Create new Todo Object

    $newTodo = [PSCustomObject]@{

        TodoID        = [guid]::NewGuid().ToString() # Unique ID for the todo item

        Task          = $Task

        DueDate       = $dueDateInternal

        Priority      = $priorityText

        Status        = "Pending"

        CreatedDate   = (Get-Date).ToString($global:DATE_FORMAT_INTERNAL)

        CompletedDate = ""

    }

 

    # Add to Project Object (in memory)

    try {

        # Ensure Todos property exists and is an array

        if (-not $ProjectObject.PSObject.Properties.Name.Contains('Todos') -or $ProjectObject.Todos -eq $null) {

             $ProjectObject | Add-Member -MemberType NoteProperty -Name 'Todos' -Value @() -Force

        } elseif ($ProjectObject.Todos -isnot [array]) {

             $ProjectObject.Todos = @($ProjectObject.Todos) # Convert single item to array

        }

        $ProjectObject.Todos += $newTodo # Add the new todo to the array

        Write-AppLog "Added Todo '$Task' to project '$($ProjectObject.ID2)' (in memory)." "INFO"

        Show-Success "Todo '$Task' added (in memory). Remember to save if applicable."

        return $true # Indicate success (for Project Detail view to trigger save)

    } catch {

        Handle-Error $_ "Adding new Todo object to project's Todos array"

        return $false # Indicate failure

    }

}

 

function Update-TodoInProject {

    param(

        [Parameter(Mandatory=$true)][PSCustomObject]$ProjectObject,

        [Parameter(Mandatory=$true)][PSCustomObject]$TodoObject # The specific Todo object to update

    )

 

    Clear-Host; Draw-Title "UPDATE TODO: $($TodoObject.Task)"

    Show-Info "Editing Todo for Project: $($ProjectObject.ID2). Press Enter to keep current value."

 

    # Store original values for change detection

    $originalTodoData = $TodoObject.PSObject.Copy()

    $itemChanged = $false

 

    # --- Get Updated Values ---

    $newTask = Get-InputWithPrompt "Task description" $TodoObject.Task

    if ([string]::IsNullOrWhiteSpace($newTask)) { Show-Warning "Task cannot be empty. Keeping original."; $newTask = $TodoObject.Task }

    if ($TodoObject.Task -ne $newTask) { $TodoObject.Task = $newTask; $itemChanged = $true }

 

    # Due Date

    $dueDateInput = Get-InputWithPrompt "Due date ($($global:AppConfig.displayDateFormat)) or '-' to clear" $TodoObject.DueDate -ForceDefaultFormat

    $newDueDateInternal = $TodoObject.DueDate # Start with original

    if($dueDateInput -eq '-') { # Clear date

        if ($TodoObject.DueDate -ne "") { $TodoObject.DueDate = ""; $itemChanged = $true }

    } else {

        $parsedInternal = Parse-DateSafeInternal $dueDateInput

        if (![string]::IsNullOrEmpty($parsedInternal) -and $TodoObject.DueDate -ne $parsedInternal) {

             $TodoObject.DueDate = $parsedInternal; $itemChanged = $true

        } elseif (![string]::IsNullOrEmpty($dueDateInput) -and [string]::IsNullOrEmpty($parsedInternal)) {

            Show-Warning "Invalid due date format. Keeping original."

        } # If input was empty and date was already empty, no change. If input empty and date existed, no change.

    }

 

    # Priority

    $priorityMapReverse = @{ "High"=1; "Normal"=2; "Low"=3 }

    $currentPriorityValue = if ($priorityMapReverse.ContainsKey($TodoObject.Priority)) { $priorityMapReverse[$TodoObject.Priority] } else { 2 } # Default to Normal if unknown

    $priorityChoice = Get-NumericChoice -Prompt "Priority (Current: $($TodoObject.Priority) [${currentPriorityValue}]) (1=High, 2=Normal, 3=Low)" -MinValue 1 -MaxValue 3 -CancelOption "0"

    if ($priorityChoice -ne $null) {

        $newPriorityText = switch ($priorityChoice) { 1 {"High"} 2 {"Normal"} 3 {"Low"} }

        if ($TodoObject.Priority -ne $newPriorityText) { $TodoObject.Priority = $newPriorityText; $itemChanged = $true }

    } # If null, no change

 

    # Status

    $statusMapReverse = @{ "Pending"=1; "Completed"=2 }

    $currentStatusValue = if ($statusMapReverse.ContainsKey($TodoObject.Status)) { $statusMapReverse[$TodoObject.Status] } else { 1 }

    $statusChoice = Get-NumericChoice -Prompt "Status (Current: $($TodoObject.Status) [${currentStatusValue}]) (1=Pending, 2=Completed)" -MinValue 1 -MaxValue 2 -CancelOption "0"

    if ($statusChoice -ne $null) {

        $newStatus = switch ($statusChoice) { 1 {"Pending"} 2 {"Completed"} }

        if ($TodoObject.Status -ne $newStatus) {

             $TodoObject.Status = $newStatus

             # Update CompletedDate based on status change

             if ($newStatus -eq "Completed") { $TodoObject.CompletedDate = (Get-Date).ToString($global:DATE_FORMAT_INTERNAL) }

             else { $TodoObject.CompletedDate = "" } # Clear completed date if set back to Pending

             $itemChanged = $true

        }

    } # If null, no change

 

    # --- Report Result ---

    if ($itemChanged) {

        Write-AppLog "Updated Todo '$($TodoObject.TodoID)' for project '$($ProjectObject.ID2)' (in memory)." "INFO"

        Show-Success "Todo updated (in memory). Remember to save if applicable."

    } else {

        Show-Info "No changes were made to the Todo."

    }

    return $itemChanged # Return true if changes were made, false otherwise

}

 

function Remove-TodoFromProject {

    param(

        [Parameter(Mandatory=$true)][PSCustomObject]$ProjectObject,

        [Parameter(Mandatory=$true)][PSCustomObject]$TodoObjectToRemove

    )

 

    Clear-Host; Draw-Title "REMOVE TODO: $($TodoObjectToRemove.Task)"

    Show-Warning "This will remove the Todo item from Project: $($ProjectObject.ID2)"

 

    $confirm = Confirm-ActionNumeric -ActionDescription "Confirm removal of this Todo?"

    if ($confirm -ne $true) { Write-AppLog "Remove Todo cancelled by user for '$($TodoObjectToRemove.TodoID)'." "INFO"; Show-Warning "Cancelled."; return $false }

 

    try {

        # Ensure Todos is an array

         if ($null -eq $ProjectObject.Todos -or $ProjectObject.Todos -isnot [array]) {

             Write-AppLog "Cannot remove Todo '$($TodoObjectToRemove.TodoID)', Todos array is missing or invalid on project '$($ProjectObject.ID2)'." "ERROR"

             Show-Error "Cannot remove Todo - project data seems inconsistent."

             return $false

         }

 

        # Filter out the Todo to remove using its unique ID

        $updatedTodos = @($ProjectObject.Todos | Where-Object { $_.TodoID -ne $TodoObjectToRemove.TodoID })

 

        # Check if the count decreased (i.e., item was actually found and removed)

        if ($updatedTodos.Count -lt $ProjectObject.Todos.Count) {

             $ProjectObject.Todos = $updatedTodos # Update the project object in memory

             Write-AppLog "Removed Todo '$($TodoObjectToRemove.TodoID)' from project '$($ProjectObject.ID2)' (in memory)." "INFO"

             Show-Success "Todo removed (in memory). Remember to save if applicable."

             return $true # Indicate success

        } else {

             Write-AppLog "Todo '$($TodoObjectToRemove.TodoID)' not found in project '$($ProjectObject.ID2)' Todos array during removal attempt." "WARN"

             Show-Warning "Todo item was not found in the project's list. No changes made."

             return $false # Indicate no change / failure to find

        }

    } catch {

        Handle-Error $_ "Removing Todo object from project's Todos array"

        return $false # Indicate failure

    }

}

#endregion

 

#region Schedule View Function (Uses PSStyle UI Helpers)

function Show-ScheduleView {
    Clear-Host; Draw-Title "UPCOMING TODO SCHEDULE (Current & Next Work Week)"
    $theme = $global:currentTheme

    $today = (Get-Date).Date
    # Find start of current work week (Monday)
    $currentWeekStart = $today; while ($currentWeekStart.DayOfWeek -ne [System.DayOfWeek]::Monday) { $currentWeekStart = $currentWeekStart.AddDays(-1) }
    $currentWeekEnd = $currentWeekStart.AddDays(4) # Monday to Friday
    # Find start and end of next work week
    $nextWeekStart = $currentWeekStart.AddDays(7)
    $nextWeekEnd = $nextWeekStart.AddDays(4) # Monday to Friday

    # Display week ranges using themed Info style
    $infoStyle = Get-PSStyleValue $theme "Palette.InfoFG" "#5FD7FF" "Foreground"
    Write-Host (Apply-PSStyle -Text "Current Work Week: $($currentWeekStart.ToString($global:AppConfig.displayDateFormat)) to $($currentWeekEnd.ToString($global:AppConfig.displayDateFormat))" -FG $infoStyle)
    Write-Host (Apply-PSStyle -Text "Next Work Week:    $($nextWeekStart.ToString($global:AppConfig.displayDateFormat)) to $($nextWeekEnd.ToString($global:AppConfig.displayDateFormat))" -FG $infoStyle)
    Write-Host ""

    $allProjects = Load-ProjectTodoJson
    if ($allProjects.Count -eq 0) { Show-Warning "No projects found in data file."; Pause-Screen; return }

    # Find all pending Todos within the current or next work week
    $upcomingTodos = @()
    foreach ($project in $allProjects) {
        # Ensure Todos is not null and is an array before trying to iterate
        if ($null -eq $project.Todos -or $project.Todos -isnot [array] -or $project.Todos.Count -eq 0) { continue }

        foreach ($item in $project.Todos) {
            # Skip if not pending or no due date
            if ($item.Status -ne "Pending" -or [string]::IsNullOrEmpty($item.DueDate)) { continue }

            $dueDate = $null
            if ($item.DueDate -notmatch '^\d{8}$') {
                Write-AppLog "Invalid DueDate format '$($item.DueDate)' for Todo '$($item.TodoID)' in schedule view." "WARN"
                continue # Skip if format is wrong
            }

            try {
                $dueDate = [datetime]::ParseExact($item.DueDate, $global:DATE_FORMAT_INTERNAL, $null).Date
            } catch {
                Write-AppLog "Error parsing DueDate '$($item.DueDate)' for Todo '$($item.TodoID)' in schedule view: $($_.Exception.Message)" "WARN"
                continue # Skip if parsing fails
            }

            # Check if due date falls within either work week (Mon-Fri)
            if (($dueDate -ge $currentWeekStart -and $dueDate -le $currentWeekEnd) -or
                ($dueDate -ge $nextWeekStart -and $dueDate -le $nextWeekEnd)) {

                # <<< MODIFICATION: Create a new object with calculated properties >>>
                try {
                    $processedTodo = [PSCustomObject]@{
                        # Copy original Todo properties
                        TodoID        = $item.TodoID
                        Task          = $item.Task
                        DueDate       = $item.DueDate # Keep original format for display potentially
                        Priority      = $item.Priority
                        Status        = $item.Status
                        CreatedDate   = $item.CreatedDate
                        CompletedDate = $item.CompletedDate
                        # Add calculated/context properties
                        ProjectID2    = $project.ID2
                        ParsedDueDate = $dueDate
                        PriorityValue = switch($item.Priority){'High'{1}'Normal'{2}'Low'{3}default{4}}
                        IsNextWeek    = ($dueDate -ge $nextWeekStart)
                    }
                    $upcomingTodos += $processedTodo
                } catch {
                    Handle-Error $_ "Creating processed Todo object for schedule view (Project: $($project.ID2), Todo: $($item.Task))"
                }
                # <<< END MODIFICATION >>>
            }
        }
    }

    if ($upcomingTodos.Count -eq 0) { Show-Warning "No pending ToDos found for the current or next work week (Mon-Fri)."; Pause-Screen; return }

    # Sort Todos by Due Date, then Priority (using properties from the new objects)
    try { $sortedUpcoming = @($upcomingTodos | Sort-Object ParsedDueDate, PriorityValue -ErrorAction Stop) }
    catch { Handle-Error $_ "Sorting upcoming Todos for schedule view"; Show-Warning "Could not sort Todos."; $sortedUpcoming = $upcomingTodos }

    # --- Prepare Table Data and Row Colors ---
    $tableData = @()
    $rowColors = @{} # Use semantic keys for highlighting
    $idCounter = 1
    foreach ($item in $sortedUpcoming) { # Iterate through the processed objects
        $rowHighlightKey = $null # Default: no specific highlight
        $cellHighlights = @{} # Cell-specific highlights

        # Determine highlighting based on week and overdue status
        if ($item.ParsedDueDate.Date -lt $today) {
            $rowHighlightKey = "Overdue" # Overdue takes precedence
        } elseif ($item.IsNextWeek) {
            $rowHighlightKey = "SchedNext" # Highlight as Next Week
        } else {
            $rowHighlightKey = "SchedCurrent" # Highlight as Current Week
        }

        # Prepare row data for the "Todos" view type
        $tableData += ,@(
            $idCounter.ToString(),
            $item.Task,
            $item.ProjectID2,
            (Format-DateSafeDisplay $item.DueDate), # Use original string for formatting
            $item.Priority,
            $item.Status
        )

        # Assign row coloring info
        if ($rowHighlightKey) { $rowColors[$idCounter - 1] = $rowHighlightKey }

        $idCounter++
    }

    # Display the table
    Format-TableUnicode -ViewType "Todos" -Data $tableData -RowColors $rowColors
    Write-Host ""

    # Display Legend using PSStyle
    $legendCurrentFG = Get-PSStyleValue $theme "DataTable.Highlight.SchedCurrent.FG" "#5FFF87" "Foreground"
    $legendCurrentBG = Get-PSStyleValue $theme "DataTable.Highlight.SchedCurrent.BG" $null "Background"
    $legendNextFG = Get-PSStyleValue $theme "DataTable.Highlight.SchedNext.FG" "#FFFF00" "Foreground"
    $legendNextBG = Get-PSStyleValue $theme "DataTable.Highlight.SchedNext.BG" $null "Background"
    $legendOverdueFG = Get-PSStyleValue $theme "DataTable.Highlight.Overdue.FG" "#FF005F" "Foreground"
    $legendOverdueBG = Get-PSStyleValue $theme "DataTable.Highlight.Overdue.BG" $null "Background"

    Write-Host (Apply-PSStyle -Text " Legend: " -FG $infoStyle) -NoNewline
    Write-Host (Apply-PSStyle -Text " Current Week " -FG $legendCurrentFG -BG $legendCurrentBG) -NoNewline
    Write-Host (Apply-PSStyle -Text " Next Week " -FG $legendNextFG -BG $legendNextBG) -NoNewline
    Write-Host (Apply-PSStyle -Text " Overdue " -FG $legendOverdueFG -BG $legendOverdueBG)

    Pause-Screen
}

#endregion

 # --- NEW FUNCTION: Create-FormattedTimesheet ---
 function Create-FormattedTimesheet {
     Clear-Host; Draw-Title "CREATE FORMATTED TIMESHEET (Mon-Fri)"
 
     # Get Week Start Date
     $defaultStartDateInternal = (Get-Date).Date; while ($defaultStartDateInternal.DayOfWeek -ne [System.DayOfWeek]::Monday) { $defaultStartDateInternal = $defaultStartDateInternal.AddDays(-1) }; $defaultStartDateStringInternal = $defaultStartDateInternal.ToString($global:DATE_FORMAT_INTERNAL)
     $startDateInput = Get-InputWithPrompt "Enter start date ($($global:AppConfig.displayDateFormat)) for week" $defaultStartDateStringInternal -ForceDefaultFormat
     $startDateInternal = Parse-DateSafeInternal $startDateInput
     if ([string]::IsNullOrEmpty($startDateInternal)) { if(-not [string]::IsNullOrWhiteSpace($startDateInput)){ Show-Error "Invalid start date." } else { Show-Warning "Cancelled." }; Pause-Screen; return }
     try { $startDate = [datetime]::ParseExact($startDateInternal, $global:DATE_FORMAT_INTERNAL, $null) } catch { Handle-Error $_ "Parsing start date for timesheet creation"; Pause-Screen; return }
     while ($startDate.DayOfWeek -ne [System.DayOfWeek]::Monday) { $startDate = $startDate.AddDays(-1) }
     $endDate = $startDate.AddDays(4) # Monday to Friday
 
     $weekStartDateStr = $startDate.ToString($global:AppConfig.displayDateFormat)
     Show-Info "Generating timesheet for week: $weekStartDateStr (Mon-Fri)"
 
     # Load Data
     $allTimeEntries = Get-CsvDataSafely -FilePath $Global:AppConfig.timeTrackingFile
     $allProjects = Load-ProjectTodoJson
     if ($null -eq $allTimeEntries) { Show-Error "Failed to load time entries. Cannot create timesheet."; Pause-Screen; return }
 
     # Create Project ID1 Lookup
     $projectIDLookup = @{}
     foreach ($proj in $allProjects) { if (-not $projectIDLookup.ContainsKey($proj.ID2)) { $projectIDLookup[$proj.ID2] = $proj.ID1 } }
 
     # Filter and Process Entries into a structured format
     $processedEntries = @{} # Hashtable: Key = ID2/Description, Value = Hashtable { ID1=val, Mon=hrs, Tue=hrs,... }
     $validEntryFound = $false
     $skippedCount = 0
     foreach ($entry in $allTimeEntries) {
         $entryDate = $null; $hoursValue = 0.0; $props = $entry.PSObject.Properties.Name
         if (-not ($props -contains 'Date') -or $entry.Date -notmatch '^\d{8}$') { $skippedCount++; continue }
         if (-not ($props -contains 'Hours') -or -not ([double]::TryParse($entry.Hours, [ref]$hoursValue))) { $skippedCount++; continue }
         try { $entryDate = [datetime]::ParseExact($entry.Date, $global:DATE_FORMAT_INTERNAL, $null).Date } catch { $skippedCount++; continue }
 
         # Check if within the Mon-Fri range
         if ($entryDate.Date -ge $startDate.Date -and $entryDate.Date -le $endDate.Date) {
             $validEntryFound = $true
             $id2Key = $entry.ID2
             $dayOfWeekShort = $entryDate.DayOfWeek.ToString().Substring(0,3) # Mon, Tue, Wed, Thu, Fri
 
             # Initialize entry if not exists, including ID1 lookup
             if (-not $processedEntries.ContainsKey($id2Key)) {
                  $id1Value = if ($projectIDLookup.ContainsKey($id2Key)) { $projectIDLookup[$id2Key] } else { "" }
                  $processedEntries[$id2Key] = @{ ID1 = $id1Value; Mon=0.0; Tue=0.0; Wed=0.0; Thu=0.0; Fri=0.0 }
             }
             # Add hours to the correct day
             if ($processedEntries[$id2Key].ContainsKey($dayOfWeekShort)) { $processedEntries[$id2Key][$dayOfWeekShort] += $hoursValue }
         }
     }
     if ($skippedCount -gt 0) { Show-Warning "$skippedCount time entries skipped due to format errors while generating report (see log)." }
     if (-not $validEntryFound) { Show-Warning "No valid time entries found for the specified week (Mon-Fri)."; Pause-Screen; return }
 
     # Prepare data for CSV Export (including empty columns)
     $outputDataForCsv = @()
     foreach ($id2Key in $processedEntries.Keys | Sort-Object) {
         $entryData = $processedEntries[$id2Key]
         $outputDataForCsv += [PSCustomObject]@{
             ID1 = $entryData.ID1
             ID2 = $id2Key
             # Add 4 empty columns explicitly - name them distinctively for ConvertTo-Csv
             _Empty1 = ""
             _Empty2 = ""
             _Empty3 = ""
             _Empty4 = ""
             # Daily Hours formatted
             Mon = $entryData.Mon.ToString("0.0")
             Tue = $entryData.Tue.ToString("0.0")
             Wed = $entryData.Wed.ToString("0.0")
             Thu = $entryData.Thu.ToString("0.0")
             Fri = $entryData.Fri.ToString("0.0")
         }
     }
 
     # Define Temp CSV Path from config or default
     $tempCsvPath = $Global:AppConfig.tempTimesheetCsvPath
     if ([string]::IsNullOrWhiteSpace($tempCsvPath)) {
         $tempCsvPath = Join-Path $scriptRoot "_temp_timesheet.csv"
         Write-AppLog "Temp timesheet path not in config, using default: $tempCsvPath" "DEBUG"
     }
 
     # Export to Temp CSV (Overwrites)
     try {
         # Construct the specific header string manually for Out-File
         $headerString = "ID1,ID2,,,,Mon,Tue,Wed,Thu,Fri"
         $headerString | Out-File -FilePath $tempCsvPath -Encoding UTF8 -Force -EA Stop
 
         # Append the data using ConvertTo-Csv, skip its header, handle potential commas in data
         # Using -UseQuotes AsNeeded is generally safer for clipboard data
         $outputDataForCsv | ConvertTo-Csv -NoTypeInformation -UseQuotes AsNeeded | Select-Object -Skip 1 | Out-File -FilePath $tempCsvPath -Encoding UTF8 -Append -EA Stop
 
         Write-AppLog "Created formatted timesheet CSV: $tempCsvPath" "INFO"
         Show-Info "Temporary timesheet CSV created at: $tempCsvPath"
 
         # Copy CSV Content to Clipboard
         try {
             Get-Content -Path $tempCsvPath -Raw -Encoding UTF8 | Set-Clipboard -EA Stop
             Show-Success "Formatted timesheet content copied to clipboard!"
         } catch {
             Handle-Error $_ "Copying timesheet CSV content to clipboard"
         }
     } catch {
         Handle-Error $_ "Creating or writing formatted timesheet CSV '$tempCsvPath'"
     }
     Pause-Screen
 }

#region Notes and Commands Functions (Uses PSStyle UI Helpers)

function Initialize-CommandSnippetFolder {

    # Ensure config is loaded before trying to access AppConfig

    if ($null -eq $Global:AppConfig) { Load-AppConfig }

    if ($null -eq $Global:AppConfig) { Show-Error "Cannot initialize snippet folder - config failed to load."; return $false }

 

    # Ensure the base data directory exists first (where config sits)

    $configDir = Join-Path $scriptRoot $Global:DefaultDataSubDir

    if (-not (Ensure-DirectoryExists -DirectoryPath $configDir)) { return $false } # Error handled by Ensure func

 

    # Now ensure the specific commands folder exists

    if (-not (Ensure-DirectoryExists -DirectoryPath $Global:AppConfig.commandsFolder)) {

        Show-Warning "Could not ensure Commands directory exists at: $($Global:AppConfig.commandsFolder)."

        return $false

    }

    return $true

}

 

function Add-CommandSnippet {

    Clear-Host; Draw-Title "ADD COMMAND SNIPPET"

    if (-not (Initialize-CommandSnippetFolder)) { Pause-Screen; return }

 

    $commandName = Get-InputWithPrompt "Snippet name (alphanumeric, underscores allowed)"

    # Validate name - simple check for invalid chars or empty

    if ([string]::IsNullOrWhiteSpace($commandName) -or $commandName -match '[\\/:*?"<>| ]+') { # Disallow spaces too

        Show-Error "Invalid snippet name. Use only letters, numbers, underscores. No spaces."

        Pause-Screen; return

    }

 

    $commandDescription = Get-InputWithPrompt "Description (optional, first line of snippet)"

 

    Show-Info "Enter the snippet text below. Type '!SAVE' on a new line to finish, or '!CANCEL' to abort."

    # Use a theme color for the instruction separator

    $theme = $global:currentTheme

    $separatorStyle = Get-PSStyleValue $theme "Palette.DisabledFG" "#808080" "Foreground"

    Write-Host (Apply-PSStyle -Text "--- Enter Snippet Text Below ---" -FG $separatorStyle)

 

    $snippetContentLines = [System.Collections.Generic.List[string]]::new()

    while ($true) {

        # Use a slightly different prompt for snippet input lines

        $line = Read-Host "Snippet>"

        if ($line -eq "!SAVE") { break }

        if ($line -eq "!CANCEL") { Write-AppLog "Add snippet cancelled by user during text entry." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

        $snippetContentLines.Add($line)

    }

 

    if ($snippetContentLines.Count -eq 0) { Write-AppLog "Add snippet cancelled - no content provided." "INFO"; Show-Warning "Cancelled - no snippet content entered."; Pause-Screen; return }

 

    # Construct file content with header

    $fileName = "$commandName.txt" # Standard extension

    $filePath = Join-Path $Global:AppConfig.commandsFolder $fileName

    $fileHeader = "# Description: $commandDescription`n---`n" # Simple header

    $fullFileContent = $fileHeader + ($snippetContentLines -join [System.Environment]::NewLine)

 

    # Check for existing file and confirm overwrite

    if (Test-Path $filePath) {

        if ((Confirm-ActionNumeric -ActionDescription "Snippet file '$fileName' already exists. Overwrite?") -ne $true) {

            Write-AppLog "Add snippet cancelled - file exists, user chose not to overwrite." "INFO"

            Show-Warning "Cancelled. File not overwritten."

            Pause-Screen; return

        }

    }

 

    # Save the file

    try {

        $fullFileContent | Out-File -FilePath $filePath -Encoding utf8 -Force -EA Stop

        Write-AppLog "Saved command snippet '$commandName' to '$filePath'" "INFO"

        Show-Success "Snippet '$commandName' saved successfully."

    } catch {

        Handle-Error $_ "Saving command snippet file '$filePath'"

    }

    Pause-Screen

}

 

function Edit-CommandSnippet {

    param([Parameter(Mandatory=$true)][System.IO.FileInfo]$SelectedFileObject)

 

    $filePath = $SelectedFileObject.FullName

    Clear-Host; Draw-Title "EDIT SNIPPET: $($SelectedFileObject.BaseName)"

 

    # Read existing content, separating header and body

    $description = ""

    $currentContentLines = @()

    $separatorFound = $false

    try {

        $allLines = Get-Content -Path $filePath -Encoding utf8 -EA Stop

        for ($i = 0; $i -lt $allLines.Count; $i++) {

            if (-not $separatorFound) {

                 if ($allLines[$i] -match '^\s*#\s*Description:\s*(.+)') { $description = $matches[1].Trim() }

                 elseif ($allLines[$i].Trim() -eq '---') { $separatorFound = $true }

                 # Ignore other potential header lines for now

            } else {

                 # Everything after separator is content

                 $currentContentLines += $allLines[$i]

            }

        }

        # If separator was never found, assume whole file (minus potential known header lines) is content

        if (-not $separatorFound) {

             Write-AppLog "Separator '---' not found editing '$($SelectedFileObject.Name)'. Treating content after known headers." "WARN"

             $startIndex = 0

             if ($allLines[0] -match '^\s*#\s*Description:') { $startIndex = 1 }

             $currentContentLines = $allLines[$startIndex..($allLines.Count - 1)]

        }

    } catch { Handle-Error $_ "Reading snippet file '$filePath' for edit"; Pause-Screen; return }

 

    Show-Info "Current Description: $description"

    $theme = $global:currentTheme

    $separatorStyle = Get-PSStyleValue $theme "Palette.DisabledFG" "#808080" "Foreground"

    Write-Host (Apply-PSStyle -Text "--- Current Snippet Content ---" -FG $separatorStyle)

    $currentContentLines | ForEach-Object { Write-Host "  $_" } # Basic display, no extra styling

    Write-Host (Apply-PSStyle -Text "--- End Current Content ---" -FG $separatorStyle)

    Write-Host ""

 

    # Get updated description

    $newDescription = Get-InputWithPrompt "New Description (Enter to keep current)" $description

 

    # Get updated content

    Show-Info "Enter the NEW snippet text below. Type '!SAVE' on a new line to finish, or '!CANCEL' to abort."

    Write-Host (Apply-PSStyle -Text "--- Enter New Snippet Text Below ---" -FG $separatorStyle)

    $newContentLines = [System.Collections.Generic.List[string]]::new()

    while ($true) {

        $line = Read-Host "NewSnippet>"

        if ($line -eq "!SAVE") { break }

        if ($line -eq "!CANCEL") { Write-AppLog "Edit snippet cancelled by user during text entry for '$($SelectedFileObject.Name)'." "INFO"; Show-Warning "Edit cancelled."; Pause-Screen; return }

        $newContentLines.Add($line)

    }

 

    # Construct new file content

    $newFileHeader = "# Description: $newDescription`n---`n"

    $fullNewContent = $newFileHeader + ($newContentLines -join [System.Environment]::NewLine)

 

    # Save the updated file

    try {

        $fullNewContent | Out-File -FilePath $filePath -Encoding utf8 -Force -EA Stop

        Write-AppLog "Updated command snippet '$($SelectedFileObject.BaseName)'" "INFO"

        Show-Success "Snippet '$($SelectedFileObject.BaseName)' updated successfully."

    } catch {

        Handle-Error $_ "Saving updated command snippet '$filePath'"

    }

    Pause-Screen

}

 

function Remove-CommandSnippet {

    param([Parameter(Mandatory=$true)][System.IO.FileInfo]$SelectedFileObject)

 

    Clear-Host; Draw-Title "REMOVE SNIPPET: $($SelectedFileObject.Name)"

    Show-Warning "This will permanently delete the snippet file."

    $theme = $global:currentTheme

    $infoStyle = Get-PSStyleValue $theme "Palette.InfoFG" "#5FD7FF" "Foreground"

    Write-Host (Apply-PSStyle -Text "File: $($SelectedFileObject.FullName)" -FG $infoStyle)

 

    # Show preview

    try {

        $preview = Get-Content -Path $SelectedFileObject.FullName -TotalCount 10 -Encoding utf8 -EA SilentlyContinue

        Write-Host (Apply-PSStyle -Text "Preview:" -FG $infoStyle)

        $preview | ForEach-Object {Write-Host (Apply-PSStyle -Text "  $_" -FG $infoStyle)}

        if($preview.Count -ge 10){ Write-Host (Apply-PSStyle -Text "  ..." -FG $infoStyle)}

    } catch {}

 

    # Confirm deletion

    if ((Confirm-ActionNumeric -ActionDescription "Confirm deletion of this snippet file?") -ne $true) {

        Write-AppLog "Remove snippet cancelled by user for '$($SelectedFileObject.Name)'." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return

    }


# Delete the file

    try {

        Remove-Item -Path $SelectedFileObject.FullName -Force -EA Stop

        Write-AppLog "Deleted command snippet '$($SelectedFileObject.BaseName)' from '$($SelectedFileObject.FullName)'" "INFO"

        Show-Success "Snippet '$($SelectedFileObject.BaseName)' deleted successfully."

    } catch {

        Handle-Error $_ "Deleting command snippet '$($SelectedFileObject.FullName)'"

    }

    Pause-Screen

}

 

function Search-CommandSnippets {

    Clear-Host; Draw-Title "SEARCH COMMAND SNIPPETS"

    if (-not (Initialize-CommandSnippetFolder)) { Pause-Screen; return }

 

    $searchTerm = Get-InputWithPrompt "Enter search term (searches name and description)"

    if ([string]::IsNullOrWhiteSpace($searchTerm)) { Show-Warning "No search term entered."; Pause-Screen; return }

 

    try { $commandFiles = @(Get-ChildItem -Path $Global:AppConfig.commandsFolder -Filter "*.txt" -File -EA Stop) }

    catch { Handle-Error $_ "Listing command snippets for search"; Pause-Screen; return }

    if ($commandFiles.Count -eq 0) { Show-Warning "No command snippets found in the folder."; Pause-Screen; return }

 

    $matchingFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    $pattern = try { [regex]::Escape($searchTerm) } catch { Handle-Error $_ "Escaping search term regex"; return }

 

    # Search filename and description header

    foreach ($file in $commandFiles) {

        $matchFound = $false

        # Check filename (basename without extension)

        if ($file.BaseName -match $pattern) { $matchFound = $true }

 

        # If not found in name, check description line in header

        if (-not $matchFound) {

            try {

                $headerLines = Get-Content -Path $file.FullName -TotalCount 3 -Encoding utf8 -EA SilentlyContinue

                $descLine = $headerLines | Where-Object { $_ -match '^\s*#\s*Description:\s*(.+)' } | Select-Object -First 1

                if ($descLine -and $matches[1] -match $pattern) { $matchFound = $true }

            } catch { Write-AppLog "Could not read header for snippet search: $($file.Name)" "WARN" }

        }

 

        if ($matchFound) { $matchingFiles.Add($file) }

    }

 

    if ($matchingFiles.Count -eq 0) { Show-Warning "No snippets found matching '$searchTerm'."; Pause-Screen; return }

 

    Show-Info "$($matchingFiles.Count) snippet(s) found matching '$searchTerm'."

    # Pass the matching files to the selection/action function

    Select-And-Action-CommandSnippet -SnippetFiles $matchingFiles.ToArray() -Caller "Search Results"

    # Pause-Screen is handled within Select-And-Action-CommandSnippet

}

 

function Select-And-Action-CommandSnippet {

    param(

        [Parameter(Mandatory=$true)][System.IO.FileInfo[]]$SnippetFiles,

        [string]$Caller = "List Snippets" # Title context (e.g., "List Snippets", "Search Results")

    )

    if ($SnippetFiles.Count -eq 0) { Show-Warning "No snippets provided for action."; Pause-Screen; return }

 

    # Prepare items for Select-ItemFromList, extracting description

    $selectionItems = @($SnippetFiles | ForEach-Object {

        $name = $_.BaseName

        $description = ""

        try {

            $headerLines = Get-Content -Path $_.FullName -TotalCount 3 -Encoding utf8 -EA SilentlyContinue

            $descLine = $headerLines | Where-Object { $_ -match '^\s*#\s*Description:\s*(.+)' } | Select-Object -First 1

            if ($descLine) { $description = $matches[1].Trim() }

        } catch {}

        # Return an object containing the original FileInfo and extracted data

        [PSCustomObject]@{ Item = $_; BaseName = $name; FullName=$_.FullName; Description = $description }

    })

 

    # Let user select a snippet

    $selectedObjectWrapper = Select-ItemFromList -Title "$Caller - SELECT SNIPPET" -Items $selectionItems -ViewType "CommandSelection" -Prompt "Select snippet number (0=Cancel)"

    if (-not $selectedObjectWrapper) { Write-AppLog "Snippet action cancelled at selection ($Caller)." "INFO"; Show-Warning "Cancelled."; Pause-Screen; return }

 

    $selectedFileObject = $selectedObjectWrapper.Item # Get the original FileInfo object

 

    # Show Actions Menu

    Clear-Host; Draw-Title "ACTION FOR SNIPPET: $($selectedFileObject.BaseName)"

    Show-Info "Description: $($selectedObjectWrapper.Description)"

    Write-Host ""

    $theme = $global:currentTheme

    $successStyle = Get-PSStyleValue $theme "Palette.SuccessFG" "#5FFF87" "Foreground"

    $optionStyle = Get-PSStyleValue $theme "Menu.Option.FG" "#FFFFFF" "Foreground"

    $errorStyle = Get-PSStyleValue $theme "Palette.ErrorFG" "#FF0000" "Foreground"

    $warnStyle = Get-PSStyleValue $theme "Palette.WarningFG" "#FFFF00" "Foreground"

 

    Write-Host (Apply-PSStyle -Text "[1] Copy Content to Clipboard" -FG $successStyle)

    Write-Host (Apply-PSStyle -Text "[2] Edit Snippet" -FG $optionStyle)

    Write-Host (Apply-PSStyle -Text "[3] Delete Snippet" -FG $errorStyle)

    Write-Host ""

    Write-Host (Apply-PSStyle -Text "[0] Cancel" -FG $warnStyle)

    Write-Host ""

 

    $actionChoice = Get-NumericChoice -Prompt "Choose action for '$($selectedFileObject.BaseName)'" -MinValue 0 -MaxValue 3

 

    # Execute Action

    switch ($actionChoice) {

        1 { # Copy to Clipboard

            try {

                $scriptLines = Get-Content -Path $selectedFileObject.FullName -Encoding utf8 -EA Stop

                $startIndex = -1; $separatorFound = $false

                # Find content after separator '---'

                for ($i = 0; $i -lt $scriptLines.Count; $i++) {

                    if ($scriptLines[$i].Trim() -eq '---') { $startIndex = $i + 1; $separatorFound = $true; break }

                }

                # Fallback if no separator found (copy after known headers)

                if (-not $separatorFound) {

                    $startIndex = 0

                    if ($scriptLines[0] -match '^\s*#\s*Description:') { $startIndex = 1 }

                    Write-AppLog "Separator '---' not found in snippet '$($selectedFileObject.Name)' for copy." "WARN"

                }

 

                $snippetContentToCopy = ""

                if ($startIndex -ge 0 -and $startIndex -lt $scriptLines.Count) {

                    $snippetContentToCopy = $scriptLines[$startIndex..($scriptLines.Count - 1)] -join [System.Environment]::NewLine

                } elseif ($scriptLines.Count -gt 0 -and $startIndex -eq -1) {

                     # Handle case where there's content but no separator/header found

                     $snippetContentToCopy = $scriptLines -join [System.Environment]::NewLine

                     Show-Warning "Could not reliably find start of content. Copying entire file."

                }

 

                if (-not [string]::IsNullOrWhiteSpace($snippetContentToCopy)) {

                    try { $snippetContentToCopy | Set-Clipboard -EA Stop; Write-AppLog "Copied snippet '$($selectedFileObject.BaseName)' content to clipboard." "INFO"; Show-Success "Snippet content copied to clipboard!" }

                    catch { Handle-Error $_ "Copying snippet '$($selectedFileObject.BaseName)' to clipboard" }

                } else { Show-Warning "No content found in snippet to copy." }

            } catch { Handle-Error $_ "Reading snippet '$($selectedFileObject.FullName)' for copy" }

            Pause-Screen

        }

        2 { Edit-CommandSnippet -SelectedFileObject $selectedFileObject } # Edit function handles pause

        3 { Remove-CommandSnippet -SelectedFileObject $selectedFileObject } # Remove function handles pause

        0 { Write-AppLog "Snippet action cancelled by user for '$($selectedFileObject.BaseName)'." "INFO"; Show-Warning "Cancelled."; Pause-Screen }

        default { Show-Warning "Invalid action choice."; Pause-Screen } # Should be caught by Get-NumericChoice

    }

}


#endregion
# --- Moved Action Map Definition Here ---
# --- MODIFIED Global Action Map with updated numbering and new action ---
$global:mainMenuActionMap = @{
    # Projects Section
    '1'  = { New-ProjectFromRequest }
    '1a' = { Add-ManualProject }
    '2'  = { Show-ProjectList }
    '3'  = { Show-ProjectList -IncludeCompleted }
    '4'  = { Set-Project }
    '5'  = { Set-ProjectComplete }
    '6'  = { Open-ProjectFiles }
    '7'  = { Remove-Project }
    '8'  = { return "Dashboard" } # Dashboard is 8

    # Time Tracking Section (Renumbered + New)
    '9'  = { Add-ProjectTimeInteractive }      # Was 8
    '10' = { Add-NonProjectTimeInteractive }   # Was 9
    '11' = { Get-TimeSheet }                   # Was 10
    '12' = { Create-FormattedTimesheet }       # NEW

    # Schedule & Calendar Section (Renumbered)
    '13' = { Show-ScheduleView }               # Was 11
    '14' = { Show-Calendar }                   # Was 12
    '15' = { Calculate-FutureDate }            # Was 13
    '16' = { Show-YearCalendar }               # Was 14

    # Commands Section (Renumbered)
    '17' = { Add-CommandSnippet }              # Was 15
    '18' = { # List/Manage Snippets           # Was 16
               if (Initialize-CommandSnippetFolder) {
                   try { $files = @(Get-ChildItem -Path $Global:AppConfig.commandsFolder -Filter "*.txt" -File -EA Stop) | Sort-Object Name }
                   catch { Handle-Error $_ "Listing snippets"; $files=@() }
                   if ($files.Count -eq 0) { Show-Warning "No command snippets found."; Pause-Screen }
                   else { Select-And-Action-CommandSnippet -SnippetFiles $files -Caller "List Snippets" }
               } else { Pause-Screen }
           }
    '19' = { Search-CommandSnippets }          # Was 17
    '25' = { Start-PomodoroSession }

    # General Section (Keys unchanged)
    'c'  = { Configure-Settings }
    'h'  = { Show-Help }
    's'  = { Invoke-SetupRoutine }
    't'  = { Change-Theme }
    'z'  = { Show-Trogdor -WithMessage }
    'q'  = { return "Quit" }
}
# --- End Moved Action Map Definition ---

#region Main Menu & Loop (Uses PSStyle UI Helpers) # KEEP THIS REGION TAG
 

# PowerShell Calendar: Grid + Styled Boxed Views (Fixed Array Handling + Bottom Border Alignment)

# 1. Generate a plain calendar grid (string array)
function Get-CalendarGrid {
    param(
        [int]$Year  = (Get-Date).Year,
        [int]$Month = (Get-Date).Month
    )
    $lines = @()
    # Header centered in ~20 chars
    $lines += (Get-Date -Year $Year -Month $Month -Day 1).ToString('MMMM yyyy').PadLeft(20)
    $lines += 'Su Mo Tu We Th Fr Sa'

    $firstDow = (Get-Date -Year $Year -Month $Month -Day 1).DayOfWeek.value__
    $line     = '   ' * $firstDow
    $maxDay   = [DateTime]::DaysInMonth($Year, $Month)

    for ($d = 1; $d -le $maxDay; $d++) {
        $line += '{0,2} ' -f $d
        if ((($firstDow + $d) % 7) -eq 0) {
            $lines += $line.TrimEnd(); $line = ''
        }
    }
    if ($line) { $lines += $line.TrimEnd() }

    # Ensure grid always has 8 lines total (header + weekdays + 6 weeks)
    while ($lines.Count -lt 8) {
        $lines += ''.PadRight(20)
    }

    return $lines
}

# 2. Wrap grid in a styled box
function Get-BoxedCalendar {
    param(
        [int]$Year,
        [int]$Month,
        [hashtable]$Theme = $global:currentTheme
    )
    $grid  = Get-CalendarGrid -Year $Year -Month $Month
    $width = $grid[0].Length

    $fgB   = Get-PSStyleValue $Theme 'Palette.Border' '#00AF87' 'Foreground'
    $b     = Get-BorderStyleChars -StyleName 'Single'
    $out   = [System.Collections.Generic.List[string]]::new()

    $out.Add((Apply-PSStyle -Text ($b.TopLeft + ($b.Horizontal * $width) + $b.TopRight) -FG $fgB))
    foreach ($row in $grid) {
        $line = $b.Vertical + $row.PadRight($width) + $b.Vertical
        $out.Add((Apply-PSStyle -Text $line -FG $fgB))
    }
    $out.Add((Apply-PSStyle -Text ($b.BottomLeft + ($b.Horizontal * $width) + $b.BottomRight) -FG $fgB))
    return $out.ToArray()
}

# 3. Show three months side-by-side (fixed array grouping)
function Show-Calendar {
    Clear-Host; Draw-Title 'CALENDAR (3-MONTH VIEW)'
    $now   = Get-Date
    $dates = @($now.AddMonths(-1), $now, $now.AddMonths(1))
    $blocks = @()
    foreach ($dt in $dates) {
        $blocks += ,(Get-BoxedCalendar -Year $dt.Year -Month $dt.Month)
    }
    $maxLines = ($blocks | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
    for ($i = 0; $i -lt $maxLines; $i++) {
        $parts = $blocks | ForEach-Object {
            if ($_.Count -gt $i) { $_[$i] } else { ' ' * ($_[0].Length) }
        }
        Write-Host ($parts -join '  ')
    }
    Pause-Screen
}

# 4. Show full-year calendar in rows of N months
function Show-YearCalendar {
    param(
        [int]$Year   = (Get-Date).Year,
        [int]$PerRow = 3
    )
    Clear-Host; Draw-Title "YEAR CALENDAR - $Year"
    $all = @()
    for ($m = 1; $m -le 12; $m++) {
        $all += ,(Get-BoxedCalendar -Year $Year -Month $m)
    }
    for ($start = 0; $start -lt 12; $start += $PerRow) {
        $slice    = $all[$start..[Math]::Min($start + $PerRow - 1, 11)]
        $maxLines = ($slice | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
        for ($i = 0; $i -lt $maxLines; $i++) {
            $parts = $slice | ForEach-Object {
                if ($_.Count -gt $i) { $_[$i] } else { ' ' * ($_[0].Length) }
            }
            Write-Host ($parts -join '  ')
        }
        Write-Host ''
    }
    Pause-Screen
}

 

function Calculate-FutureDate {

    Clear-Host; Draw-Title "CALCULATE FUTURE DATE"

    $theme = $global:currentTheme

    # Get styles

    $headerStyle = Get-PSStyleValue $theme "Menu.Header.FG" "#FFFFD7" "Foreground"

    $optionStyle = Get-PSStyleValue $theme "Menu.Option.FG" "#00AF5F" "Foreground"

    $dataStyle = Get-PSStyleValue $theme "Palette.DataFG" "#00D787" "Foreground"

    $successStyle = Get-PSStyleValue $theme "Palette.SuccessFG" "#5FFF87" "Foreground"

    $infoStyle = Get-PSStyleValue $theme "Palette.InfoFG" "#5Fafd7" "Foreground"

 

    $Days = 0; $Weeks = 0; $Months = 0

 

    # Ask calculation type

    Write-Host (Apply-PSStyle -Text "Select calculation type:" -FG $headerStyle)

    Write-Host (Apply-PSStyle -Text " 1. Add days   2. Add weeks   3. Add months   0. Cancel" -FG $optionStyle)

    $calcType = Get-NumericChoice -Prompt "Enter choice" -MinValue 0 -MaxValue 3

 

    switch ($calcType) {

        1 {

            $daysInput = Get-InputWithPrompt "Enter number of days to add"

            if ($daysInput -match '^\d+$') { $Days = [int]$daysInput }

            else { Show-Error "Invalid number of days entered."; Pause-Screen; return }

        }

        2 {

            $weeksInput = Get-InputWithPrompt "Enter number of weeks to add"

            if ($weeksInput -match '^\d+$') { $Weeks = [int]$weeksInput }

            else { Show-Error "Invalid number of weeks entered."; Pause-Screen; return }

        }

        3 {

            $monthsInput = Get-InputWithPrompt "Enter number of months to add"

            if ($monthsInput -match '^\d+$') { $Months = [int]$monthsInput }

            else { Show-Error "Invalid number of months entered."; Pause-Screen; return }

        }

        0 { Show-Warning "Cancelled."; Pause-Screen; return }

        default { Show-Error "Invalid calculation type selected."; Pause-Screen; return } # Should not happen

    }

 

    # Get start date

    $todayInternal = (Get-Date).ToString($global:DATE_FORMAT_INTERNAL)

    $startDateInput = Get-InputWithPrompt "Start date ($($global:AppConfig.displayDateFormat))" $todayInternal -ForceDefaultFormat

    $startDateInternal = Parse-DateSafeInternal $startDateInput

    if ([string]::IsNullOrEmpty($startDateInternal)) { Show-Error "Invalid start date format."; Pause-Screen; return }

 

    try { $startDate = [datetime]::ParseExact($startDateInternal, $global:DATE_FORMAT_INTERNAL, $null) }

    catch { Handle-Error $_ "Parsing start date for future date calculation"; Pause-Screen; return }

 

    # Calculate end date

    $endDate = $startDate.AddMonths($Months).AddDays($Weeks * 7).AddDays($Days)

 

    # Display results using PSStyle

    Write-Host ""

    Write-Host (Apply-PSStyle -Text "       Start Date: $($startDate.ToString($global:AppConfig.displayDateFormat)) ($($startDate.DayOfWeek))" -FG $dataStyle)

    $addingText = @(); if($Days -gt 0){ $addingText += "$Days day(s)"}; if($Weeks -gt 0){ $addingText += "$Weeks week(s)"}; if($Months -gt 0){ $addingText += "$Months month(s)"}

    Write-Host (Apply-PSStyle -Text "      Adding Time: $($addingText -join ', ')" -FG $dataStyle)

    Write-Host (Apply-PSStyle -Text "Calculated End Date: $($endDate.ToString($global:AppConfig.displayDateFormat)) ($($endDate.DayOfWeek))" -FG $successStyle)

    Write-Host (Apply-PSStyle -Text "   Total Days Added: $(($endDate - $startDate).Days)" -FG $infoStyle)

    Pause-Screen

}

#endregion

 

#region Setup Function (Uses PSStyle UI Helpers)

function Invoke-SetupRoutine {

    Clear-Host; Draw-Title "SETUP ROUTINE (PLACEHOLDER)"

    Show-Warning "This is a placeholder function."

    Show-Info "Initial setup involves:"

    Show-Info " 1. Ensuring the '$($Global:DefaultDataSubDir)' directory exists (usually automatic)."

    Show-Info " 2. Creating/editing the 'config.json' file within that directory."

    Show-Info " 3. Critically, setting the 'caaTemplatePath' in 'config.json' or via 'Configure Settings'."

    Show-Info ""

    Show-Info "Use 'New Project from Request' (Option 1) or 'Add Manual Project' (Option 1a) to add projects."

    Show-Info "Use 'Configure Settings' (Option C) from the Main Menu to modify paths and theme."

    Pause-Screen

}

#endregion

 

#region Dashboard & Project Detail View (Uses PSStyle UI Helpers)

 

function Show-Dashboard {
#    Clear-Host
    Draw-Title "PROJECT MANAGEMENT DASHBOARD" # Generic Title
    $theme = $global:currentTheme

    # Get Styles using PSStyleValue
    $headerStyleFG = Get-PSStyleValue $theme "Menu.Header.FG" "#FFFFD7" "Foreground"
    $headerStyleBG = Get-PSStyleValue $theme "Menu.Header.BG" "#1C1C1C" "Background"
    $errorStyleFG = Get-PSStyleValue $theme "Palette.ErrorFG" "#FF0000" "Foreground"
    $errorStyleBG = Get-PSStyleValue $theme "Palette.ErrorBG" $null "Background"
    $dueSoonStyleFG = Get-PSStyleValue $theme "Palette.DueSoonFG" "#FFFF87" "Foreground"
    $infoStyleFG = Get-PSStyleValue $theme "Palette.InfoFG" "#5Fafd7" "Foreground"
    $optionStyleFG = Get-PSStyleValue $theme "Menu.Option.FG" "#00AF5F" "Foreground"
    $warnStyleFG = Get-PSStyleValue $theme "Palette.WarningFG" "#FFFF00" "Foreground"

    # --- Load Data ---
    $allProjects = Load-ProjectTodoJson
    $hoursMap = Get-ProjectHoursMapByID2

    # --- Calculate Summary Stats ---
    $activeProjects = @($allProjects | Where-Object { [string]::IsNullOrEmpty($_.CompletedDate) })
    $completedProjectsCount = $allProjects.Count - $activeProjects.Count
    $totalTrackedHours = ($hoursMap.Values | Measure-Object -Sum).Sum

    # Calculate Overdue/Due Soon Todos
    $overdueTodos = @(); $dueSoonTodos = @()
    $today = (Get-Date).Date
    foreach ($project in $activeProjects) {
        if ($null -eq $project.Todos -or $project.Todos -isnot [array] -or $project.Todos.Count -eq 0) { continue } # Added type check
        foreach ($todo in $project.Todos | Where-Object { $_.Status -eq "Pending" -and -not [string]::IsNullOrEmpty($_.DueDate) }) {
            try {
                if($todo.DueDate -match '^\d{8}$') {
                    $dueDate = [datetime]::ParseExact($todo.DueDate, $global:DATE_FORMAT_INTERNAL, $null).Date
                    if ($dueDate -lt $today) {
                        $overdueTodos += [PSCustomObject]@{ ProjectID2=$project.ID2; Task=$todo.Task; DueDate=$todo.DueDate }
                    } elseif (($dueDate - $today).Days -lt 7) { # Due within 7 days (configurable?)
                        $dueSoonTodos += [PSCustomObject]@{ ProjectID2=$project.ID2; Task=$todo.Task; DueDate=$todo.DueDate }
                    }
                } else { Write-AppLog "Invalid DueDate format '$($todo.DueDate)' for Todo '$($item.TodoID)' in dashboard calc." "WARN" }
            } catch { Write-AppLog "Error parsing DueDate '$($todo.DueDate)' for Todo '$($item.TodoID)' in dashboard calc: $($_.Exception.Message)" "WARN" }
        }
    }

    # --- Display Summary Header ---
    $summaryText = "[ Overview ] Active: $($activeProjects.Count) | Completed: $completedProjectsCount | Total Hours: $($totalTrackedHours.ToString('F1')) | Overdue Todos: $($overdueTodos.Count) | Due Soon Todos: $($dueSoonTodos.Count)"
    Write-Host (Apply-PSStyle -Text $summaryText.PadRight(80) -FG $headerStyleFG -BG $headerStyleBG) # Pad for full width BG effect if BG is set
    Write-Host ""

    # --- Display Overdue/Due Soon Sections ---
    if ($overdueTodos.Count -gt 0) {
        Write-Host (Apply-PSStyle -Text "[ Overdue ToDos ($($overdueTodos.Count)) ]" -FG $errorStyleFG -BG $errorStyleBG) # Apply optional BG too
        $overdueTodos | Select-Object -First 5 | ForEach-Object {
            Write-Host (Apply-PSStyle -Text " - $($_.ProjectID2): $($_.Task) (Due: $(Format-DateSafeDisplay $_.DueDate))" -FG $errorStyleFG)
        }
        if ($overdueTodos.Count -gt 5) { Write-Host (Apply-PSStyle -Text "   ... and $($overdueTodos.Count - 5) more." -FG $errorStyleFG) }
        Write-Host ""
    }
    if ($dueSoonTodos.Count -gt 0) {
        Write-Host (Apply-PSStyle -Text "[ ToDos Due Soon ($($dueSoonTodos.Count)) ]" -FG $dueSoonStyleFG)
        $dueSoonTodos | Select-Object -First 5 | ForEach-Object {
            Write-Host (Apply-PSStyle -Text " - $($_.ProjectID2): $($_.Task) (Due: $(Format-DateSafeDisplay $_.DueDate))" -FG $dueSoonStyleFG)
        }
        if ($dueSoonTodos.Count -gt 5) { Write-Host (Apply-PSStyle -Text "   ... and $($dueSoonTodos.Count - 5) more." -FG $dueSoonStyleFG) }
        Write-Host ""
    }

    # --- Display Active Projects Table ---
    $sortedProjects = @() # Define scope outside if
    if ($activeProjects.Count -eq 0) {
        Show-Warning "No active projects found."
    } else {
        try { $sortedProjects = $activeProjects | Sort-Object -Property @{ Expression = { try { [datetime]::ParseExact($_.AssignedDate, $global:DATE_FORMAT_INTERNAL, $null) } catch { [datetime]::MinValue } } } -ErrorAction Stop }
        catch { Handle-Error $_ "Sorting active projects for Dashboard"; $sortedProjects = $activeProjects }

        $tableData = @()
        $rowColors = @{}
        $rowIndex = 0
        foreach ($project in $sortedProjects) {
            $rowHighlightKey = ""; $cellHighlights = @{}
            # Check Overdue status for row
            try {
                if ($project.DueDate -match '^\d{8}$') {
                    $dueDate = [datetime]::ParseExact($project.DueDate, $global:DATE_FORMAT_INTERNAL, $null)
                    if ($dueDate.Date -lt $today) { $rowHighlightKey = "Overdue" }
                    elseif (($dueDate.Date - $today).Days -lt 7) { $cellHighlights[3] = "DueSoon" } # Highlight BF Date cell (index 3 in Dashboard view)
                } else { $cellHighlights[3] = "Warning" }
            } catch { $cellHighlights[3] = "Warning" }

            # Get latest pending todo display text
            $newestPendingTaskDisplay = "---"
             if ($project.Todos -and $project.Todos -is [array] -and $project.Todos.Count -gt 0) { # Added type check
                 $newestPending = $project.Todos | Where-Object { $_.Status -eq 'Pending' -and $_.CreatedDate -match '^\d{8}$'} | Sort-Object CreatedDate -Desc | Select-Object -First 1
                 if ($newestPending) {
                     $taskText = $newestPending.Task
                     $latestTodoColWidth = ($global:tableConfig.Columns.Dashboard | Where-Object {$_.Title -eq 'Latest Todo'}).Width
                     $maxLength = [Math]::Max(5, $latestTodoColWidth - 1)
                     $newestPendingTaskDisplay = if ($taskText.Length -gt $maxLength) { $taskText.Substring(0, $maxLength - 1) + '…' } else { $taskText }
                 }
             }

            # Format row data for the "Dashboard" view
            $bfDisp = Format-DateSafeDisplay $project.BFDate
            $tableData += ,@(
                ($rowIndex + 1).ToString(), # Use row number for selection
                $project.ID2,
                $project.FullName,
                $bfDisp,
                $newestPendingTaskDisplay
            )

            # Store row/cell coloring information
            $rowColorInfo = @{}; if($rowHighlightKey){ $rowColorInfo = $rowHighlightKey }; if($cellHighlights.Count -gt 0){ if($rowColorInfo -is [string]){$rowColorInfo=@{"_ROW_KEY_"=$rowColorInfo}}; foreach($k in $cellHighlights.Keys){$rowColorInfo["_CELL_$k"]=$cellHighlights[$k]} }
            $rowColors[$rowIndex] = $rowColorInfo
            $rowIndex++
        }

        # Display the table using the "Dashboard" view type
        Format-TableUnicode -ViewType "Dashboard" -Data $tableData -RowColors $rowColors
    }

    # --- Display Actions Menu ---
    Write-Host ""
    Write-Host (Apply-PSStyle -Text "[ Dashboard Actions ]".PadRight(80) -FG $headerStyleFG -BG $headerStyleBG)
    Write-Host (Apply-PSStyle -Text " 1. View Project Details          5. Main Menu" -FG $optionStyleFG)
    Write-Host (Apply-PSStyle -Text " 2. Add New Project (Request)     Q/0. Quit" -FG $optionStyleFG) # <<< Updated Quit option
    Write-Host (Apply-PSStyle -Text " 3. Add Manual Project" -FG $optionStyleFG)
    Write-Host (Apply-PSStyle -Text " 4. View All Projects" -FG $optionStyleFG)
    Write-Host ""
    Write-Host (Apply-PSStyle -Text "(Enter project # to view details, +<MainMenuKey> for quick actions, e.g., +10)" -FG $infoStyleFG)

    $userInput = Get-InputWithPrompt "Select action or project number"

    # Handle quick actions first
    if ($userInput -match '^\+([a-zA-Z0-9]+)$') {
        $quickActionKey = $matches[1].ToLower()
        if ($global:mainMenuActionMap.ContainsKey($quickActionKey)) {
            Write-AppLog "Executing Quick Action '$quickActionKey' from Dashboard." "INFO"
            try { & $global:mainMenuActionMap[$quickActionKey] } catch { Handle-Error $_ "Executing quick action '$quickActionKey' from Dashboard" }
            return $null # Return null to redraw dashboard/menu
        } else { Show-Warning "Invalid Quick Action key: '$quickActionKey'"; Pause-Screen; return $null }
    }

    # Handle standard menu options
    switch ($userInput.ToLower()) { # Use ToLower for quit keys
        '1' { # Explicitly selecting View Details requires another selection
            if ($activeProjects.Count -gt 0) {
                # Need sorted list if available from table display above
                $listToSelectFrom = if ($sortedProjects.Count -gt 0) { $sortedProjects } else { $activeProjects }
                $selectedProject = Select-ItemFromList -Title "SELECT PROJECT TO VIEW" -Items $listToSelectFrom -ViewType "ProjectSelection" -Prompt "Select project number (0=Back)"
                if ($selectedProject) { Show-ProjectDetail -Project $selectedProject }
            } else { Show-Warning "No active projects to select."; Pause-Screen }
            return $null
        }
        '2' { New-ProjectFromRequest; return $null }
        '3' { Add-ManualProject; return $null }
        '4' { Show-ProjectList -IncludeCompleted; return $null }
        '5' { return "MainMenu" } # Signal to go to Main Menu
        # <<< MODIFICATION: Handle 'q' and '0' for Quit >>>
        '0' { return "Quit" }     # Signal to quit
        # <<< END MODIFICATION >>>
    }

    # Handle selecting project by number shown in the table
    if ($userInput -match '^\d+$' -and $activeProjects.Count -gt 0) {
        $selectionIndex = [int]$userInput - 1 # Convert display # (1-based) to array index (0-based)
        # Check against the potentially sorted list used for display
        if ($sortedProjects.Count -gt 0 -and $selectionIndex -ge 0 -and $selectionIndex -lt $sortedProjects.Count) {
            Show-ProjectDetail -Project $sortedProjects[$selectionIndex]
            return $null # Return to Dashboard after viewing detail
        }
    }

    # If input was none of the above
    Show-Warning "Invalid selection: '$userInput'"; Pause-Screen
    return $null # Default return is null to redraw Dashboard
}


function Show-ProjectDetail {
    param(
        [Parameter(Mandatory=$true)][PSCustomObject]$Project
    )
    $theme = $global:currentTheme
    $exitDetailView = $false

    # Get Common Styles Once
    $headerStyleFG = Get-PSStyleValue $theme "Menu.Header.FG" "#FFFFD7" "Foreground"
    $headerStyleBG = Get-PSStyleValue $theme "Menu.Header.BG" "#1C1C1C" "Background"
    $labelStyle = Get-PSStyleValue $theme "Palette.SecondaryFG" "#808080" "Foreground"
    $valueStyle = Get-PSStyleValue $theme "Palette.DataFG" "#FFFFFF" "Foreground"
    $optionStyle = Get-PSStyleValue $theme "Menu.Option.FG" "#00AF5F" "Foreground"
    $infoStyle = Get-PSStyleValue $theme "Palette.InfoFG" "#5Fafd7" "Foreground"
    $successStyle = Get-PSStyleValue $theme "Palette.SuccessFG" "#5FFF87" "Foreground"
    $disabledStyle = Get-PSStyleValue $theme "Palette.DisabledFG" "#626262" "Foreground"
    $warnStyle = Get-PSStyleValue $theme "Palette.WarningFG" "#FFFF00" "Foreground"
    $errorStyle = Get-PSStyleValue $theme "Palette.ErrorFG" "#FF0000" "Foreground"
    $overdueStyle = Get-PSStyleValue $theme "Palette.OverdueFG" "#FF005F" "Foreground"

    while (-not $exitDetailView) {
        # Recalculate hours each loop in case time was logged
        try { $hoursMap = Get-ProjectHoursMapByID2; $calculatedHours = if ($hoursMap.ContainsKey($Project.ID2)) { $hoursMap[$Project.ID2] } else { 0.0 } }
        catch { Handle-Error $_ "Calculating hours for Project Detail view"; $calculatedHours = 0.0 }

#        Clear-Host;
         Draw-Title "PROJECT DETAIL: $($Project.ID2)"

        # --- Project Information Section ---
        Write-Host (Apply-PSStyle -Text "[ Project Information ]".PadRight(80) -FG $headerStyleFG -BG $headerStyleBG)
        # Use simple label/value pairs with PSStyle
        Write-Host (Apply-PSStyle -Text "  Full Name: " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $Project.FullName -FG $valueStyle)
        # <<< MODIFICATION: Add ID1 and ID2 explicitly >>>
        Write-Host (Apply-PSStyle -Text "  ID1:       " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $Project.ID1 -FG $valueStyle)
        Write-Host (Apply-PSStyle -Text "  ID2:       " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $Project.ID2 -FG $valueStyle)
        # <<< END MODIFICATION >>>
        Write-Host ""
        Write-Host (Apply-PSStyle -Text "  Assigned:  " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text (Format-DateSafeDisplay $Project.AssignedDate) -FG $valueStyle)

        # Apply overdue style to Due Date if needed
        $dueDisplay = Format-DateSafeDisplay $Project.DueDate
        $dueStyle = $valueStyle # Default style
        try {
            if ($Project.DueDate -match '^\d{8}$') {
                 $dueDate = [datetime]::ParseExact($Project.DueDate, $global:DATE_FORMAT_INTERNAL, $null)
                 if ($dueDate.Date -lt (Get-Date).Date -and [string]::IsNullOrEmpty($Project.CompletedDate)) { $dueStyle = $overdueStyle }
            }
        } catch {}
        Write-Host (Apply-PSStyle -Text "  Due:       " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $dueDisplay -FG $dueStyle)

        Write-Host (Apply-PSStyle -Text "  BF Date:   " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text (Format-DateSafeDisplay $Project.BFDate) -FG $valueStyle)
        Write-Host ""
        # Apply style based on Status
        $statusText = if ([string]::IsNullOrEmpty($Project.CompletedDate)) { "Active" } else { "Completed $(Format-DateSafeDisplay $Project.CompletedDate)" }
        $statusStyle = if ([string]::IsNullOrEmpty($Project.CompletedDate)) { $successStyle } else { $disabledStyle }
        Write-Host (Apply-PSStyle -Text "  Status:    " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $statusText -FG $statusStyle)
        Write-Host (Apply-PSStyle -Text "  Hours:     " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $calculatedHours.ToString('F1') -FG $valueStyle)
        Write-Host ""

        # --- File Information Section (No Paths Displayed) ---
        Write-Host (Apply-PSStyle -Text "[ File Information ]".PadRight(80) -FG $headerStyleFG -BG $headerStyleBG)
        $folderExists = (-not [string]::IsNullOrEmpty($Project.ProjFolder)) -and (Test-Path $Project.ProjFolder -PathType Container)
        $folderStatus = if ($folderExists) { "Available" } else { "Not Found / Not Set" }
        $folderStatusStyle = if ($folderExists) { $successStyle } else { $warnStyle }
        Write-Host (Apply-PSStyle -Text "  Project Folder: " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $folderStatus -FG $folderStatusStyle)

        # Check file existence relative to folder only if folder exists
        $casDocsFolder = if ($folderExists) { Join-Path $Project.ProjFolder "__DOCS__\__CAS_DOCS__" } else { $null }
        Function Get-FileStatus { param($FileName, $DocsPath, $Label)
            $status = "Not Set" ; $style = $disabledStyle
            if (-not [string]::IsNullOrEmpty($FileName)) {
                 if ($DocsPath -and (Test-Path (Join-Path $DocsPath $FileName) -PathType Leaf)) {
                     $status = "Available"; $style = $successStyle
                 } else {
                     $status = "Not Found"; $style = $warnStyle
                 }
            }
            Write-Host (Apply-PSStyle -Text "  $($Label.PadRight(14)): " -FG $labelStyle) -NoNewline; Write-Host (Apply-PSStyle -Text $status -FG $style)
        }
        Get-FileStatus $Project.CAAName $casDocsFolder "CAA File"
        Get-FileStatus $Project.RequestName $casDocsFolder "Request File"
        Get-FileStatus $Project.T2020 $casDocsFolder "T2020 File"
        Write-Host ""


        # --- Project Todos Section ---
        Write-Host (Apply-PSStyle -Text "[ Project ToDos ($($Project.Todos.Count)) ]".PadRight(80) -FG $headerStyleFG -BG $headerStyleBG)
        if ($Project.Todos -and $Project.Todos.Count -gt 0) {
            $todoTableData = @(); $todoRowColors = @{}; $todoIdCounter = 1
            try { $sortedTodos = $Project.Todos | Sort-Object @{Expression={ $_.Status -ne 'Pending' }}, @{Expression={ try{[datetime]::ParseExact($_.DueDate, $global:DATE_FORMAT_INTERNAL, $null)}catch{[datetime]::MaxValue} }}, @{Expression={switch($_.Priority){'High'{1}'Normal'{2}'Low'{3}default{4}}}} -ErrorAction Stop }
            catch { Handle-Error $_ "Sorting Todos in Project Detail"; $sortedTodos = $Project.Todos }

            $today = (Get-Date).Date
            foreach ($todo in $sortedTodos) {
                $rowHighlightKey = ""; $cellHighlights = @{}
                if ($todo.Status -eq "Completed") {
                    $rowHighlightKey = "Completed"
                } elseif ($todo.Status -eq "Pending" -and -not [string]::IsNullOrEmpty($todo.DueDate)) {
                    try {
                        if($todo.DueDate -match '^\d{8}$') {
                            $due = [datetime]::ParseExact($todo.DueDate, $global:DATE_FORMAT_INTERNAL, $null).Date
                            if ($due -lt $today) { $rowHighlightKey = "Overdue" }
                            elseif (($due - $today).Days -lt 3) { $cellHighlights[2] = "DueSoon" } # Highlight Due Date cell (index 2)
                        } else { $cellHighlights[2] = "Warning" }
                    } catch { $cellHighlights[2] = "Warning" } # Highlight Due Date cell if invalid
                }
                # Prepare row data for ProjectTodos view
                $todoTableData += ,@( $todoIdCounter.ToString(), $todo.Task, (Format-DateSafeDisplay $todo.DueDate), $todo.Priority, $todo.Status )
                # Assign coloring info
                $rowColorInfo=@{}; if($rowHighlightKey){$rowColorInfo=$rowHighlightKey}; if($cellHighlights.Count -gt 0){ if($rowColorInfo -is [string]){$rowColorInfo=@{"_ROW_KEY_"=$rowColorInfo}}; foreach($k in $cellHighlights.Keys){$rowColorInfo["_CELL_$k"]=$cellHighlights[$k]} }; $todoRowColors[$todoIdCounter - 1] = $rowColorInfo
                $todoIdCounter++
            }
            Format-TableUnicode -ViewType "ProjectTodos" -Data $todoTableData -RowColors $todoRowColors
        } else {
            Write-Host (Apply-PSStyle -Text " (No ToDos for this project)" -FG $disabledStyle)
        }
        Write-Host ""

        # --- Actions Menu ---
        Write-Host (Apply-PSStyle -Text "[ Actions for this Project ]".PadRight(80) -FG $headerStyleFG -BG $headerStyleBG)
        Write-Host (Apply-PSStyle -Text " 1. Add ToDo                 5. Mark Project Complete" -FG $optionStyle)
        Write-Host (Apply-PSStyle -Text " 2. Update ToDo              6. Open Project Files" -FG $optionStyle)
        Write-Host (Apply-PSStyle -Text " 3. Remove ToDo              7. Edit Project Details" -FG $optionStyle)
        Write-Host (Apply-PSStyle -Text " 4. Log Time                 0. Back to Previous Menu" -FG $optionStyle) # Changed label slightly
        Write-Host ""
        Write-Host (Apply-PSStyle -Text "(Enter '+<MainMenuKey>' for quick actions)" -FG $infoStyle)

        $userInput = Get-InputWithPrompt "Select action"

        # Handle quick actions
        if ($userInput -match '^\+([a-zA-Z0-9]+)$') {
            $quickActionKey = $matches[1].ToLower()
            if ($global:mainMenuActionMap.ContainsKey($quickActionKey)) {
                Write-AppLog "Executing Quick Action '$quickActionKey' from Project Detail." "INFO"
                try { & $global:mainMenuActionMap[$quickActionKey] } catch { Handle-Error $_ "Executing quick action '$quickActionKey' from Project Detail" }
                # May need to reload project data if quick action modified it, but for now just continue loop
                continue
            } else { Show-Warning "Invalid Quick Action key: '$quickActionKey'"; Pause-Screen; continue }
        }

        # Handle standard numeric choice
        $choice = $null
        if ($userInput -match '^\d$' -and [int]$userInput -ge 0 -and [int]$userInput -le 7) { $choice = [int]$userInput }
        else { Show-Warning "Invalid selection."; Pause-Screen; continue }

        if ($choice -eq 0) { $exitDetailView = $true; continue } # Exit loop to go back

        $saveNeeded = $false # Flag to indicate if Save-ProjectTodoJson should be called
        switch ($choice) {
            1 { # Add Todo
                $addResult = Add-TodoItemToProject -ProjectObject $Project
                if ($addResult -eq $true) { $saveNeeded = $true } # Add func returns true on success
                # Add func handles its own pause/messages - continue loop will redraw
            }
            2 { # Update Todo
                if ($Project.Todos -and $Project.Todos.Count -gt 0) {
                    $todoToUpdate = Select-ItemFromList -Title "UPDATE TODO" -Items $Project.Todos -ViewType "TodoSelection" -Prompt "Select ToDo to update (0=Cancel)"
                    if ($todoToUpdate) {
                        $updateResult = Update-TodoInProject -ProjectObject $Project -TodoObject $todoToUpdate
                        if ($updateResult -eq $true) { $saveNeeded = $true } # Update func returns true if changed
                        Pause-Screen # Pause after update attempt
                    } else { Write-AppLog "Update Todo cancelled at selection." "INFO"; Show-Warning "Update cancelled."; Pause-Screen }
                } else { Show-Warning "No ToDos exist to update."; Pause-Screen }
            }
            3 { # Remove Todo
                if ($Project.Todos -and $Project.Todos.Count -gt 0) {
                    $todoToRemove = Select-ItemFromList -Title "REMOVE TODO" -Items $Project.Todos -ViewType "TodoSelection" -Prompt "Select ToDo to remove (0=Cancel)"
                    if ($todoToRemove) {
                        $removeResult = Remove-TodoFromProject -ProjectObject $Project -TodoObject $todoToRemove
                        if ($removeResult -eq $true) { $saveNeeded = $true } # Remove func returns true on success
                        # Remove func handles its own pause/messages - continue loop redraws
                    } else { Write-AppLog "Remove Todo cancelled at selection." "INFO"; Show-Warning "Remove cancelled."; Pause-Screen }
                } else { Show-Warning "No ToDos exist to remove."; Pause-Screen }
            }
            4 { # Log Time
                 # <<< MODIFICATION: Call Add-ProjectTimeInteractive WITH context >>>
                 Add-ProjectTimeInteractive -ProjectContext $Project
                 # Function now handles pause internally
            }
            5 { # Mark Project Complete
                 # <<< MODIFICATION: Call Set-ProjectComplete WITH context >>>
                 Set-ProjectComplete -ProjectContext $Project
                 # If successful, the project object in memory here might be stale. Force exit/reload.
                 $exitDetailView = $true # Exit detail view after attempting completion
            }
            6 { Open-ProjectFiles -SelectedProject $Project } # Handles its own pause
            7 { # Edit Project Details
                 # <<< MODIFICATION: Call Set-Project WITH context >>>
                 Write-AppLog "Edit Project Details selected from Detail View - calling Set-Project with context." "INFO"
                 Set-Project -ProjectContext $Project # Handles saving
                 $exitDetailView = $true # Exit detail view after editing attempt as object may have changed
            }
        } # End Switch

        # Save changes if Todo add/update/remove occurred
        if ($saveNeeded) {
            $allProjects = Load-ProjectTodoJson # Reload all projects first
            $idx = -1; for($i=0;$i -lt $allProjects.Count;$i++){if($allProjects[$i].ID2 -eq $Project.ID2){$idx=$i;break}}
            if ($idx -ge 0) {
                $allProjects[$idx] = $Project # Replace the object in the main list with our modified one
                Write-AppLog "Attempting to save Todo changes for project '$($Project.ID2)' from Detail View." "INFO"
                if (Save-ProjectTodoJson -ProjectData $allProjects) {
                    Show-Info "Todo changes saved successfully."
                    # No pause needed here as loop will redraw
                } else {
                    Show-Error "Failed to save Todo changes!"; Pause-Screen # Pause on save error
                }
            } else {
                Write-AppLog "Consistency Error saving Todo changes for project '$($Project.ID2)' from Detail View - project not found in list." "ERROR"
                Show-Error "Consistency Error saving changes. Project may be out of sync."; Pause-Screen
            }
        } # End if ($saveNeeded)

    } # End While loop
}

#endregion

 

#region Main Menu & Loop (Uses PSStyle UI Helpers)

 

# --- MODIFIED Show-MainMenu to include new option and renumber ---
function Show-MainMenu {
    # --- THIS FUNCTION NOW ONLY DISPLAYS THE MENU ---
    Clear-Host; Draw-Title "PMC" # Use the key defined in $Global:BlockyTitles
    $theme = $global:currentTheme
    # Get styles using PSStyle helpers
    $layout = Get-ThemeProperty $theme "Menu.Layout" "TwoColumn" "String"
    $headerFG = Get-PSStyleValue $theme "Menu.Header.FG" "#FFFFD7" "Foreground"
    $headerBG = Get-PSStyleValue $theme "Menu.Header.BG" "#1C1C1C" "Background"
    $headerPrefix = Get-ThemeProperty $theme "Menu.Header.Prefix" "[ " "String"
    $headerSuffix = Get-ThemeProperty $theme "Menu.Header.Suffix" " ]" "String"
    $headerFullWidth = Get-ThemeProperty $theme "Menu.Header.FullWidth" $true "Boolean"
    $optionFG = Get-PSStyleValue $theme "Menu.Option.FG" "#00AF5F" "Foreground"
    $optionBG = Get-PSStyleValue $theme "Menu.Option.BG" $null "Background"
    $numFormat = Get-ThemeProperty $theme "Menu.Option.NumFormat" "{0}." "String" # e.g., "1.", "> 1"
    $numColor = Get-PSStyleValue $theme "Menu.Option.NumColor" $optionFG "Foreground" # Color for the number part
    $indentSpaces = " " * (Get-ThemeProperty $theme "Menu.Option.Indent" 1 "Integer")
    $menuGradient = Get-ThemeProperty $theme "Menu.Option.Gradient" $null "Array" # Array of Hex colors
    $infoFG = Get-PSStyleValue $theme "Menu.Info.FG" "#808080" "Foreground"
    $infoBG = Get-PSStyleValue $theme "Menu.Info.BG" $null "Background"

    # Menu structure with updated numbering
    $menuSections = @(
        @{ Header = "Projects & Dashboard"; Options = @(
            " 1. New Project (Request)        5. Mark Project Complete",
            " 1a. Add Manual Project           6. Open Project Files",
            " 2. View Active Projects          7. Remove Project Entry",
            " 3. View All Projects             8. Dashboard", # Moved Dashboard
            " 4. Update Project Details" )},
        @{ Header = "Time Tracking"; Options = @(
            " 9. Add Project Time             11. View Time Sheet",          # Renumbered
            "10. Add Non-Project Time        12. Create Formatted Sheet"
            "25. Pomodoro Timer ")}, # Renumbered + NEW
        @{ Header = "Schedule & Calendar"; Options = @(
            "13. View Schedule               15. Calculate Future Date", # Renumbered
            "14. View 3-Month Calendar       16. View Year Calendar" )}, # Renumbered
        @{ Header = "Commands"; Options = @(
            "17. Add Snippet                 19. Search Snippets", # Renumbered
            "18. List/Manage Snippets" )}, # Renumbered
        @{ Header = "General"; Options = @(
            " C. Configure Settings          T. Change Theme",
            " H. Help                        S. Setup Routine (Placeholder)",
            "Q. Quit" )}
    )

    # Rest of the display logic (same as before, just uses the updated $menuSections)
    $totalMenuLines = ($menuSections.Options | Measure-Object -Sum {$_.Count}).Sum
    $currentLineIndex = 0
    $consoleWidth = 80; try { $consoleWidth = $Host.UI.RawUI.WindowSize.Width } catch {};

    foreach ($section in $menuSections) {
        $headerText = "$headerPrefix$($section.Header)$headerSuffix"; if ($headerFullWidth) { $headerText = $headerText.PadRight([Math]::Max($headerText.Length, $consoleWidth -1)) }; Write-Host (Apply-PSStyle -Text $headerText -FG $headerFG -BG $headerBG)
        if ($layout -eq "TwoColumn") { foreach ($optionLine in $section.Options) { $displayText = $optionLine; if ($menuGradient -and $menuGradient.Count -gt 0) { $colorIndex=[Math]::Floor(($currentLineIndex/$totalMenuLines)*$menuGradient.Count); $colorIndex=[Math]::Min($colorIndex,$menuGradient.Count-1); $lineFG=Get-PSStyleValue @{Palette=@{Temp=$menuGradient[$colorIndex]}} "Palette.Temp" $optionFG "Foreground"; $displayText=Apply-PSStyle -Text $displayText -FG $lineFG -BG $optionBG } else { $displayText=Apply-PSStyle -Text $displayText -FG $optionFG -BG $optionBG }; Write-Host ($indentSpaces + $displayText); $currentLineIndex++ } }
        else { $singleOptions = @(); foreach ($optionLine in $section.Options) { $parts = $optionLine -split '\s{2,}' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }; $singleOptions += $parts }; foreach ($option in $singleOptions) { $displayText = $option; if ($menuGradient -and $menuGradient.Count -gt 0) { $colorIndex=[Math]::Floor(($currentLineIndex/$totalMenuLines)*$menuGradient.Count); $colorIndex=[Math]::Min($colorIndex,$menuGradient.Count-1); $lineFG=Get-PSStyleValue @{Palette=@{Temp=$menuGradient[$colorIndex]}} "Palette.Temp" $optionFG "Foreground"; $displayText=Apply-PSStyle -Text $displayText -FG $lineFG -BG $optionBG } else { $displayText=Apply-PSStyle -Text $displayText -FG $optionFG -BG $optionBG }; Write-Host ($indentSpaces + $displayText); $currentLineIndex++ } }
        Write-Host ""
    }
    $themeInfoText = "Current Theme: $($global:currentTheme.Name)"; Write-Host (Apply-PSStyle -Text $themeInfoText -FG $infoFG -BG $infoBG)
}
 

function Change-Theme {

    Clear-Host; Draw-Title "CHANGE THEME"

    $theme = $global:currentTheme

    $availableThemes = $global:themes.Keys | Sort-Object

 

    # Get styles using PSStyle helpers

    $headerStyle = Get-PSStyleValue $theme "Menu.Header.FG" "#FFFFD7" "Foreground"

    $optionStyle = Get-PSStyleValue $theme "Menu.Option.FG" "#00AF5F" "Foreground"

    $warnStyle = Get-PSStyleValue $theme "Palette.WarningFG" "#FFFF00" "Foreground"

 

    Write-Host (Apply-PSStyle -Text "Available Themes:" -FG $headerStyle)

    $themeMap = @{} # Maps display number to theme key

    for ($i = 0; $i -lt $availableThemes.Count; $i++) {

        $themeName = $availableThemes[$i]

        # Get display name and optional description from theme definition

        $displayName = Get-ThemeProperty $global:themes[$themeName] "Name" $themeName "String"

        $description = Get-ThemeProperty $global:themes[$themeName] "Description" "" "String"

        $displayEntry = "$($i + 1). $displayName"

        if (-not [string]::IsNullOrEmpty($description)) { $displayEntry += " ($description)" }

 

        Write-Host (Apply-PSStyle -Text $displayEntry -FG $optionStyle)

        $themeMap[$i+1] = $themeName

    }

    Write-Host (Apply-PSStyle -Text " 0. Cancel" -FG $warnStyle)

 

    $choice = Get-NumericChoice -Prompt "Select theme number" -MinValue 0 -MaxValue $availableThemes.Count

 

    if ($choice -ne $null -and $choice -ne 0 -and $themeMap.ContainsKey($choice)) {

        $selectedThemeKey = $themeMap[$choice]

        if ($selectedThemeKey -ne $Global:AppConfig.defaultTheme) {

            $Global:AppConfig.defaultTheme = $selectedThemeKey

            $global:currentThemeName = $selectedThemeKey

            $global:currentTheme = $global:themes[$selectedThemeKey] # Update live theme object

            Write-AppLog "Theme changed to '$selectedThemeKey'. Saving config." "INFO"

            if(Save-AppConfig){ Show-Success "Theme changed to: $($global:currentTheme.Name)" }

            else { Show-Error "Theme changed in memory, but failed to save to config file." }

        } else {

            Show-Info "Theme already set to '$($global:currentTheme.Name)'."

        }

    } elseif ($choice -eq 0) {

        Show-Warning "Theme change cancelled."

    } else { # Invalid number entered

        Show-Error "Invalid theme selection number."

    }

    Pause-Screen

}

 

function Show-Help {

    Clear-Host; Draw-Title "HELP / ABOUT"

    Show-Info "Project Management Console (PSStyle Edition)"

    Show-Info "Version: V8 Enhanced + PSStyle Theming"

    Show-Info "Target: PowerShell 7.2+"

    Write-Host ""

    Show-Info "Use the menus to navigate:"

    Show-Info "- Dashboard (D): Overview of active projects and todos."

    Show-Info "- Main Menu: Access all functions."

    Show-Info "- Configure Settings (C): Change paths, theme, etc."

    Show-Info "- Quick Actions (+Key): Enter '+<MenuKey>' (e.g., +10) from Dashboard or Detail view."

    Write-Host ""

    Show-Info "Key Features:"

    Show-Info "- Project/Todo management via JSON."

    Show-Info "- Time tracking via CSV."

    Show-Info "- Command Snippet storage/retrieval."

    Show-Info "- Customizable themes using PSStyle (Hex colors)."

    Write-Host ""

    Show-Info "Data stored in: $($Global:AppConfig.projectsFile | Split-Path -Parent)"

    Pause-Screen

}

#endregion
function Get-PomodoroClockDisplay {
    param(
        [string]$TimeString,  # Format: "MM:SS"
        [string]$ForegroundColor
    )
   
    # Define digit patterns inline
    $digitPatterns = @(
        # 0
        @(
            "██████",
            "██  ██",
            "██  ██",
            "██  ██",
            "██████"
        ),
        # 1
        @(
            "    ██",
            "    ██",
            "    ██",
            "    ██",
            "    ██"
        ),
        # 2
        @(
            "██████",
            "    ██",
            "██████",
            "██    ",
            "██████"
        ),
        # 3
        @(
            "██████",
            "    ██",
            "██████",
            "    ██",
            "██████"
        ),
        # 4
        @(
            "██  ██",
            "██  ██",
            "██████",
            "    ██",
            "    ██"
        ),
        # 5
        @(
            "██████",
            "██    ",
            "██████",
            "    ██",
            "██████"
        ),
        # 6
        @(
            "██████",
            "██    ",
            "██████",
            "██  ██",
            "██████"
        ),
        # 7
        @(
            "██████",
            "    ██",
            "    ██",
            "    ██",
            "    ██"
        ),
        # 8
        @(
            "██████",
            "██  ██",
            "██████",
            "██  ██",
            "██████"
        ),
        # 9
        @(
            "██████",
            "██  ██",
            "██████",
            "    ██",
            "██████"
        )
    )
   
    # Define clear colon pattern - made more visible
    $colonPattern = @(
        "    ",
        "  ██",
        "    ",
        "  ██",
        "    "
    )
   
    # Initialize output lines
    $outputLines = @("", "", "", "", "")
   
    # Process each character in the time string
    for ($charIndex = 0; $charIndex -lt $TimeString.Length; $charIndex++) {
        $char = $TimeString[$charIndex]
       
        # Add appropriate pattern for the character
        if ($char -eq ':') {
            # Add colon pattern
            for ($i = 0; $i -lt 5; $i++) {
                $outputLines[$i] += $colonPattern[$i]
            }
        }
        elseif ($char -match '\d') {
            # Add digit pattern
            $digit = [int]::Parse($char.ToString())
            for ($i = 0; $i -lt 5; $i++) {
                $outputLines[$i] += $digitPatterns[$digit][$i]
            }
        }
       
        # Add spacing after each character (except the last one)
        if ($charIndex -lt $TimeString.Length - 1) {
            for ($i = 0; $i -lt 5; $i++) {
                $outputLines[$i] += "  "  # Add two spaces
            }
        }
    }
   
    # Return styled lines
    $styledLines = @()
    foreach ($line in $outputLines) {
        $styledLines += (Apply-PSStyle -Text $line -FG $ForegroundColor)
    }
   
    return $styledLines
}

function Update-PomodoroDisplay {
    # Update manually for testing if the timer isn't working
    if ($null -eq $script:remainingSeconds) {
        Write-AppLog "Warning: remainingSeconds not initialized in Update-PomodoroDisplay" "WARN"
        $script:remainingSeconds = 1500  # Default 25 minutes
    }
   
    $minutes = [math]::Floor($script:remainingSeconds / 60)
    $seconds = $script:remainingSeconds % 60
   
    # Updated format that should work reliably
    $timeString = $minutes.ToString("00") + ":" + $seconds.ToString("00")
   
    # Position cursor and clear display area
    [Console]::SetCursorPosition(0, 5)
    $clearHeight = 20
    1..$clearHeight | ForEach-Object {
        [Console]::SetCursorPosition(0, 4 + $_)
        Write-Host (" " * [Console]::WindowWidth)
    }
    [Console]::SetCursorPosition(0, 5)
   
    # Determine current color based on mode
    $currentFG = if ($script:isPaused) {
        $script:pausedFG
    } elseif ($script:isWorkPeriod) {
        $script:workFG
    } elseif ($script:cycle -eq 1 -and -not $script:isWorkPeriod) {
        $script:longBreakFG
    } else {
        $script:breakFG
    }
   
    # Display session info
    $modeText = if ($script:isWorkPeriod) { "WORK SESSION" } else {
        if ($script:cycle -eq 1) { "LONG BREAK" } else { "SHORT BREAK" }
    }
    $statusText = if ($script:isPaused) { "⏸️ PAUSED" } else { "▶️ RUNNING" }
   
    Write-Host ""
    Write-Host (Apply-PSStyle -Text " Mode:    $modeText " -FG $currentFG)
    Write-Host (Apply-PSStyle -Text " Cycle:   $($script:cycle)/$($script:CyclesBeforeLongBreak) " -FG $currentFG)
    Write-Host (Apply-PSStyle -Text " Status:  $statusText " -FG $currentFG)
    if ($script:ProjectID2) {
        Write-Host (Apply-PSStyle -Text " Project: $($script:ProjectID2) " -FG $currentFG)
    }
    Write-Host ""
   
    # Get clock display
    $clockLines = Get-PomodoroClockDisplay -TimeString $timeString -ForegroundColor $currentFG
   
    # Center the clock
    foreach ($line in $clockLines) {
        # Get plain text length without ANSI codes
        $plainTextLength = $line.Length - ($currentFG.Length + $PSStyle.Reset.Length)
        $leftPadding = [Math]::Max(0, [Math]::Floor(([Console]::WindowWidth - $plainTextLength) / 2))
        Write-Host (" " * $leftPadding) -NoNewline
        Write-Host $line
    }
   
    Write-Host ""
   
    # Draw progress bar
    $progressPercentage = [Math]::Max(0, [Math]::Min(100, 100 * (1 - ($script:remainingSeconds / $script:totalSeconds))))
    $progressBarWidth = 50
    $filledWidth = [Math]::Round(($progressPercentage / 100) * $progressBarWidth)
    $emptyWidth = $progressBarWidth - $filledWidth
   
    $progressBar = "["
    $progressBar += "█" * $filledWidth
    $progressBar += " " * $emptyWidth
    $progressBar += "] " + [Math]::Round($progressPercentage) + "%"
   
    # Center the progress bar
    $progressPadding = [Math]::Max(0, [Math]::Floor(([Console]::WindowWidth - $progressBar.Length) / 2))
    Write-Host (" " * $progressPadding) -NoNewline
    Write-Host (Apply-PSStyle -Text $progressBar -FG $currentFG)
   
    Write-Host ""
    Write-Host (Apply-PSStyle -Text " Space: Pause/Resume | S: Skip | Esc: Exit " -FG $currentFG)
   
    # Update the console immediately
    [Console]::Out.Flush()
}


function Start-PomodoroTimer {
    param(
        [int]$WorkMinutes = 25,
        [int]$ShortBreakMinutes = 5,
        [int]$LongBreakMinutes = 15,
        [int]$CyclesBeforeLongBreak = 4,
        [string]$ProjectID2 = "",
        [switch]$AutoLogTime = $false
    )
   
    Clear-Host
    Draw-Title "POMODORO TIMER"
   
    $theme = $global:currentTheme
   
    # Default colors
    $script:workFG = Get-PSStyleValue $theme "Palette.SuccessFG" "#5FFF87" "Foreground"
    $script:breakFG = Get-PSStyleValue $theme "Palette.InfoFG" "#5Fafd7" "Foreground"
    $script:longBreakFG = Get-PSStyleValue $theme "Palette.HighlightFG" "#00D7FF" "Foreground"
    $script:pausedFG = Get-PSStyleValue $theme "Palette.WarningFG" "#FFFF00" "Foreground"
    $script:progressFG = Get-PSStyleValue $theme "Palette.HighlightFG" "#FFFFFF" "Foreground"
    $script:borderFG = Get-PSStyleValue $theme "DataTable.BorderFG" "#FFFFFF" "Foreground"
   
    # Setup session variables
    $script:cycle = 1
    $script:sessionCount = 0
    $script:isWorkPeriod = $true
    $script:isPaused = $false
    $script:startTime = Get-Date
    $script:remainingSeconds = $WorkMinutes * 60
    $script:totalSeconds = $WorkMinutes * 60
   
    # Store parameters for later use
    $script:WorkMinutes = $WorkMinutes
    $script:ShortBreakMinutes = $ShortBreakMinutes
    $script:LongBreakMinutes = $LongBreakMinutes
    $script:CyclesBeforeLongBreak = $CyclesBeforeLongBreak
    $script:ProjectID2 = $ProjectID2
    $script:AutoLogTime = $AutoLogTime
   
    # Display initial screen
    Update-PomodoroDisplay
   
    # Make sure any previous timers are cleaned up
    Unregister-Event -SourceIdentifier PomodoroTick -ErrorAction SilentlyContinue
   
    # Create a simple loop instead of using the timer
    # This is more reliable in PowerShell and avoids complex event handling
    try {
        # Main input/timer loop
        while ($true) {
            # Check for key presses
            if ($host.UI.RawUI.KeyAvailable) {
                $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
               
                switch ($key.VirtualKeyCode) {
                    32 { # Space - Pause/Resume
                        $script:isPaused = -not $script:isPaused
                        Update-PomodoroDisplay
                    }
                    83 { # S - Skip to next session
                        $script:remainingSeconds = 1  # Will trigger completion on next iteration
                        Update-PomodoroDisplay
                    }
                    27 { # Esc - Exit
                        throw "UserExit"
                    }
                }
               
                # Clear any other pending key presses
                while ($host.UI.RawUI.KeyAvailable) {
                    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
           
            # Update timer if not paused
            if (-not $script:isPaused) {
                # Update timer every second
                Start-Sleep -Seconds 1
                $script:remainingSeconds--
               
                # Check if time's up
                if ($script:remainingSeconds -le 0) {
                    # Time's up for this period!
                   
                    # Log time if requested and this was a work period
                    if ($script:isWorkPeriod -and $script:AutoLogTime -and -not [string]::IsNullOrEmpty($script:ProjectID2)) {
                        $elapsedMinutes = [math]::Round($script:WorkMinutes, 1)
                        Add-TimeEntryCore -ID2 $script:ProjectID2 -Hours ($elapsedMinutes / 60) -DateInternal (Get-Date).ToString($global:DATE_FORMAT_INTERNAL) -Description "Pomodoro Work Session"
                    }
                   
                    # Track completed work sessions
                    if ($script:isWorkPeriod) {
                        $script:sessionCount++
                    }
                   
                    # Update cycle and period
                    if ($script:isWorkPeriod) {
                        $script:isWorkPeriod = $false
                        if ($script:cycle -ge $script:CyclesBeforeLongBreak) {
                            $script:remainingSeconds = $script:LongBreakMinutes * 60
                            $script:totalSeconds = $script:LongBreakMinutes * 60
                            $script:cycle = 1
                        } else {
                            $script:remainingSeconds = $script:ShortBreakMinutes * 60
                            $script:totalSeconds = $script:ShortBreakMinutes * 60
                            $script:cycle++
                        }
                    } else {
                        $script:isWorkPeriod = $true
                        $script:remainingSeconds = $script:WorkMinutes * 60
                        $script:totalSeconds = $script:WorkMinutes * 60
                    }
                   
                    $script:startTime = Get-Date
                }
               
                # Update the display
                Update-PomodoroDisplay
            }
            else {
                # When paused, still check for input but don't hog CPU
                Start-Sleep -Milliseconds 100
            }
        }
    }
    catch {
        if ($_.Exception.Message -ne "UserExit") {
            Handle-Error $_ "Pomodoro Timer Operation"
        }
    }
    finally {
        # Clean up
        Clear-Host
        Show-Info "Pomodoro timer ended."
        if ($script:sessionCount -gt 0) {
            Show-Success "Completed $($script:sessionCount) work session(s)."
        }
        Pause-Screen
    }
}

function Update-PomodoroDisplay {
        # Ensure these are valid integers before formatting
        $minutes = [math]::Floor($script:remainingSeconds / 60)
        $seconds = $script:remainingSeconds % 60
       
        # More defensive string formatting
        try {
            $minutesStr = $minutes.ToString("00")
            $secondsStr = $seconds.ToString("00")
            $timeString = "$minutesStr $secondsStr"
        }
        catch {
            # Fallback if formatting fails
            $timeString = "00:00"
            Write-AppLog "Error formatting time in Pomodoro display: $($_.Exception.Message)" "ERROR"
        }
       
        # Rest of the function remains the same...
   
   
    # Position cursor and clear display area
    [Console]::SetCursorPosition(0, 5)
    $clearHeight = 20
    1..$clearHeight | ForEach-Object {
        [Console]::SetCursorPosition(0, 4 + $_)
        Write-Host (" " * [Console]::WindowWidth)
    }
    [Console]::SetCursorPosition(0, 5)
   
    # Determine current color based on mode
    $currentFG = if ($script:isPaused) {
        $script:pausedFG
    } elseif ($script:isWorkPeriod) {
        $script:workFG
    } elseif ($script:cycle -eq 1 -and -not $script:isWorkPeriod) {
        $script:longBreakFG
    } else {
        $script:breakFG
    }
   
    # Display session info
    $modeText = if ($script:isWorkPeriod) { "WORK SESSION" } else {
        if ($script:cycle -eq 1) { "LONG BREAK" } else { "SHORT BREAK" }
    }
    $statusText = if ($script:isPaused) { "⏸️ PAUSED" } else { "▶️ RUNNING" }
   
    Write-Host ""
    Write-Host (Apply-PSStyle -Text " Mode:    $modeText " -FG $currentFG)
    Write-Host (Apply-PSStyle -Text " Cycle:   $($script:cycle)/$($script:CyclesBeforeLongBreak) " -FG $currentFG)
    Write-Host (Apply-PSStyle -Text " Status:  $statusText " -FG $currentFG)
    if ($script:ProjectID2) {
        Write-Host (Apply-PSStyle -Text " Project: $($script:ProjectID2) " -FG $currentFG)
    }
    Write-Host ""
   
    # Get and display clock
    $clockLines = Get-PomodoroClockDisplay -TimeString $timeString -ForegroundColor $currentFG
   
    # Center and display the clock
    $lineLength = $clockLines[0].Length - ($currentFG.Length + $PSStyle.Reset.Length) # Account for ANSI codes
    $leftPadding = [Math]::Max(0, [Math]::Floor(([Console]::WindowWidth - $lineLength) / 2))
   
    foreach ($line in $clockLines) {
        Write-Host (" " * $leftPadding) -NoNewline
        Write-Host $line
    }
   
    Write-Host ""
   
    # Draw progress bar
    $progressPercentage = [Math]::Max(0, [Math]::Min(100, 100 * (1 - ($script:remainingSeconds / $script:totalSeconds))))
    $progressBarWidth = 50
    $filledWidth = [Math]::Round(($progressPercentage / 100) * $progressBarWidth)
    $emptyWidth = $progressBarWidth - $filledWidth
   
    $progressBar = "["
    $progressBar += "█" * $filledWidth
    $progressBar += " " * $emptyWidth
    $progressBar += "] " + [Math]::Round($progressPercentage) + "%"
   
    # Center the progress bar
    $progressPadding = [Math]::Max(0, [Math]::Floor(([Console]::WindowWidth - $progressBar.Length) / 2))
    Write-Host (" " * $progressPadding) -NoNewline
    Write-Host (Apply-PSStyle -Text $progressBar -FG $currentFG)
   
    Write-Host ""
    Write-Host (Apply-PSStyle -Text " Space: Pause/Resume | S: Skip | Esc: Exit " -FG $currentFG)
}

function Start-PomodoroSession {
    Clear-Host
    Draw-Title "START POMODORO SESSION"
   
    # Determine if we should link to a project
    $linkToProject = Confirm-ActionNumeric -ActionDescription "Link this Pomodoro session to a project for time tracking?"
   
    $projectID2 = ""
    if ($linkToProject -eq $true) {
        $allProjects = Load-ProjectTodoJson
        $activeProjects = @($allProjects | Where-Object { [string]::IsNullOrEmpty($_.CompletedDate) })
       
        if ($activeProjects.Count -eq 0) {
            Show-Warning "No active projects found. Continuing without project link."
        } else {
            $selectedProject = Select-ItemFromList -Title "SELECT PROJECT" -Items $activeProjects -ViewType "ProjectSelection" -Prompt "Select project (0=Skip)"
            if ($selectedProject) {
                $projectID2 = $selectedProject.ID2
                Show-Success "Session will be linked to project: $projectID2"
            }
        }
    }
   
    # Get custom timer settings
    Show-Info "Configure your Pomodoro session (press Enter to accept defaults)"
   
    $workMin = 25
    $workMinInput = Get-InputWithPrompt "Work period minutes" $workMin
    if ($workMinInput -match '^\d+$') { $workMin = [int]$workMinInput }
   
    $shortBreakMin = 5
    $shortBreakInput = Get-InputWithPrompt "Short break minutes" $shortBreakMin
    if ($shortBreakInput -match '^\d+$') { $shortBreakMin = [int]$shortBreakInput }
   
    $longBreakMin = 15
    $longBreakInput = Get-InputWithPrompt "Long break minutes" $longBreakMin
    if ($longBreakInput -match '^\d+$') { $longBreakMin = [int]$longBreakInput }
   
    $cycles = 4
    $cyclesInput = Get-InputWithPrompt "Cycles before long break" $cycles
    if ($cyclesInput -match '^\d+$') { $cycles = [int]$cyclesInput }
   
    # Check for task selection if linked to project
    $taskDescription = ""
    if ($projectID2 -ne "") {
        # You could add todo task selection here if desired
       
        $autoLog = Confirm-ActionNumeric -ActionDescription "Automatically log time to project when work sessions complete?"
        if ($autoLog -ne $true) {
            $projectID2 = ""  # Clear project ID if not auto logging
        }
    }
   
    # Start the timer
    Start-PomodoroTimer -WorkMinutes $workMin -ShortBreakMinutes $shortBreakMin -LongBreakMinutes $longBreakMin `
                       -CyclesBeforeLongBreak $cycles -ProjectID2 $projectID2 -AutoLogTime ($projectID2 -ne "")
}



 

 

#region Trogdor (Uses PSStyle UI Helpers)

$trogdorAnsiArt = @"

            /\____/\

           /  ` `` `\   TROGDOR!

          | ^ /  \ ^ |  /

          \  `----'  /--<

           \  `--'  /         BURNiNATING the PEASANTS

            |   /\   |          /

   _______|  /  \  |_______ /

  /-------\ |    | /-------/

/         \|____|/         \

\___________________________/

    \ ~~~ /      \ ~~~ /

     -----        -----

"@

function Show-Trogdor {

    param([switch]$WithMessage, [string]$CustomMessage = "BURNINATING THE COUNTRYSIDE!")

    Clear-Host

    $theme = $global:currentTheme

    # Get styles using PSStyle helpers, with fallbacks

    $titleFg = Get-PSStyleValue $theme "Palette.ErrorFG" "#FF0000" "Foreground"

    $titleBg = Get-PSStyleValue $theme "Palette.ErrorBG" $null "Background"

    $borderFg = Get-PSStyleValue $theme "Palette.WarningFG" "#FFFF00" "Foreground"

    $artFg = Get-PSStyleValue $theme "Palette.SuccessFG" "#5FFF87" "Foreground" # Green for Trogdor

    $messageFg = Get-PSStyleValue $theme "Palette.OverdueFG" "#FF005F" "Foreground" # Burninating message color

 

    $title = "TROGDOR THE BURNINATOR"

    $borderChar = "§" # Burninating character

 

    $width = 80; try { $width = $Host.UI.RawUI.WindowSize.Width - 1 } catch {}; if ($width -lt 10) { $width = 80 }

 

    # Draw Border and Title

    $borderLine = $borderChar * $width

    Write-Host ""

    Write-Host (Apply-PSStyle -Text $borderLine -FG $borderFg)

    $centeredTitle = " $($title.ToUpper()) "

    # Basic centering without complex padding measurement - CORRECTED LINE

    $titleLine = $centeredTitle.PadLeft( [Math]::Max(0, [Math]::Floor(($width + $centeredTitle.Length) / 2))).PadRight($width)

    Write-Host (Apply-PSStyle -Text $titleLine -FG $titleFg -BG $titleBg)

    Write-Host (Apply-PSStyle -Text $borderLine -FG $borderFg)

    Write-Host ""

 

    # Display ANSI Art with styling

    $trogdorAnsiArt.Split("`n") | ForEach-Object { Write-Host (Apply-PSStyle -Text $_ -FG $artFg) }

 

    # Display Message if requested

    if ($WithMessage) {

        Write-Host ""

        $message = $CustomMessage.ToUpper()

        # Basic centering for message - CORRECTED LINE

        $messageLine = $message.PadLeft( [Math]::Max(0, [Math]::Floor(($width + $message.Length) / 2))).PadRight($width)

        Write-Host (Apply-PSStyle -Text $messageLine -FG $messageFg)

    }

    Write-Host ""

    Pause-Screen "Trogdor was here... Press Enter to resume non-burninating activities..."

}

#endregion

 

 

#region Main Application Loop

function Start-ProjectManagement {

    try {

        # --- Load Themes from Files FIRST ---

        # This populates the $Global:themes hashtable

        Load-ThemesFromFiles # <<< CRITICAL: Call this first

 

        # --- Ensure at least one theme exists for fallback ---

        if ($Global:themes.Count -eq 0) {

            Write-AppLog "No themes found or loaded. Creating minimal fallback theme." "WARN"

            # Define the minimal fallback theme (as provided in the original code)

            $Global:themes['FallbackMinimal'] = @{

                Name = "Fallback (Minimal)"

                Palette = @{ PrimaryFG='#C0C0C0'; SecondaryFG='#808080'; AccentFG='#FFFF00'; Border='#FFFFFF'; HeaderFG='#FFFF00'; HeaderBG=$null; DataFG='#C0C0C0'; DataBG=$null; InputPrompt='#00FFFF'; InputDefault='#808080'; UserInput='#FFFFFF'; SuccessFG='#00FF00'; SuccessBG=$null; ErrorFG='#FF0000'; ErrorBG=$null; WarningFG='#FFFF00'; WarningBG=$null; InfoFG='#00BFFF'; InfoBG=$null; DisabledFG='#808080'; HighlightFG='#000000'; HighlightBG='#FFFFFF'; DueSoonFG='#FFFF00'; OverdueFG='#FF0000'; CompletedFG='#808080'; SchedCurrentWkFG = '#00FF00'; SchedNextWkFG = '#FFFF00'; }

                WindowTitle=@{FG='$Palette:HeaderFG'; Border=@{Style='ASCII'; FG='$Palette:Border'}; LinesAbove=1; LinesBelow=1; Pad=1; TextCase="Uppercase"}

                Menu=@{ Layout='TwoColumn'; Header=@{FG='$Palette:HeaderFG'; Prefix="[ "; Suffix=" ]"; FullWidth=$true}; Option=@{FG='$Palette:PrimaryFG'; NumColor='$Palette:AccentFG'; Indent=1}; Info=@{FG='$Palette:InfoFG'} }

                DataTable=@{ BorderStyle='ASCII'; BorderFG='$Palette:Border'; Pad=1; Header=@{FG='$Palette:HeaderFG'; Separator=$true}; DataRow=@{FG='$Palette:DataFG'}; AltRow=@{FG='$Palette:DataFG'}; Highlight=@{ Overdue=@{FG='$Palette:OverdueFG'}; DueSoon=@{FG='$Palette:DueSoonFG'}; Completed=@{FG='$Palette:CompletedFG'}; Selected=@{FG='$Palette:HighlightFG'; BG='$Palette:HighlightBG'}; SchedCurrent=@{FG='$Palette:SchedCurrentWkFG'}; SchedNext=@{FG='$Palette:SchedNextWkFG'}; Warning=@{FG='$Palette:WarningFG'} } }

                InputControl=@{ Prompt=@{FG='$Palette:InputPrompt'}; Default=@{FG='$Palette:InputDefault'}; UserInput=@{FG='$Palette:UserInput'} }

                StatusMessage=@{ Types=@{ Success=@{FG='$Palette:SuccessFG'; Prefix="[OK] "}; Error=@{FG='$Palette:ErrorFG'; Prefix="[ERROR] "}; Warning=@{FG='$Palette:WarningFG'; Prefix="[WARN] "}; Info=@{FG='$Palette:InfoFG'; Prefix="[INFO] "} } }

            }

            Write-AppLog "Created minimal fallback theme 'FallbackMinimal' as no themes were loaded." "WARN"

        }

 

        # --- Load Application Configuration ---

        # This function will now use the $Global:themes populated above

        Load-AppConfig # <<< CRITICAL: Call this AFTER loading themes

 

        # --- Check if Config Loaded Successfully ---

        if ($null -eq $Global:AppAppConfig -and $Global:AppConfig.Keys.Count -eq 0) {

            Write-Error "FATAL: Application configuration could not be loaded after attempting. Exiting."

            Read-Host "Press Enter."

            return # Exit the Start-ProjectManagement function

        }

 

        # --- Initialization Continues (Logging, Data Dirs, etc.) ---

        Write-AppLog "--- Application Started (v8 Enhanced - PSStyle Edition) ---" "INFO"

        Write-AppLog "PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"

        Write-AppLog "Theme Set: $($global:currentThemeName) ($($global:currentTheme.Name))" "INFO"

 

        if (-not (Initialize-DataDirectory)) {

             Show-Warning "Initialization checks failed. Some features might not work correctly."

             Pause-Screen

        }

 

    } catch {

        # Catch errors during the initial theme/config load phase

        Write-Error "FATAL ERROR during initialization phase: $($_.Exception.Message)"

        Write-Error "Stack Trace: $($_.ScriptStackTrace)"

        Read-Host "Press Enter to exit."

        return # Exit the Start-ProjectManagement function

    }

 

    # Set Initial View (after successful init)

    $currentView = "Dashboard"

 

    # --- Main Loop Logic ---

    while ($true) {

        $nextView = $null # Reset next view determination

        try {

            switch ($currentView) {

                "Dashboard" {

                     $nextView = Show-Dashboard # Returns "MainMenu", "Quit", or null

                }

               
                "MainMenu" {
                    # Step 1: Display the menu (function now only displays)
                    Show-MainMenu

                    # Step 2: Get user input HERE
                    $infoFG = Get-PSStyleValue $global:currentTheme "Menu.Info.FG" "#808080" "Foreground" # Get info color
                    Write-Host (Apply-PSStyle -Text "(Enter option Key, or +<Key> for quick action)" -FG $infoFG) # Display prompt hint
                    $userInput = Get-InputWithPrompt "Enter selection" # Use standard prompt

                    # Step 3: Process the input HERE
                    if ($userInput -match '^\+([a-zA-Z0-9]+)$') {
                        # Handle Quick Action (+Key)
                        $quickActionKey = $matches[1].ToLower()
                        if ($global:mainMenuActionMap.ContainsKey($quickActionKey)) {
                            Write-AppLog "Executing Quick Action '$quickActionKey' from Main Menu." "INFO"
                            try {
                                # Invoke the action
                                $actionResult = & $global:mainMenuActionMap[$quickActionKey]
                                # Determine next view based on result
                                if ($actionResult -in @("Dashboard", "MainMenu", "Quit")) { $nextView = $actionResult }
                                else { $nextView = "MainMenu" } # Default back to main menu
                            } catch {
                                Handle-Error $_ "Executing quick action '$quickActionKey'"
                                $nextView = "MainMenu" # Go back to main menu on error
                            }
                        } else {
                            # Invalid quick action key
                            Show-Warning "Invalid Quick Action key: '$quickActionKey'"; Pause-Screen
                            $nextView = "MainMenu"
                        }
                    }
                    else {
                        # Handle Standard Selection (Key)
                        $selectedKey = $userInput.ToLower()
                        if ($global:mainMenuActionMap.ContainsKey($selectedKey)) {
                            try {
                                Write-AppLog "Executing Main Menu action '$selectedKey'" "INFO"
                                # DEBUG: dump the 11‐map so we know exactly what code we're invoking
                                if ($selectedKey -eq '11') {
                                    Write-Host "=== SCRIPTBLOCK FOR '11' START ==="
                                    Write-Host ($global:mainMenuActionMap['11'].ToString())
                                    Write-Host "=== SCRIPTBLOCK FOR '11' END ==="
                                }
                               
                                # Invoke the action
                                $actionResult = & $global:mainMenuActionMap[$selectedKey]
                                # Determine next view based on result
                                if ($actionResult -in @("Dashboard", "MainMenu", "Quit")) { $nextView = $actionResult }
                                else { $nextView = "MainMenu" } # Default back to main menu
                            } catch {
                                Handle-Error $_ "Executing Main Menu action '$selectedKey'"
                                $nextView = "MainMenu" # Go back to main menu on error
                            }
                        } else {
                            # Invalid standard selection
                            Show-Warning "Invalid selection: '$userInput'"; Pause-Screen
                            $nextView = "MainMenu"
                        }
                    }
                } # End MainMenu Case
# --- End of replacement block ---
     

                "Quit" {

                    break # Exit the While loop

                }

                default {

                    Write-AppLog "Invalid view state encountered: '$currentView'. Returning to Dashboard." "ERROR"

                    Show-Error "An unexpected error occurred (Invalid View State)."

                    Pause-Screen

                    $nextView = "Dashboard"

                }

            } # End Switch ($currentView)

        } catch {

            Handle-Error $_ "Main Application Loop (Current View: '$currentView')"

            Show-Error "A critical unexpected error occurred. Returning to Dashboard."

            Pause-Screen

            $nextView = "Dashboard" # Attempt recovery

        }

 

        # Transition to the next view state

        $currentView = $nextView

 

        # Safety check

        if ($null -eq $currentView -or $currentView -notin @("Dashboard", "MainMenu", "Quit")) {

             Write-AppLog "Detected invalid next view state ('$currentView'). Resetting to Dashboard." "ERROR"

             $currentView = "Dashboard"

        }

    } # End While Loop

 

    # --- Cleanup / Exit Message ---

    Write-AppLog "--- Application Exited Gracefully ---" "INFO"

    Clear-Host

    $theme = $global:currentTheme

    $exitFG = Get-PSStyleValue $theme "WindowTitle.FG" "#FFFFFF" "Foreground"

    $exitBG = Get-PSStyleValue $theme "WindowTitle.BG" $null "Background"

    Write-Host (Apply-PSStyle -Text "Exiting Project Management System. Goodbye!" -FG $exitFG -BG $exitBG)

    Write-Host $PSStyle.Reset # Ensure terminal is reset

}

#endregion

 

# --- Script Entry Point ---

# Ensure BlockyTitles are defined before calling Start-ProjectManagement if Draw-Title uses them

$Global:BlockyTitles = @{

    'PMC' = @"

██████╗ ███╗   ███╗ ██████╗

██╔══██╗████╗ ████║██╔════╝

██████╔╝██╔████╔██║██║

██╔═══╝ ██║╚██╔╝██║██║

██║     ██║ ╚═╝ ██║╚██████╗

╚═╝     ╚═╝     ╚═╝ ╚═════╝

"@

    # Add other blocky titles here if needed

# Add this to the global block art definitions
# Add these to the existing $Global:BlockyTitles hashtable
# These should be placed where the BlockyTitles hash is defined, near the end of the script

# Add digits to the existing BlockyTitles hashtable






    'TROGDOR THE BURNINATOR' = $trogdorAnsiArt # Reuse Trogdor art

}

Start-ProjectManagement

 

# --- END OF CORRECTED FILE ---

