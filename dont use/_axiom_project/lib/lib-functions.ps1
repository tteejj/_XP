function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Component,
        
        [Parameter(Mandatory)]
        [string]$Context,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )
    
    try {
        return & $ScriptBlock
    }
    catch {
        Write-Log -Level Error -Message "$Context failed: $_" -Component $Component
        throw
    }
}

function _Identify-HeliosComponent {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    try {
        $scriptName = $ErrorRecord.InvocationInfo.ScriptName ?? (Get-PSCallStack | Where-Object ScriptName | Select-Object -First 1).ScriptName
        if (-not $scriptName) { return "Interactive/Unknown" }

        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($scriptName)

        $componentMap = @{
            'tui-engine' = 'TUI Engine'; 'navigation' = 'Navigation Service'; 'keybindings' = 'Keybinding Service'
            'task-service' = 'Task Service'; 'helios-components' = 'Helios UI Components'; 'helios-panels' = 'Helios UI Panels'
            'dashboard-screen' = 'Dashboard Screen'; 'task-screen' = 'Task Screen'; 'exceptions' = 'Exception Module'
            'logger' = 'Logger Module'; 'Start-PMCTerminal' = 'Application Entry'
        }

        foreach ($pattern in $componentMap.Keys) {
            if ($fileName -like "*$pattern*") { return $componentMap[$pattern] }
        }
        return "Unknown ($fileName)"
    } catch { return "Component Identification Failed" }
}

function _Get-DetailedError {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [hashtable]$AdditionalContext = @{}
    )
    try {
        $errorInfo = [PSCustomObject]@{
            Timestamp = Get-Date -Format "o"; Summary = $ErrorRecord.Exception.Message; Type = $ErrorRecord.Exception.GetType().FullName
            Category = $ErrorRecord.CategoryInfo.Category.ToString(); TargetObject = $ErrorRecord.TargetObject
            ScriptName = $ErrorRecord.InvocationInfo.ScriptName; LineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber
            Line = $ErrorRecord.InvocationInfo.Line; PositionMessage = $ErrorRecord.InvocationInfo.PositionMessage
            StackTrace = $ErrorRecord.Exception.StackTrace; InnerExceptions = @(); AdditionalContext = $AdditionalContext
            SystemContext = @{
                ProcessId = $PID; ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                PowerShellVersion = $PSVersionTable.PSVersion.ToString(); OS = $PSVersionTable.OS
            }
        }

        $innerEx = $ErrorRecord.Exception.InnerException
        while ($innerEx) {
            $errorInfo.InnerExceptions += [PSCustomObject]@{ Message = $innerEx.Message; Type = $innerEx.GetType().FullName; StackTrace = $innerEx.StackTrace }
            $innerEx = $innerEx.InnerException
        }
        return $errorInfo
    } catch {
        return [PSCustomObject]@{ Timestamp = Get-Date -Format "o"; Summary = "CRITICAL: Error analysis failed."; OriginalError = $ErrorRecord.Exception.Message; AnalysisError = $_.Exception.Message; Type = "ErrorAnalysisFailure" }
    }
}

function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Component,
        [Parameter(Mandatory)] [string]$Context,
        [Parameter(Mandatory)] [scriptblock]$ScriptBlock,
        [hashtable]$AdditionalData = @{}
    )

    if (-not $ScriptBlock) { throw "Invoke-WithErrorHandling: ScriptBlock parameter cannot be null." }
    $Component = [string]::IsNullOrWhiteSpace($Component) ? "Unknown Component" : $Component
    $Context = [string]::IsNullOrWhiteSpace($Context) ? "Unknown Operation" : $Context

    try {
        return (& $ScriptBlock)
    }
    catch {
        $originalErrorRecord = $_
        $identifiedComponent = _Identify-HeliosComponent -ErrorRecord $originalErrorRecord
        $finalComponent = ($Component -ne "Unknown Component") ? $Component : $identifiedComponent

        $errorContext = @{ Operation = $Context }
        $AdditionalData.GetEnumerator() | ForEach-Object { $errorContext[$_.Name] = $_.Value }
        $detailedError = _Get-DetailedError -ErrorRecord $originalErrorRecord -AdditionalContext $errorContext

        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "Error in '$finalComponent' during '$Context': $($originalErrorRecord.Exception.Message)" -Data $detailedError
        }

        [void]$script:ErrorHistory.Add($detailedError)
        if ($script:ErrorHistory.Count -gt $script:MaxErrorHistory) { $script:ErrorHistory.RemoveAt(0) }

        $contextHashtable = @{
            Operation = $Context; Timestamp = $detailedError.Timestamp; LineNumber = $detailedError.LineNumber
            ScriptName = $detailedError.ScriptName ?? "Unknown"
        }
        
        foreach ($key in $AdditionalData.Keys) {
            $value = $AdditionalData[$key]
            if ($value -is [string] -or $value -is [int] -or $value -is [bool] -or $value -is [datetime]) { $contextHashtable[$key] = $value }
        }
        
        $heliosException = New-Object Helios.HeliosException($originalErrorRecord.Exception.Message, $finalComponent, $contextHashtable, $originalErrorRecord.Exception)
        throw $heliosException
    }
}

ValidateNotEmpty([string]$value, [string]$parameterName) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw [System.ArgumentException]::new("Parameter '$($parameterName)' cannot be null or empty.")
        }
    }

PmcTask() {}

PmcTask([string]$title) { [ValidationBase]::ValidateNotEmpty($title, "Title"); $this.Title = $title }

PmcTask([string]$title, [string]$description, [TaskPriority]$priority, [string]$projectKey) {
        [ValidationBase]::ValidateNotEmpty($title, "Title")
        $this.Title = $title; $this.Description = $description; $this.Priority = $priority
        $this.ProjectKey = $projectKey; $this.Category = $projectKey
    }

Complete() {
        $this.Status = [TaskStatus]::Completed; $this.Completed = $true
        $this.Progress = 100; $this.UpdatedAt = [datetime]::Now
    }

UpdateProgress([int]$newProgress) {
        if ($newProgress -lt 0 -or $newProgress -gt 100) { throw "Progress must be between 0 and 100." }
        $this.Progress = $newProgress
        $this.Status = $newProgress -eq 100 ? [TaskStatus]::Completed : $newProgress -gt 0 ? [TaskStatus]::InProgress : [TaskStatus]::Pending
        $this.Completed = ($this.Status -eq [TaskStatus]::Completed)
        $this.UpdatedAt = [datetime]::Now
    }

GetDueDateString() { return $this.DueDate ? $this.DueDate.Value.ToString("yyyy-MM-dd") : "N/A" }

ToLegacyFormat() {
        return @{
            id = $this.Id; title = $this.Title; description = $this.Description
            completed = $this.Completed; priority = $this.Priority.ToString().ToLower()
            project = $this.ProjectKey; due_date = $this.DueDate ? $this.GetDueDateString() : $null
            created_at = $this.CreatedAt.ToString("o"); updated_at = $this.UpdatedAt.ToString("o")
        }
    }

FromLegacyFormat([hashtable]$legacyData) {
        $task = [PmcTask]::new()
        $task.Id = $legacyData.id ?? $task.Id
        $task.Title = $legacyData.title
        $task.Description = $legacyData.description
        if ($legacyData.priority) { try { $task.Priority = [TaskPriority]::$($legacyData.priority) } catch {} }
        $task.ProjectKey = $legacyData.project ?? $legacyData.Category ?? "General"
        $task.Category = $task.ProjectKey
        if ($legacyData.created_at) { try { $task.CreatedAt = [datetime]::Parse($legacyData.created_at) } catch {} }
        if ($legacyData.updated_at) { try { $task.UpdatedAt = [datetime]::Parse($legacyData.updated_at) } catch {} }
        if ($legacyData.due_date -and $legacyData.due_date -ne "N/A") { try { $task.DueDate = [datetime]::Parse($legacyData.due_date) } catch {} }
        if ($legacyData.completed -is [bool] -and $legacyData.completed) { $task.Complete() }
        return $task
    }

PmcProject() {}

PmcProject([string]$key, [string]$name) {
        [ValidationBase]::ValidateNotEmpty($key, "Key"); [ValidationBase]::ValidateNotEmpty($name, "Name")
        $this.Key = $key; $this.Name = $name
    }

ToLegacyFormat() {
        return @{
            Key = $this.Key; Name = $this.Name; Client = $this.Client
            BillingType = $this.BillingType.ToString(); Rate = $this.Rate; Budget = $this.Budget
            Active = $this.Active; CreatedAt = $this.CreatedAt.ToString("o")
        }
    }

FromLegacyFormat([hashtable]$legacyData) {
        $project = [PmcProject]::new()
        $project.Key = $legacyData.Key ?? $project.Key
        $project.Name = $legacyData.Name
        $project.Client = $legacyData.Client
        if ($legacyData.Rate) { $project.Rate = [double]$legacyData.Rate }
        if ($legacyData.Budget) { $project.Budget = [double]$legacyData.Budget }
        if ($legacyData.Active -is [bool]) { $project.Active = $legacyData.Active }
        if ($legacyData.BillingType) { try { $project.BillingType = [BillingType]::$($legacyData.BillingType) } catch {} }
        if ($legacyData.CreatedAt) { try { $project.CreatedAt = [datetime]::Parse($legacyData.CreatedAt) } catch {} }
        $project.UpdatedAt = $project.CreatedAt
        return $project
    }

GetForegroundCode([ConsoleColor]$color) {
        return [TuiAnsiHelper]::ColorMap[$color.ToString()]
    }

GetBackgroundCode([ConsoleColor]$color) {
        return [TuiAnsiHelper]::ColorMap[$color.ToString()] + 10
    }

Reset() {
        return "`e[0m"
    }

Bold() {
        return "`e[1m"
    }

Underline() {
        return "`e[4m"
    }

Italic() {
        return "`e[3m"
    }

TuiCell() {
        $this.Char = ' '
        $this.ForegroundColor = [ConsoleColor]::White
        $this.BackgroundColor = [ConsoleColor]::Black
    }

TuiCell([char]$char) {
        $this.Char = $char
        $this.ForegroundColor = [ConsoleColor]::White
        $this.BackgroundColor = [ConsoleColor]::Black
    }

TuiCell([char]$char, [ConsoleColor]$fg, [ConsoleColor]$bg) {
        $this.Char = $char
        $this.ForegroundColor = $fg
        $this.BackgroundColor = $bg
    }

TuiCell([char]$char, [ConsoleColor]$fg, [ConsoleColor]$bg, [bool]$bold, [bool]$underline) {
        $this.Char = $char
        $this.ForegroundColor = $fg
        $this.BackgroundColor = $bg
        $this.Bold = $bold
        $this.Underline = $underline
    }

TuiCell([TuiCell]$other) {
        if ($null -ne $other) {
            $this.Char = $other.Char
            $this.ForegroundColor = $other.ForegroundColor
            $this.BackgroundColor = $other.BackgroundColor
            $this.Bold = $other.Bold
            $this.Underline = $other.Underline
            $this.Italic = $other.Italic
            $this.StyleFlags = $other.StyleFlags
            $this.ZIndex = $other.ZIndex
            $this.Metadata = $other.Metadata
        }
    }

WithStyle([ConsoleColor]$fg, [ConsoleColor]$bg) {
        $copy = [TuiCell]::new($this)
        $copy.ForegroundColor = $fg
        $copy.BackgroundColor = $bg
        return $copy
    }

WithChar([char]$char) {
        $copy = [TuiCell]::new($this)
        $copy.Char = $char
        return $copy
    }

BlendWith([TuiCell]$other) {
        if ($null -eq $other) { return $this }
        if ($other.ZIndex -gt $this.ZIndex) { return $other }
        if ($other.ZIndex -eq $this.ZIndex -and $other.Char -ne ' ') { return $other }
        return $this
    }

DiffersFrom([TuiCell]$other) {
        if ($null -eq $other) { return $true }
        return ($this.Char -ne $other.Char -or 
                $this.ForegroundColor -ne $other.ForegroundColor -or 
                $this.BackgroundColor -ne $other.BackgroundColor -or
                $this.Bold -ne $other.Bold -or
                $this.Underline -ne $other.Underline -or
                $this.Italic -ne $other.Italic)
    }

ToAnsiString() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Color codes - This now works because TuiAnsiHelper is known to the parser.
        $fgCode = [TuiAnsiHelper]::GetForegroundCode($this.ForegroundColor)
        $bgCode = [TuiAnsiHelper]::GetBackgroundCode($this.BackgroundColor)
        [void]$sb.Append("`e[${fgCode};${bgCode}")
        
        # Style codes
        if ($this.Bold) { [void]$sb.Append(";1") }
        if ($this.Underline) { [void]$sb.Append(";4") }
        if ($this.Italic) { [void]$sb.Append(";3") }
        
        [void]$sb.Append("m").Append($this.Char)
        return $sb.ToString()
    }

ToLegacyFormat() {
        return @{
            Char = $this.Char
            FG = $this.ForegroundColor
            BG = $this.BackgroundColor
        }
    }

ToString() {
        return "TuiCell($($this.Char), $($this.ForegroundColor), $($this.BackgroundColor))"
    }

TuiBuffer([int]$width, [int]$height, [string]$name = "Unnamed") {
        if ($width -le 0 -or $height -le 0) {
            throw [ArgumentException]::new("Buffer dimensions must be positive")
        }
        
        $this.Width = $width
        $this.Height = $height
        $this.Name = $name
        $this.Cells = New-Object 'TuiCell[,]' $height, $width
        $this.Clear()
    }

Clear() {
        $this.Clear([TuiCell]::new())
    }

Clear([TuiCell]$fillCell) {
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.Cells[$y, $x] = [TuiCell]::new($fillCell)
            }
        }
        $this.IsDirty = $true
    }

GetCell([int]$x, [int]$y) {
        if ($x -lt 0 -or $x -ge $this.Width -or $y -lt 0 -or $y -ge $this.Height) {
            return [TuiCell]::new()  # Return empty cell for out-of-bounds
        }
        return $this.Cells[$y, $x]
    }

SetCell([int]$x, [int]$y, [TuiCell]$cell) {
        if ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height -and $null -ne $cell) {
            $this.Cells[$y, $x] = $cell
            $this.IsDirty = $true
        }
    }

WriteString([int]$x, [int]$y, [string]$text, [ConsoleColor]$fg, [ConsoleColor]$bg) {
        if ([string]::IsNullOrEmpty($text) -or $y -lt 0 -or $y -ge $this.Height) {
            return
        }

        $currentX = $x
        foreach ($char in $text.ToCharArray()) {
            if ($currentX -ge $this.Width) { break }
            if ($currentX -ge 0) {
                $this.SetCell($currentX, $y, [TuiCell]::new($char, $fg, $bg))
            }
            $currentX++
        }
    }

BlendBuffer([TuiBuffer]$other, [int]$offsetX, [int]$offsetY) {
        if ($null -eq $other) { return }

        for ($y = 0; $y -lt $other.Height; $y++) {
            for ($x = 0; $x -lt $other.Width; $x++) {
                $targetX = $offsetX + $x
                $targetY = $offsetY + $y
                
                if ($targetX -ge 0 -and $targetX -lt $this.Width -and $targetY -ge 0 -and $targetY -lt $this.Height) {
                    $sourceCell = $other.GetCell($x, $y)
                    $targetCell = $this.GetCell($targetX, $targetY)
                    $blendedCell = $targetCell.BlendWith($sourceCell)
                    $this.SetCell($targetX, $targetY, $blendedCell)
                }
            }
        }
    }

GetSubBuffer([int]$x, [int]$y, [int]$width, [int]$height) {
        $subBuffer = [TuiBuffer]::new($width, $height, "$($this.Name).Sub")
        
        for ($sy = 0; $sy -lt $height; $sy++) {
            for ($sx = 0; $sx -lt $width; $sx++) {
                $sourceCell = $this.GetCell($x + $sx, $y + $sy)
                $subBuffer.SetCell($sx, $sy, [TuiCell]::new($sourceCell))
            }
        }
        
        return $subBuffer
    }

Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0 -or $newHeight -le 0) {
            throw [ArgumentException]::new("Buffer dimensions must be positive")
        }

        $oldCells = $this.Cells
        $oldWidth = $this.Width
        $oldHeight = $this.Height

        $this.Width = $newWidth
        $this.Height = $newHeight
        $this.Cells = New-Object 'TuiCell[,]' $newHeight, $newWidth
        $this.Clear()

        # Copy existing content
        $copyWidth = [Math]::Min($oldWidth, $newWidth)
        $copyHeight = [Math]::Min($oldHeight, $newHeight)

        for ($y = 0; $y -lt $copyHeight; $y++) {
            for ($x = 0; $x -lt $copyWidth; $x++) {
                $this.Cells[$y, $x] = $oldCells[$y, $x]
            }
        }

        $this.IsDirty = $true
    }

function Initialize-EventSystem {
    <# .SYNOPSIS Initializes the event system for the application #>
    Invoke-WithErrorHandling -Component "EventSystem.Initialize" -Context "Initializing event system" -ScriptBlock {
        $script:EventHandlers = @{}
        $script:EventHistory = [System.Collections.Generic.List[object]]::new()
        Write-Verbose "Event system initialized"
    }
}

function Publish-Event {
    <#
    .SYNOPSIS Publishes an event to all registered handlers
    .PARAMETER EventName The name of the event to publish
    .PARAMETER Data Optional data to pass to event handlers
    #>
    param(
        [Parameter(Mandatory)] [string]$EventName,
        [Parameter()] [hashtable]$Data = @{}
    )
    Invoke-WithErrorHandling -Component "EventSystem.PublishEvent" -Context "Publishing event '$EventName'" -ScriptBlock {
        $eventRecord = @{ EventName = $EventName; Data = $Data; Timestamp = Get-Date }
        
        $script:EventHistory.Add($eventRecord)
        if ($script:EventHistory.Count -gt $script:MaxEventHistory) { $script:EventHistory.RemoveAt(0) }
        
        if ($script:EventHandlers.ContainsKey($EventName)) {
            foreach ($handler in $script:EventHandlers[$EventName]) {
                try {
                    $eventData = @{ EventName = $EventName; Data = $Data; Timestamp = $eventRecord.Timestamp }
                    & $handler.ScriptBlock -EventData $eventData
                } catch {
                    Write-Log -Level Warning -Message "Error in event handler for '$EventName' (ID: $($handler.HandlerId)): $_"
                }
            }
        }
        Write-Verbose "Published event: $EventName"
    } -AdditionalData @{ EventName = $EventName; EventData = $Data }
}

function Subscribe-Event {
    <#
    .SYNOPSIS Subscribes to an event with a handler
    .PARAMETER EventName The name of the event to subscribe to
    .PARAMETER Handler The script block to execute
    .PARAMETER HandlerId Optional unique identifier for the handler
    .PARAMETER Source Optional source component ID for cleanup tracking
    #>
    param(
        [Parameter(Mandatory)] [string]$EventName,
        [Parameter(Mandatory)] [scriptblock]$Handler,
        [Parameter()] [string]$HandlerId = [Guid]::NewGuid().ToString(),
        [Parameter()] [string]$Source
    )
    return Invoke-WithErrorHandling -Component "EventSystem.SubscribeEvent" -Context "Subscribing to event '$EventName'" -ScriptBlock {
        if (-not $script:EventHandlers.ContainsKey($EventName)) { $script:EventHandlers[$EventName] = @() }
        
        $handlerInfo = @{ HandlerId = $HandlerId; ScriptBlock = $Handler; SubscribedAt = Get-Date; Source = $Source }
        $script:EventHandlers[$EventName] += $handlerInfo
        
        Write-Verbose "Subscribed to event: $EventName (Handler: $HandlerId)"
        return $HandlerId
    } -AdditionalData @{ EventName = $EventName; HandlerId = $HandlerId; Source = $Source }
}

function Unsubscribe-Event {
    <#
    .SYNOPSIS Unsubscribes from an event
    .PARAMETER EventName The name of the event (optional if HandlerId is provided)
    .PARAMETER HandlerId The unique identifier of the handler to remove
    #>
    param(
        [Parameter()] [string]$EventName,
        [Parameter(Mandatory)] [string]$HandlerId
    )
    Invoke-WithErrorHandling -Component "EventSystem.UnsubscribeEvent" -Context "Unsubscribing from event '$EventName' (Handler: $HandlerId)" -ScriptBlock {
        if ($EventName) {
            if ($script:EventHandlers.ContainsKey($EventName)) {
                $script:EventHandlers[$EventName] = @($script:EventHandlers[$EventName] | Where-Object { $_.HandlerId -ne $HandlerId })
                if ($script:EventHandlers[$EventName].Count -eq 0) { $script:EventHandlers.Remove($EventName) }
                Write-Verbose "Unsubscribed from event: $EventName (Handler: $HandlerId)"
            }
        } else {
            $found = $false
            foreach ($eventKey in @($script:EventHandlers.Keys)) {
                $handlers = $script:EventHandlers[$eventKey]
                $newHandlers = @($handlers | Where-Object { $_.HandlerId -ne $HandlerId })
                if ($newHandlers.Count -lt $handlers.Count) {
                    $found = $true
                    $script:EventHandlers[$eventKey] = if ($newHandlers.Count -eq 0) { $script:EventHandlers.Remove($eventKey) } else { $newHandlers }
                    Write-Verbose "Unsubscribed from event: $eventKey (Handler: $HandlerId)"; break
                }
            }
            if (-not $found) { Write-Warning "Handler ID not found: $HandlerId" }
        }
    } -AdditionalData @{ EventName = $EventName; HandlerId = $HandlerId }
}

function Clear-EventHandlers {
    <# .SYNOPSIS Clears all event handlers for a specific event or all events #>
    param([Parameter()] [string]$EventName)
    Invoke-WithErrorHandling -Component "EventSystem.ClearEventHandlers" -Context "Clearing event handlers for '$EventName'" -ScriptBlock {
        if ($EventName) { if ($script:EventHandlers.ContainsKey($EventName)) { $script:EventHandlers.Remove($EventName); Write-Verbose "Cleared handlers for event: $EventName" } } 
        else { $script:EventHandlers = @{}; Write-Verbose "Cleared all event handlers" }
    }
}

function Initialize-ThemeManager {
    Invoke-WithErrorHandling -Component "ThemeManager.Initialize" -Context "Initializing theme service" -ScriptBlock {
        Set-TuiTheme -ThemeName "Modern"
        Write-Log -Level Info -Message "Theme manager initialized."
    }
}

function Export-TuiTheme {
    param([Parameter(Mandatory)] [string]$ThemeName, [Parameter(Mandatory)] [string]$Path)
    Invoke-WithErrorHandling -Component "ThemeManager.ExportTheme" -Context "Exporting theme to JSON" -AdditionalData @{ ThemeName = $ThemeName; FilePath = $Path } -ScriptBlock {
        if ($script:Themes.ContainsKey($ThemeName)) {
            $theme = $script:Themes[$ThemeName]
            $exportTheme = @{ Name = $theme.Name; Colors = @{} }
            foreach ($colorKey in $theme.Colors.Keys) { $exportTheme.Colors[$colorKey] = $theme.Colors[$colorKey].ToString() }
            $exportTheme | ConvertTo-Json -Depth 3 | Set-Content -Path $Path
            Write-Log -Level Info -Message "Exported theme '$ThemeName' to: $Path"
        } else {
            Write-Log -Level Warning -Message "Cannot export theme. Theme not found: $ThemeName"
        }
    }
}

function Import-TuiTheme {
    param([Parameter(Mandatory)] [string]$Path)
    Invoke-WithErrorHandling -Component "ThemeManager.ImportTheme" -Context "Importing theme from JSON" -AdditionalData @{ FilePath = $Path } -ScriptBlock {
        if (Test-Path $Path) {
            $importedTheme = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
            $theme = @{ Name = $importedTheme.Name; Colors = @{} }
            foreach ($colorKey in $importedTheme.Colors.Keys) {
                $theme.Colors[$colorKey] = [System.Enum]::Parse([System.ConsoleColor], $importedTheme.Colors[$colorKey], $true)
            }
            $script:Themes[$theme.Name] = $theme
            Write-Log -Level Info -Message "Imported theme: $($theme.Name)"
            return $theme
        } else {
            Write-Log -Level Warning -Message "Cannot import theme. File not found: $Path"
            return $null
        }
    }
}

UIElement() {
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this.{_private_buffer} = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
    }

UIElement([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [ArgumentException]::new("UIElement name cannot be null or empty.")
        }
        $this.Name = $name
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this.{_private_buffer} = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
    }

UIElement([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this.{_private_buffer} = [TuiBuffer]::new($width, $height, "$($this.Name).Buffer")
    }

GetAbsolutePosition() {
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

AddChild([UIElement]$child) {
        if ($null -ne $child) {
            $child.Parent = $this
            $this.Children.Add($child)
            $this.RequestRedraw()
        }
    }

RemoveChild([UIElement]$child) {
        if ($null -ne $child) {
            $child.Parent = $null
            [void]$this.Children.Remove($child)
            $this.RequestRedraw()
        }
    }

RequestRedraw() {
        $this.{_needs_redraw} = $true
        if ($null -ne $this.Parent) {
            $this.Parent.RequestRedraw()
        }
    }

Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0 -or $newHeight -le 0) { return }
        
        $this.Width = $newWidth
        $this.Height = $newHeight
        
        if ($null -ne $this.{_private_buffer}) {
            $this.{_private_buffer}.Resize($newWidth, $newHeight)
        }
        
        $this.RequestRedraw()
        $this.OnResize($newWidth, $newHeight)
    }

Move([int]$newX, [int]$newY) {
        $this.X = $newX
        $this.Y = $newY
        $this.RequestRedraw()
        $this.OnMove($newX, $newY)
    }

ContainsPoint([int]$x, [int]$y) {
        return ($x -ge $this.X -and $x -lt ($this.X + $this.Width) -and 
                $y -ge $this.Y -and $y -lt ($this.Y + $this.Height))
    }

GetChildAtPoint([int]$x, [int]$y) {
        for ($i = $this.Children.Count - 1; $i -ge 0; $i--) {
            $child = $this.Children[$i]
            if ($child.Visible -and $child.ContainsPoint($x - $this.X, $y - $this.Y)) {
                return $child
            }
        }
        return $null
    }

OnRender() {
        # Default implementation - clear buffer
        if ($null -ne $this.{_private_buffer}) {
            $this.{_private_buffer}.Clear()
        }
    }

OnResize([int]$newWidth, [int]$newHeight) {
        # Override in subclasses
    }

OnMove([int]$newX, [int]$newY) {
        # Override in subclasses
    }

OnFocus() {
        # Override in subclasses
    }

OnBlur() {
        # Override in subclasses
    }

HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Override in subclasses - return true if input was handled
        return $false
    }

Render() {
        Invoke-WithErrorHandling -Component $this.Name -Context "Render" -ScriptBlock {
            if (-not $this.Visible) { return }
            $this._RenderContent()
        } -AdditionalData @{ ComponentType = $this.GetType().Name }
    }

_RenderContent() {
        if (-not $this.Visible) { return }

        # Render this component to its private buffer
        if ($this.{_needs_redraw} -or ($null -eq $this.{_private_buffer})) {
            if ($null -eq $this.{_private_buffer}) {
                $this.{_private_buffer} = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
            }
            
            $this.OnRender()
            $this.{_needs_redraw} = $false
        }

        # Render children to their buffers, then composite onto parent
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $child.Render()
                
                # Composite child's buffer onto this component's buffer
                if ($null -ne $child.{_private_buffer}) {
                    $this.{_private_buffer}.BlendBuffer($child.{_private_buffer}, $child.X, $child.Y)
                }
            }
        }
    }

GetBuffer() {
        return $this.{_private_buffer}
    }

ToString() {
        return "$($this.GetType().Name): $($this.Name)"
    }

Component([string]$name) : base($name) {
    }

_RenderContent() {
        # Call parent implementation for buffer management
        ([UIElement]$this)._RenderContent()
    }

Screen([string]$name, [hashtable]$services) : base($name) {
        if (-not $services) { throw [ArgumentNullException]::new("services") }
        
        $this.Services = $services
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
    }

Initialize() { }

OnEnter() { }

OnExit() { }

OnResume() { }

HandleInput([System.ConsoleKeyInfo]$key) { }

Cleanup() {
        foreach ($kvp in $this.EventSubscriptions.GetEnumerator()) {
            try {
                Unsubscribe-Event -EventName $kvp.Key -SubscriberId $kvp.Value
            }
            catch {
                Write-Log -Level Warning -Message "Failed to unregister event '$($kvp.Key)' for screen '$($this.Name)'."
            }
        }
        $this.EventSubscriptions.Clear()
        $this.Panels.Clear()
        Write-Log -Level Debug -Message "Cleaned up screen: $($this.Name)"
    }

AddPanel([UIElement]$panel) {
        if (-not $panel) { throw [ArgumentNullException]::new("panel") }
        $this.Panels.Add($panel)
    }

SubscribeToEvent([string]$eventName, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($eventName)) { throw [ArgumentException]::new("Event name cannot be null or empty.") }
        if (-not $action) { throw [ArgumentNullException]::new("action") }
        
        # AI: Fixed parameter name from -Action to -Handler to match event-system.psm1 function signature
        $subscriptionId = Subscribe-Event -EventName $eventName -Handler $action -Source $this.Name
        $this.EventSubscriptions[$eventName] = $subscriptionId
    }

_RenderContent() {
        # Call base implementation for buffer management
        ([UIElement]$this)._RenderContent()
        
        # Render all panels in the screen to the back-buffer
        foreach ($panel in $this.Panels) {
            if ($panel.Visible) {
                $panel.Render()
            }
        }
    }

Panel() : base() {
        $this.Name = "Panel"
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
    }

Panel([int]$x, [int]$y, [int]$width, [int]$height) : base($x, $y, $width, $height) {
        $this.Name = "Panel"
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
    }

Panel([int]$x, [int]$y, [int]$width, [int]$height, [string]$title) : base($x, $y, $width, $height) {
        $this.Name = "Panel"
        $this.Title = $title
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
    }

UpdateContentBounds() {
        if ($this.HasBorder) {
            $this.ContentX = 1
            $this.ContentY = 1
            $this.ContentWidth = [Math]::Max(0, $this.Width - 2)
            $this.ContentHeight = [Math]::Max(0, $this.Height - 2)
        } else {
            $this.ContentX = 0
            $this.ContentY = 0
            $this.ContentWidth = $this.Width
            $this.ContentHeight = $this.Height
        }
    }

OnResize([int]$newWidth, [int]$newHeight) {
        $this.UpdateContentBounds()
        $this.PerformLayout()
    }

PerformLayout() {
        if ($this.Children.Count -eq 0) { return }

        switch ($this.LayoutType) {
            "Vertical" { $this.LayoutVertical() }
            "Horizontal" { $this.LayoutHorizontal() }
            "Grid" { $this.LayoutGrid() }
            # "Manual" - no automatic layout
        }
    }

LayoutVertical() {
        $currentY = $this.ContentY
        $childWidth = $this.ContentWidth
        $availableHeight = $this.ContentHeight
        $childHeight = [Math]::Max(1, [Math]::Floor($availableHeight / $this.Children.Count))

        for ($i = 0; $i -lt $this.Children.Count; $i++) {
            $child = $this.Children[$i]
            $child.X = $this.ContentX
            $child.Y = $currentY
            
            if ($i -eq ($this.Children.Count - 1)) {
                $remainingHeight = $this.ContentY + $this.ContentHeight - $currentY
                $child.Resize($childWidth, $remainingHeight)
            } else {
                $child.Resize($childWidth, $childHeight)
            }
            
            $currentY += $childHeight
        }
    }

LayoutHorizontal() {
        $currentX = $this.ContentX
        $childHeight = $this.ContentHeight
        $availableWidth = $this.ContentWidth
        $childWidth = [Math]::Max(1, [Math]::Floor($availableWidth / $this.Children.Count))

        for ($i = 0; $i -lt $this.Children.Count; $i++) {
            $child = $this.Children[$i]
            $child.X = $currentX
            $child.Y = $this.ContentY
            
            if ($i -eq ($this.Children.Count - 1)) {
                $remainingWidth = $this.ContentX + $this.ContentWidth - $currentX
                $child.Resize($remainingWidth, $childHeight)
            } else {
                $child.Resize($childWidth, $childHeight)
            }
            
            $currentX += $childWidth
        }
    }

LayoutGrid() {
        if ($this.Children.Count -eq 0) { return }

        $childCount = $this.Children.Count
        $cols = [Math]::Ceiling([Math]::Sqrt($childCount))
        $rows = [Math]::Ceiling($childCount / $cols)
        
        $cellWidth = [Math]::Max(1, [Math]::Floor($this.ContentWidth / $cols))
        $cellHeight = [Math]::Max(1, [Math]::Floor($this.ContentHeight / $rows))

        for ($i = 0; $i -lt $this.Children.Count; $i++) {
            $child = $this.Children[$i]
            $row = [Math]::Floor($i / $cols)
            $col = $i % $cols
            
            $x = $this.ContentX + ($col * $cellWidth)
            $y = $this.ContentY + ($row * $cellHeight)
            
            $width = if ($col -eq ($cols - 1)) { $this.ContentX + $this.ContentWidth - $x } else { $cellWidth }
            $height = if ($row -eq ($rows - 1)) { $this.ContentY + $this.ContentHeight - $y } else { $cellHeight }
            
            $child.Move($x, $y)
            $child.Resize($width, $height)
        }
    }

SetBorderStyle([string]$style, [ConsoleColor]$color) {
        $this.BorderStyle = $style
        $this.BorderColor = $color
        $this.RequestRedraw()
    }

SetBorder([bool]$hasBorder) {
        $this.HasBorder = $hasBorder
        $this.UpdateContentBounds()
        $this.PerformLayout()
        $this.RequestRedraw()
    }

SetTitle([string]$title) {
        $this.Title = $title
        $this.RequestRedraw()
    }

ContainsContentPoint([int]$x, [int]$y) {
        return ($x -ge $this.ContentX -and $x -lt ($this.ContentX + $this.ContentWidth) -and 
                $y -ge $this.ContentY -and $y -lt ($this.ContentY + $this.ContentHeight))
    }

GetContentBounds() {
        return @{ X = $this.ContentX; Y = $this.ContentY; Width = $this.ContentWidth; Height = $this.ContentHeight }
    }

GetContentArea() {
        return $this.GetContentBounds()
    }

WriteToBuffer([int]$x, [int]$y, [string]$text, [ConsoleColor]$fg, [ConsoleColor]$bg) {
        if ($null -eq $this.{_private_buffer}) { return }
        Write-TuiText -Buffer $this.{_private_buffer} -X $x -Y $y -Text $text -ForegroundColor $fg -BackgroundColor $bg
    }

DrawBoxToBuffer([int]$x, [int]$y, [int]$width, [int]$height, [ConsoleColor]$borderColor, [ConsoleColor]$bgColor) {
        if ($null -eq $this.{_private_buffer}) { return }
        Write-TuiBox -Buffer $this.{_private_buffer} -X $x -Y $y -Width $width -Height $height `
            -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
    }

ClearContent() {
        if ($null -eq $this.{_private_buffer}) { return }
        $clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor)
        for ($y = $this.ContentY; $y -lt ($this.ContentY + $this.ContentHeight); $y++) {
            for ($x = $this.ContentX; $x -lt ($this.ContentX + $this.ContentWidth); $x++) {
                $this.{_private_buffer}.SetCell($x, $y, $clearCell)
            }
        }
    }

OnRender() {
        if ($null -eq $this.{_private_buffer}) { return }
        $bgCell = [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor)
        $this.{_private_buffer}.Clear($bgCell)
        if ($this.HasBorder) {
            Write-TuiBox -Buffer $this.{_private_buffer} -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle $this.BorderStyle -BorderColor $this.BorderColor -BackgroundColor $this.BackgroundColor -Title $this.Title
        }
    }

_RenderContent() {
        $this.OnRender()
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $child.Render()
                if ($null -ne $child.{_private_buffer}) {
                    $this.{_private_buffer}.BlendBuffer($child.{_private_buffer}, ($child.X + $this.ContentX), ($child.Y + $this.ContentY))
                }
            }
        }
    }

OnFocus() {
        if ($this.CanFocus) {
            $this.BorderColor = [ConsoleColor]::Cyan
            $this.RequestRedraw()
        }
    }

OnBlur() {
        if ($this.CanFocus) {
            $this.BorderColor = [ConsoleColor]::Gray
            $this.RequestRedraw()
        }
    }

GetFirstFocusableChild() {
        foreach ($child in $this.Children) {
            if ($child.IsFocusable -and $child.Visible -and $child.Enabled) {
                return $child
            }
            if ($child -is [Panel]) {
                $nestedChild = $child.GetFirstFocusableChild()
                if ($null -ne $nestedChild) {
                    return $nestedChild
                }
            }
        }
        return $null
    }

GetFocusableChildren() {
        $focusable = [System.Collections.Generic.List[UIElement]]::new()
        foreach ($child in $this.Children) {
            if ($child.IsFocusable -and $child.Visible -and $child.Enabled) {
                $focusable.Add($child)
            }
            if ($child -is [Panel]) {
                $nestedFocusable = $child.GetFocusableChildren()
                $focusable.AddRange($nestedFocusable)
            }
        }
        return $focusable
    }

HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($this.CanFocus -and $this.IsFocused) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Tab) {
                    $firstChild = $this.GetFirstFocusableChild()
                    if ($null -ne $firstChild) {
                        $firstChild.IsFocused = $true
                        $this.IsFocused = $false
                        return $true
                    }
                }
                ([ConsoleKey]::Enter) {
                    $firstChild = $this.GetFirstFocusableChild()
                    if ($null -ne $firstChild) {
                        $firstChild.IsFocused = $true
                        $this.IsFocused = $false
                        return $true
                    }
                }
            }
        }
        foreach ($child in $this.Children) {
            if ($child.Visible -and $child.Enabled -and $child.HandleInput($keyInfo)) {
                return $true
            }
        }
        return $false
    }

ToString() {
        return "Panel($($this.Name), $($this.X),$($this.Y), $($this.Width)x$($this.Height), Children=$($this.Children.Count))"
    }

ScrollablePanel() : base() {
        $this.Name = "ScrollablePanel"
        $this.IsFocusable = $true
        $this.CanFocus = $true
    }

ScrollablePanel([int]$x, [int]$y, [int]$width, [int]$height) : base($x, $y, $width, $height) {
        $this.Name = "ScrollablePanel"
        $this.IsFocusable = $true
        $this.CanFocus = $true
    }

SetVirtualSize([int]$width, [int]$height) {
        $this.VirtualWidth = $width
        $this.VirtualHeight = $height
        if ($width -gt 0 -and $height -gt 0) {
            $this.{_virtual_buffer} = [TuiBuffer]::new($width, $height, "$($this.Name).Virtual")
        }
        $this.RequestRedraw()
    }

ScrollTo([int]$x, [int]$y) {
        $maxScrollX = [Math]::Max(0, $this.VirtualWidth - $this.ContentWidth)
        $maxScrollY = [Math]::Max(0, $this.VirtualHeight - $this.ContentHeight)
        $this.ScrollX = [Math]::Max(0, [Math]::Min($x, $maxScrollX))
        $this.ScrollY = [Math]::Max(0, [Math]::Min($y, $maxScrollY))
        $this.RequestRedraw()
    }

ScrollBy([int]$deltaX, [int]$deltaY) {
        $this.ScrollTo($this.ScrollX + $deltaX, $this.ScrollY + $deltaY)
    }

HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($this.IsFocused) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) { $this.ScrollBy(0, -1); return $true }
                ([ConsoleKey]::DownArrow) { $this.ScrollBy(0, 1); return $true }
                ([ConsoleKey]::LeftArrow) { $this.ScrollBy(-1, 0); return $true }
                ([ConsoleKey]::RightArrow) { $this.ScrollBy(1, 0); return $true }
                ([ConsoleKey]::PageUp) { $this.ScrollBy(0, -$this.ContentHeight); return $true }
                ([ConsoleKey]::PageDown) { $this.ScrollBy(0, $this.ContentHeight); return $true }
                ([ConsoleKey]::Home) { $this.ScrollTo(0, 0); return $true }
                ([ConsoleKey]::End) { $this.ScrollTo(0, $this.VirtualHeight); return $true }
            }
        }
        return ([Panel]$this).HandleInput($keyInfo)
    }

OnRender() {
        ([Panel]$this).OnRender()
        if ($null -ne $this.{_virtual_buffer}) {
            $visibleBuffer = $this.{_virtual_buffer}.GetSubBuffer($this.ScrollX, $this.ScrollY, $this.ContentWidth, $this.ContentHeight)
            $this.{_private_buffer}.BlendBuffer($visibleBuffer, $this.ContentX, $this.ContentY)
        }
        if ($this.ShowScrollbars -and $this.HasBorder) {
            $this.DrawScrollbars()
        }
    }

DrawScrollbars() {
        if ($null -eq $this.{_private_buffer}) { return }
        if ($this.VirtualHeight -gt $this.ContentHeight) {
            $scrollbarX = $this.Width - 1
            $scrollbarHeight = $this.Height - 2
            $thumbPosition = [Math]::Floor(($this.ScrollY / [Math]::Max(1, $this.VirtualHeight - $this.ContentHeight)) * ($scrollbarHeight - 1))
            for ($y = 1; $y -lt ($this.Height - 1); $y++) {
                $char = if ($y -eq ($thumbPosition + 1)) { '█' } else { '▒' }
                $cell = [TuiCell]::new($char, [ConsoleColor]::Gray, $this.BackgroundColor)
                $this.{_private_buffer}.SetCell($scrollbarX, $y, $cell)
            }
        }
        if ($this.VirtualWidth -gt $this.ContentWidth) {
            $scrollbarY = $this.Height - 1
            $scrollbarWidth = $this.Width - 2
            $thumbPosition = [Math]::Floor(($this.ScrollX / [Math]::Max(1, $this.VirtualWidth - $this.ContentWidth)) * ($scrollbarWidth - 1))
            for ($x = 1; $x -lt ($this.Width - 1); $x++) {
                $char = if ($x -eq ($thumbPosition + 1)) { '█' } else { '▒' }
                $cell = [TuiCell]::new($char, [ConsoleColor]::Gray, $this.BackgroundColor)
                $this.{_private_buffer}.SetCell($x, $scrollbarY, $cell)
            }
        }
    }

GetVirtualBuffer() {
        return $this.{_virtual_buffer}
    }

GroupPanel() : base() {
        $this.Name = "GroupPanel"
        $this.IsFocusable = $true
        $this.CanFocus = $true
        $this.ExpandedHeight = $this.Height
    }

GroupPanel([int]$x, [int]$y, [int]$width, [int]$height, [string]$title) : base($x, $y, $width, $height, $title) {
        $this.Name = "GroupPanel"
        $this.IsFocusable = $true
        $this.CanFocus = $true
        $this.ExpandedHeight = $height
    }

ToggleCollapsed() {
        $this.IsCollapsed = -not $this.IsCollapsed
        if ($this.IsCollapsed) {
            $this.ExpandedHeight = $this.Height
            $this.Resize($this.Width, $this.HeaderHeight + 2)
        } else {
            $this.Resize($this.Width, $this.ExpandedHeight)
        }
        foreach ($child in $this.Children) {
            $child.Visible = -not $this.IsCollapsed
        }
        $this.RequestRedraw()
    }

HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($this.IsFocused) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Enter) { $this.ToggleCollapsed(); return $true }
                ([ConsoleKey]::Spacebar) { $this.ToggleCollapsed(); return $true }
            }
        }
        if (-not $this.IsCollapsed) {
            return ([Panel]$this).HandleInput($keyInfo)
        }
        return $false
    }

OnRender() {
        ([Panel]$this).OnRender()
        if ($this.HasBorder -and -not [string]::IsNullOrEmpty($this.Title)) {
            $indicator = if ($this.IsCollapsed) { $this.ExpandChar } else { $this.CollapseChar }
            $indicatorCell = [TuiCell]::new($indicator, $this.TitleColor, $this.BackgroundColor)
            $this.{_private_buffer}.SetCell(2, 0, $indicatorCell)
        }
    }

NavigationItem([string]$key, [string]$label, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($key))   { throw [ArgumentException]::new("Navigation key cannot be null or empty") }
        if ([string]::IsNullOrWhiteSpace($label)) { throw [ArgumentException]::new("Navigation label cannot be null or empty") }
        if ($null -eq $action)                    { throw [ArgumentNullException]::new("action", "Navigation action cannot be null") }
        
        $this.Key = $key.ToUpper()
        $this.Label = $label
        $this.Action = $action
    }

Execute() {
        if (-not $this.Enabled) {
            Write-Log -Level Warning -Message "Attempted to execute disabled navigation item: $($this.Key)"
            return
        }
        
        try {
            Write-Log -Level Debug -Message "Executing navigation item: $($this.Key) - $($this.Label)"
            & $this.Action
        }
        catch {
            Write-Log -Level Error -Message "Navigation action failed for item '$($this.Key)': $_"
            throw
        }
    }

FormatDisplay([bool]$showDescription = $false) {
        $display = "[$($this.Key)] "
        
        if ($this.Enabled) {
            $display += $this.Label
        }
        else {
            $display += "$($this.Label) (Disabled)"
        }
        
        if ($showDescription -and -not [string]::IsNullOrWhiteSpace($this.Description)) {
            $display += " - $($this.Description)"
        }
        
        return $display
    }

NavigationMenu([string]$name) : base() {
        $this.Name = $name
        $this.Items = [System.Collections.Generic.List[NavigationItem]]::new()
        $this.IsFocusable = $true
        $this.SelectedIndex = 0
        $this.Width = 30
        $this.Height = 10
    }

NavigationMenu([string]$name, [hashtable]$services) : base() {
        if ($null -eq $services) { throw [ArgumentNullException]::new("services") }
        $this.Name = $name
        $this.Services = $services
        $this.Items = [System.Collections.Generic.List[NavigationItem]]::new()
        $this.IsFocusable = $true
        $this.SelectedIndex = 0
        $this.Width = 30
        $this.Height = 10
    }

AddItem([NavigationItem]$item) {
        if (-not $item) { throw [ArgumentNullException]::new("item") }
        if ($this.Items.Exists({param($x) $x.Key -eq $item.Key})) { 
            throw [InvalidOperationException]::new("Item with key '$($item.Key)' already exists") 
        }
        $this.Items.Add($item)
        $this.RequestRedraw()
    }

RemoveItem([string]$key) {
        $item = $this.GetItem($key)
        if ($item) { 
            [void]$this.Items.Remove($item)
            $this.RequestRedraw()
        }
    }

GetItem([string]$key) {
        return $this.Items.Find({param($x) $x.Key -eq $key.ToUpper()})
    }

ExecuteAction([string]$key) {
        $item = $this.GetItem($key)
        if ($item -and $item.Visible) {
            Invoke-WithErrorHandling -Component "NavigationMenu" -Context "ExecuteAction:$key" -ScriptBlock { 
                $item.Execute() 
            }
        }
    }

AddSeparator() {
        $separatorItem = [NavigationItem]::new("-", "---", {})
        $separatorItem.Enabled = $false
        $this.Items.Add($separatorItem)
        $this.RequestRedraw()
    }

OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear our buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            # Get visible items
            $visibleItems = @($this.Items | Where-Object { $null -ne $_ -and $_.Visible })
            if ($visibleItems.Count -eq 0) { return }
            
            if ($this.Orientation -eq "Horizontal") { 
                $this.RenderHorizontal($visibleItems) 
            }
            else { 
                $this.RenderVertical($visibleItems) 
            }
            
        } catch { 
            Write-Log -Level Error -Message "NavigationMenu render error for '$($this.Name)': $_" 
        }
    }

RenderHorizontal([object[]]$items) {
        if ($null -eq $items -or $items.Count -eq 0) { return }
        
        $menuText = ""
        $isFirst = $true
        foreach ($item in $items) {
            if ($null -eq $item) { continue }
            
            if (-not $isFirst) {
                $menuText += $this.Separator
            }
            $menuText += "[$($item.Key)] $($item.Label)"
            $isFirst = $false
        }
        
        # Write to our private buffer
        $this._private_buffer.WriteString(0, 0, $menuText, [ConsoleColor]::White, [ConsoleColor]::Black)
    }

RenderVertical([object[]]$items) {
        if ($null -eq $items -or $items.Count -eq 0) { return }
        
        # Ensure SelectedIndex is within bounds
        if ($this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $items.Count) {
            $this.SelectedIndex = 0
        }
        
                for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            if ($null -eq $item) { continue }

            $isItemSelected = ($i -eq $this.SelectedIndex -and $this.IsFocused)
            
            $prefix = if ($isItemSelected -and $item.Key -ne "-") { "> " } else { "  " }
            $menuText = "$prefix[$($item.Key)] $($item.Label)"

            $fg = if ($isItemSelected -and $item.Key -ne "-") { [ConsoleColor]::Black } else { [ConsoleColor]::White }
            $bg = if ($isItemSelected -and $item.Key -ne "-") { [ConsoleColor]::White } else { [ConsoleColor]::Black }

            # Explicitly paint the entire line with the correct background color first
            $this._private_buffer.WriteString(0, $i, (' ' * $this.Width), $fg, $bg)
            # Then, write the actual text on top
            $this._private_buffer.WriteString(0, $i, $menuText, $fg, $bg)
        }
    }

HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        try {
            $visibleItems = @($this.Items | Where-Object { $null -ne $_ -and $_.Visible })
            if ($visibleItems.Count -eq 0) { return $false }
            
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.SelectedIndex -lt ($visibleItems.Count - 1)) {
                        $this.SelectedIndex++
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $visibleItems.Count) {
                        $selectedItem = $visibleItems[$this.SelectedIndex]
                        if ($selectedItem.Enabled -and $selectedItem.Key -ne "-") {
                            $selectedItem.Execute()
                        }
                    }
                    return $true
                }
                default {
                    # Check for direct key matches
                    $keyChar = $keyInfo.KeyChar.ToString().ToUpper()
                    $matchingItem = $this.Items.Find({param($x) $x.Key -eq $keyChar})
                    if ($matchingItem -and $matchingItem.Enabled -and $matchingItem.Visible) {
                        $matchingItem.Execute()
                        return $true
                    }
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "NavigationMenu input error for '$($this.Name)': $_" 
        }
        
        return $false
    }

OnFocus() {
        $this.IsFocused = $true
        $this.RequestRedraw()
    }

OnBlur() {
        $this.IsFocused = $false
        $this.RequestRedraw()
    }

LabelComponent([string]$name) : base($name) {
        $this.IsFocusable = $false
        $this.Width = 10
        $this.Height = 1
    }

OnRender() {
        # AI: REFACTORED - Renders to its own private buffer.
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = $this.ForegroundColor ?? [ConsoleColor]::White
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $this.Text -ForegroundColor $fg

        } catch { 
            Write-Log -Level Error -Message "Label render error for '$($this.Name)': $_" 
        }
    }

HandleInput([System.ConsoleKeyInfo]$key) {
        return $false # Labels don't handle input
    }

ButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 10
        $this.Height = 3
        $this.Text = "Button"
    }

OnRender() {
        # AI: REFACTORED - Renders to its own private buffer, not the parent's.
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))

            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            $bgColor = $this.IsPressed ? [ConsoleColor]::Yellow : [ConsoleColor]::Black
            $fgColor = $this.IsPressed ? [ConsoleColor]::Black : $borderColor
            
            # Render border to own buffer
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
            
            # Render text centered in own buffer
            $textX = [Math]::Floor(($this.Width - $this.Text.Length) / 2)
            $textY = [Math]::Floor(($this.Height - 1) / 2)
            Write-TuiText -Buffer $this._private_buffer -X $textX -Y $textY -Text $this.Text -ForegroundColor $fgColor -BackgroundColor $bgColor

        } catch { 
            Write-Log -Level Error -Message "Button render error for '$($this.Name)': $_" 
        }
    }

HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                $this.IsPressed = $true
                $this.RequestRedraw()
                
                if ($this.OnClick) { 
                    Invoke-WithErrorHandling -Component "$($this.Name).OnClick" -ScriptBlock { & $this.OnClick }
                }
                
                Start-Sleep -Milliseconds 50 # Visual feedback for press
                $this.IsPressed = $false
                $this.RequestRedraw()
                return $true
            }
        } catch { 
            Write-Log -Level Error -Message "Button input error for '$($this.Name)': $_" 
        }
        return $false
    }

TextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3
        $this.MaxLength = 100
    }

OnRender() {
        # AI: REFACTORED - Renders to its own private buffer.
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            
            # Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)

            # Display text or placeholder
            $displayText = $this.Text ?? ""
            $textColor = [ConsoleColor]::White
            if ([string]::IsNullOrEmpty($displayText) -and -not $this.IsFocused) { 
                $displayText = $this.Placeholder ?? "" 
                $textColor = [ConsoleColor]::DarkGray
            }
            
            $maxDisplayLength = $this.Width - 2
            if ($displayText.Length > $maxDisplayLength) { 
                $displayText = $displayText.Substring(0, $maxDisplayLength) 
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $displayText -ForegroundColor $textColor
            
            # Draw cursor if focused
            if ($this.IsFocused -and ($this.CursorPosition -le $displayText.Length)) {
                $cursorX = 1 + $this.CursorPosition
                # Only draw cursor if it's within the visible area
                # AI: FIX - Changed '<' to '-lt' to avoid PowerShell parser ambiguity
                if ($cursorX -lt ($this.Width - 1)) {
                    Write-TuiText -Buffer $this._private_buffer -X $cursorX -Y 1 -Text "_" -ForegroundColor [ConsoleColor]::Yellow
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "TextBox render error for '$($this.Name)': $_" 
        }
    }

HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $currentText = $this.Text ?? ""
            $cursorPos = $this.CursorPosition ?? 0
            $originalText = $currentText
            $handled = $true
            
            switch ($key.Key) {
                ([ConsoleKey]::Backspace) { 
                    if ($cursorPos -gt 0) { 
                        $currentText = $currentText.Remove($cursorPos - 1, 1)
                        $cursorPos-- 
                    } 
                }
                ([ConsoleKey]::Delete) { 
                    if ($cursorPos -lt $currentText.Length) { 
                        $currentText = $currentText.Remove($cursorPos, 1) 
                    } 
                }
                ([ConsoleKey]::LeftArrow) { 
                    if ($cursorPos -gt 0) { $cursorPos-- } 
                }
                ([ConsoleKey]::RightArrow) { 
                    if ($cursorPos -lt $currentText.Length) { $cursorPos++ } 
                }
                ([ConsoleKey]::Home) { $cursorPos = 0 }
                ([ConsoleKey]::End) { $cursorPos = $currentText.Length }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar) -and $currentText.Length -lt $this.MaxLength) { 
                        $currentText = $currentText.Insert($cursorPos, $key.KeyChar)
                        $cursorPos++ 
                    } else { 
                        $handled = $false
                    }
                }
            }
            
            if ($handled) {
                if ($currentText -ne $originalText -or $cursorPos -ne $this.CursorPosition) {
                    $this.Text = $currentText
                    $this.CursorPosition = $cursorPos
                    if ($this.OnChange) { 
                        Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock { 
                            & $this.OnChange -NewValue $currentText 
                        }
                    }
                    $this.RequestRedraw()
                }
            }
            return $handled
        } catch { 
            Write-Log -Level Error -Message "TextBox input error for '$($this.Name)': $_"
            return $false 
        }
    }

CheckBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
    }

OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $fg = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::White
            $checkbox = $this.Checked ? "[X]" : "[ ]"
            $displayText = "$checkbox $($this.Text)"
            
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg
            
        } catch { 
            Write-Log -Level Error -Message "CheckBox render error for '$($this.Name)': $_" 
        }
    }

HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                $this.Checked = -not $this.Checked
                if ($this.OnChange) { 
                    Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock { 
                        & $this.OnChange -NewValue $this.Checked 
                    } 
                }
                $this.RequestRedraw()
                return $true
            }
        } catch { 
            Write-Log -Level Error -Message "CheckBox input error for '$($this.Name)': $_" 
        }
        return $false
    }

RadioButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
    }

OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $fg = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::White
            $radio = $this.Selected ? "(●)" : "( )"
            $displayText = "$radio $($this.Text)"

            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg

        } catch { 
            Write-Log -Level Error -Message "RadioButton render error for '$($this.Name)': $_" 
        }
    }

HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                if (-not $this.Selected) {
                    # AI: Unselect other radio buttons in the same group
                    if ($this.Parent -and $this.GroupName) {
                        $siblingRadios = $this.Parent.Children | Where-Object { 
                            $_ -is [RadioButtonComponent] -and $_.GroupName -eq $this.GroupName -and $_ -ne $this 
                        }
                        foreach ($radio in $siblingRadios) {
                            $radio.Selected = $false
                        }
                    }
                    
                    $this.Selected = $true
                    if ($this.OnChange) { 
                        Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock { 
                            & $this.OnChange -NewValue $this.Selected 
                        } 
                    }
                    $this.Parent.RequestRedraw()
                }
                return $true
            }
        } catch { 
            Write-Log -Level Error -Message "RadioButton input error for '$($this.Name)': $_" 
        }
        return $false
    }

TableColumn([string]$key, [string]$header, [int]$width) {
        $this.Key = $key
        $this.Header = $header
        $this.Width = $width
    }

Table([string]$name) : base() {
        $this.Name = $name
        $this.Columns = [System.Collections.Generic.List[TableColumn]]::new()
        $this.Data = @()
        $this.SelectedIndex = 0
        $this.IsFocusable = $true
        $this.Width = 60
        $this.Height = 15
    }

SetColumns([TableColumn[]]$columns) {
        $this.Columns.Clear()
        foreach ($col in $columns) {
            $this.Columns.Add($col)
        }
        $this.RequestRedraw()
    }

SetData([object[]]$data) {
        $this.Data = if ($null -eq $data) { @() } else { @($data) }
        $dataCount = if ($this.Data -is [array]) { $this.Data.Count } else { 1 }
        if ($this.SelectedIndex -ge $dataCount) {
            $this.SelectedIndex = [Math]::Max(0, $dataCount - 1)
        }
        $this.RequestRedraw()
    }

SelectNext() {
        $dataCount = if ($null -eq $this.Data) { 0 } elseif ($this.Data -is [array]) { $this.Data.Count } else { 1 }
        if ($this.SelectedIndex -lt ($dataCount - 1)) {
            $this.SelectedIndex++
            $this.RequestRedraw()
        }
    }

SelectPrevious() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.RequestRedraw()
        }
    }

GetSelectedItem() {
        if ($null -eq $this.Data) { return $null }
        
        $dataCount = if ($this.Data -is [array]) { $this.Data.Count } else { 1 }
        
        if ($dataCount -gt 0 -and $this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $dataCount) {
            return if ($this.Data -is [array]) { $this.Data[$this.SelectedIndex] } else { $this.Data }
        }
        return $null
    }

OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            # Draw border if enabled
            if ($this.ShowBorder) {
                Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                    -BorderStyle "Single" -BorderColor ([ConsoleColor]::Gray) -BackgroundColor ([ConsoleColor]::Black)
            }
            
            $currentY = if ($this.ShowBorder) { 1 } else { 0 }
            $contentWidth = if ($this.ShowBorder) { $this.Width - 2 } else { $this.Width }
            $renderX = if ($this.ShowBorder) { 1 } else { 0 }
            
            # Header
            if ($this.ShowHeader -and $this.Columns.Count -gt 0) {
                $headerLine = ""
                foreach ($col in $this.Columns) {
                    $headerText = $col.Header.PadRight($col.Width).Substring(0, [Math]::Min($col.Header.Length, $col.Width))
                    $headerLine += $headerText + " "
                }
                
                if ($headerLine.TrimEnd().Length -gt $contentWidth) {
                    $headerLine = $headerLine.Substring(0, $contentWidth)
                }
                
                Write-TuiText -Buffer $this._private_buffer -X $renderX -Y $currentY -Text $headerLine.TrimEnd() `
                    -ForegroundColor ([ConsoleColor]::Cyan) -BackgroundColor ([ConsoleColor]::Black)
                $currentY++
                
                Write-TuiText -Buffer $this._private_buffer -X $renderX -Y $currentY `
                    -Text ("-" * [Math]::Min($headerLine.TrimEnd().Length, $contentWidth)) `
                    -ForegroundColor ([ConsoleColor]::DarkGray) -BackgroundColor ([ConsoleColor]::Black)
                $currentY++
            }
            
            # Data rows
            $dataToRender = @()
            if ($null -ne $this.Data) {
                $dataToRender = if ($this.Data -is [array]) { $this.Data } else { @($this.Data) }
            }
            
            for ($i = 0; $i -lt $dataToRender.Count; $i++) {
                $row = $dataToRender[$i]
                if ($null -eq $row) { continue }
                
                $rowLine = ""
                $isSelected = ($i -eq $this.SelectedIndex)
                
                foreach ($col in $this.Columns) {
                    $cellValue = ""
                    if ($row -is [hashtable] -and $row.ContainsKey($col.Key)) {
                        $cellValue = $row[$col.Key]?.ToString() ?? ""
                    } elseif ($row.PSObject.Properties[$col.Key]) {
                        $propValue = $row.($col.Key)
                        if ($col.Key -eq 'DueDate' -and $propValue -is [DateTime]) {
                            $cellValue = $propValue.ToString('yyyy-MM-dd')
                        } else {
                            $cellValue = if ($null -ne $propValue) { $propValue.ToString() } else { "" }
                        }
                    }
                    
                    $cellText = $cellValue.PadRight($col.Width).Substring(0, [Math]::Min($cellValue.Length, $col.Width))
                    $rowLine += $cellText + " "
                }
                
                $finalLine = $rowLine.TrimEnd()
                if ($isSelected) {
                    $finalLine = "> $finalLine"
                } else {
                    $finalLine = "  $finalLine"
                }
                
                $fg = if ($isSelected) { [ConsoleColor]::Black } else { [ConsoleColor]::White }
                $bg = if ($isSelected) { [ConsoleColor]::White } else { [ConsoleColor]::Black }
                
                if ($finalLine.Length -gt $contentWidth) {
                    $finalLine = $finalLine.Substring(0, $contentWidth)
                }
                
                Write-TuiText -Buffer $this._private_buffer -X $renderX -Y $currentY -Text $finalLine `
                    -ForegroundColor $fg -BackgroundColor $bg
                $currentY++
                
                # Don't exceed available space
                if ($currentY -ge ($this.Height - 1)) { break }
            }
            
            if ($dataToRender.Count -eq 0) {
                Write-TuiText -Buffer $this._private_buffer -X $renderX -Y $currentY -Text "  No data to display" `
                    -ForegroundColor ([ConsoleColor]::DarkGray) -BackgroundColor ([ConsoleColor]::Black)
            }
            
        } catch { 
            Write-Log -Level Error -Message "Table render error for '$($this.Name)': $_" 
        }
    }

HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        try {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    $this.SelectPrevious()
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    $this.SelectNext()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    $selectedItem = $this.GetSelectedItem()
                    if ($null -ne $selectedItem) {
                        # Trigger selection event or action
                        Write-Log -Level Debug -Message "Table item selected: $($selectedItem)"
                    }
                    return $true
                }
            }
        } catch { 
            Write-Log -Level Error -Message "Table input error for '$($this.Name)': $_" 
        }
        
        return $false
    }

OnFocus() {
        $this.IsFocused = $true
        $this.RequestRedraw()
    }

OnBlur() {
        $this.IsFocused = $false
        $this.RequestRedraw()
    }

MultilineTextBoxComponent([string]$name) : base() {
        $this.Name = $name
        $this.IsFocusable = $true
        $this.Width = 40
        $this.Height = 10
    }

OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            
            # AI: Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Calculate visible area
            $textAreaHeight = $this.Height - 2
            $textAreaWidth = $this.Width - 2
            $startLine = $this.ScrollOffsetY
            $endLine = [Math]::Min($this.Lines.Count - 1, $startLine + $textAreaHeight - 1)
            
            # AI: Render text lines
            for ($i = $startLine; $i -le $endLine; $i++) {
                if ($i -ge $this.Lines.Count) { break }
                
                $line = $this.Lines[$i] ?? ""
                $displayLine = $line
                if ($displayLine.Length -gt $textAreaWidth) {
                    $displayLine = $displayLine.Substring(0, $textAreaWidth)
                }
                
                $lineY = 1 + ($i - $startLine)
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y $lineY -Text $displayLine `
                    -ForegroundColor ([ConsoleColor]::White) -BackgroundColor ([ConsoleColor]::Black)
            }
            
            # AI: Show placeholder if empty and not focused
            if ($this.Lines.Count -eq 1 -and [string]::IsNullOrEmpty($this.Lines[0]) -and -not $this.IsFocused) {
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $this.Placeholder `
                    -ForegroundColor ([ConsoleColor]::DarkGray) -BackgroundColor ([ConsoleColor]::Black)
            }
            
            # AI: Draw cursor if focused
            if ($this.IsFocused) {
                $cursorLine = $this.CurrentLine - $this.ScrollOffsetY
                if ($cursorLine -ge 0 -and $cursorLine -lt $textAreaHeight) {
                    $cursorX = 1 + $this.CursorPosition
                    $cursorY = 1 + $cursorLine
                    if ($cursorX -lt $this.Width - 1) {
                        Write-TuiText -Buffer $this._private_buffer -X $cursorX -Y $cursorY -Text "_" `
                            -ForegroundColor ([ConsoleColor]::Yellow) -BackgroundColor ([ConsoleColor]::Black)
                    }
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "MultilineTextBox render error for '$($this.Name)': $_" 
        }
    }

HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $currentLineText = $this.Lines[$this.CurrentLine] ?? ""
            $originalLines = $this.Lines.Clone()
            $handled = $true
            
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this.CurrentLine -gt 0) {
                        $this.CurrentLine--
                        $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.Lines[$this.CurrentLine].Length)
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $this.CurrentLine++
                        $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.Lines[$this.CurrentLine].Length)
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.CursorPosition -gt 0) {
                        $this.CursorPosition--
                    } elseif ($this.CurrentLine -gt 0) {
                        $this.CurrentLine--
                        $this.CursorPosition = $this.Lines[$this.CurrentLine].Length
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.CursorPosition -lt $currentLineText.Length) {
                        $this.CursorPosition++
                    } elseif ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $this.CurrentLine++
                        $this.CursorPosition = 0
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::Home) { $this.CursorPosition = 0 }
                ([ConsoleKey]::End) { $this.CursorPosition = $currentLineText.Length }
                ([ConsoleKey]::Enter) {
                    if ($this.Lines.Count -lt $this.MaxLines) {
                        $beforeCursor = $currentLineText.Substring(0, $this.CursorPosition)
                        $afterCursor = $currentLineText.Substring($this.CursorPosition)
                        
                        $this.Lines[$this.CurrentLine] = $beforeCursor
                        $this.Lines = @($this.Lines[0..$this.CurrentLine]) + @($afterCursor) + @($this.Lines[($this.CurrentLine + 1)..($this.Lines.Count - 1)])
                        
                        $this.CurrentLine++
                        $this.CursorPosition = 0
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CursorPosition -gt 0) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Remove($this.CursorPosition - 1, 1)
                        $this.CursorPosition--
                    } elseif ($this.CurrentLine -gt 0 -and $this.Lines.Count -gt 1) {
                        $previousLine = $this.Lines[$this.CurrentLine - 1]
                        $this.CursorPosition = $previousLine.Length
                        $this.Lines[$this.CurrentLine - 1] = $previousLine + $currentLineText
                        $this.Lines = @($this.Lines[0..($this.CurrentLine - 1)]) + @($this.Lines[($this.CurrentLine + 1)..($this.Lines.Count - 1)])
                        $this.CurrentLine--
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($this.CursorPosition -lt $currentLineText.Length) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Remove($this.CursorPosition, 1)
                    } elseif ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $nextLine = $this.Lines[$this.CurrentLine + 1]
                        $this.Lines[$this.CurrentLine] = $currentLineText + $nextLine
                        $this.Lines = @($this.Lines[0..$this.CurrentLine]) + @($this.Lines[($this.CurrentLine + 2)..($this.Lines.Count - 1)])
                    }
                }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar) -and $currentLineText.Length -lt $this.MaxLineLength) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Insert($this.CursorPosition, $key.KeyChar)
                        $this.CursorPosition++
                    } else {
                        $handled = $false
                    }
                }
            }
            
            if ($handled -and $this.OnChange -and -not $this._ArraysEqual($originalLines, $this.Lines)) {
                Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -Context "Change Event" -ScriptBlock { 
                    & $this.OnChange -NewValue $this.Lines 
                }
                $this.RequestRedraw()
            }
            
            return $handled
        } catch { 
            Write-Log -Level Error -Message "MultilineTextBox input error for '$($this.Name)': $_"
            return $false 
        }
    }

_UpdateScrolling() {
        $textAreaHeight = $this.Height - 2
        if ($this.CurrentLine -lt $this.ScrollOffsetY) {
            $this.ScrollOffsetY = $this.CurrentLine
        } elseif ($this.CurrentLine -ge ($this.ScrollOffsetY + $textAreaHeight)) {
            $this.ScrollOffsetY = $this.CurrentLine - $textAreaHeight + 1
        }
    }

_ArraysEqual([string[]]$array1, [string[]]$array2) {
        if ($array1.Count -ne $array2.Count) { return $false }
        for ($i = 0; $i -lt $array1.Count; $i++) {
            if ($array1[$i] -ne $array2[$i]) { return $false }
        }
        return $true
    }

GetText() {
        return $this.Lines -join "`n"
    }

SetText([string]$text) {
        $this.Lines = if ([string]::IsNullOrEmpty($text)) { @("") } else { $text -split "`n" }
        $this.CurrentLine = 0
        $this.CursorPosition = 0
        $this.ScrollOffsetY = 0
        $this.RequestRedraw()
    }

NumericInputComponent([string]$name) : base() {
        $this.Name = $name
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3
        $this.TextValue = $this.Value.ToString("F$($this.DecimalPlaces)")
    }

OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            
            # AI: Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Display value with suffix
            $displayText = $this.TextValue + $this.Suffix
            $maxDisplayLength = $this.Width - 6
            if ($displayText.Length -gt $maxDisplayLength) {
                $displayText = $displayText.Substring(0, $maxDisplayLength)
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y 1 -Text $displayText `
                -ForegroundColor ([ConsoleColor]::White) -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw spinner arrows
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 0 -Text "▲" `
                -ForegroundColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 2 -Text "▼" `
                -ForegroundColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw cursor if focused
            if ($this.IsFocused -and $this.CursorPosition -le $this.TextValue.Length) {
                $cursorX = 2 + $this.CursorPosition
                if ($cursorX -lt $this.Width - 4) {
                    Write-TuiText -Buffer $this._private_buffer -X $cursorX -Y 1 -Text "_" `
                        -ForegroundColor ([ConsoleColor]::Yellow) -BackgroundColor ([ConsoleColor]::Black)
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "NumericInput render error for '$($this.Name)': $_" 
        }
    }

HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $handled = $true
            $originalValue = $this.Value
            
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    $this._IncrementValue()
                }
                ([ConsoleKey]::DownArrow) {
                    $this._DecrementValue()
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.CursorPosition -gt 0) { 
                        $this.CursorPosition-- 
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.CursorPosition -lt $this.TextValue.Length) { 
                        $this.CursorPosition++ 
                    }
                }
                ([ConsoleKey]::Home) { $this.CursorPosition = 0 }
                ([ConsoleKey]::End) { $this.CursorPosition = $this.TextValue.Length }
                ([ConsoleKey]::Backspace) {
                    if ($this.CursorPosition -gt 0) {
                        $this.TextValue = $this.TextValue.Remove($this.CursorPosition - 1, 1)
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($this.CursorPosition -lt $this.TextValue.Length) {
                        $this.TextValue = $this.TextValue.Remove($this.CursorPosition, 1)
                    }
                }
                ([ConsoleKey]::Enter) {
                    $this._ValidateAndUpdate()
                }
                default {
                    if ($key.KeyChar -and ($key.KeyChar -match '[\d\.\-]' -or 
                        ($key.KeyChar -eq '.' -and $this.DecimalPlaces -gt 0 -and -not $this.TextValue.Contains('.')))) {
                        $this.TextValue = $this.TextValue.Insert($this.CursorPosition, $key.KeyChar)
                        $this.CursorPosition++
                    } else {
                        $handled = $false
                    }
                }
            }
            
            if ($handled -and $this.Value -ne $originalValue -and $this.OnChange) {
                Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -Context "Change Event" -ScriptBlock { 
                    & $this.OnChange -NewValue $this.Value 
                }
                $this.RequestRedraw()
            }
            
            return $handled
        } catch { 
            Write-Log -Level Error -Message "NumericInput input error for '$($this.Name)': $_"
            return $false 
        }
    }

_IncrementValue() {
        $newValue = [Math]::Min($this.Max, $this.Value + $this.Step)
        $this._SetValue($newValue)
    }

_DecrementValue() {
        $newValue = [Math]::Max($this.Min, $this.Value - $this.Step)
        $this._SetValue($newValue)
    }

_SetValue([double]$value) {
        $this.Value = $value
        $this.TextValue = $value.ToString("F$($this.DecimalPlaces)")
        $this.CursorPosition = $this.TextValue.Length
    }

_ValidateAndUpdate() {
        try {
            $newValue = [double]$this.TextValue
            $newValue = [Math]::Max($this.Min, [Math]::Min($this.Max, $newValue))
            $newValue = [Math]::Round($newValue, $this.DecimalPlaces)
            
            $this._SetValue($newValue)
            return $true
        } catch {
            $this.TextValue = $this.Value.ToString("F$($this.DecimalPlaces)")
            Write-Log -Level Warning -Message "NumericInput validation failed for '$($this.Name)': $_"
            return $false
        }
    }

DateInputComponent([string]$name) : base() {
        $this.Name = $name
        $this.IsFocusable = $true
        $this.Width = 25
        $this.Height = 3
        $this.TextValue = $this.Value.ToString($this.Format)
    }

OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            
            # AI: Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Display date value
            $displayText = $this.TextValue
            $maxDisplayLength = $this.Width - 6
            if ($displayText.Length -gt $maxDisplayLength) {
                $displayText = $displayText.Substring(0, $maxDisplayLength)
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y 1 -Text $displayText `
                -ForegroundColor ([ConsoleColor]::White) -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw calendar icon
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 1 -Text "📅" `
                -ForegroundColor ([ConsoleColor]::Cyan) -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw cursor if focused
            if ($this.IsFocused -and $this.CursorPosition -le $this.TextValue.Length) {
                $cursorX = 2 + $this.CursorPosition
                if ($cursorX -lt $this.Width - 4) {
                    Write-TuiText -Buffer $this._private_buffer -X $cursorX -Y 1 -Text "_" `
                        -ForegroundColor ([ConsoleColor]::Yellow) -BackgroundColor ([ConsoleColor]::Black)
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "DateInput render error for '$($this.Name)': $_" 
        }
    }

HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $handled = $true
            $originalValue = $this.Value
            
            if ($this.ShowCalendar) {
                switch ($key.Key) {
                    ([ConsoleKey]::Escape) { $this.ShowCalendar = $false }
                    ([ConsoleKey]::LeftArrow) { $this.Value = $this.Value.AddDays(-1) }
                    ([ConsoleKey]::RightArrow) { $this.Value = $this.Value.AddDays(1) }
                    ([ConsoleKey]::UpArrow) { $this.Value = $this.Value.AddDays(-7) }
                    ([ConsoleKey]::DownArrow) { $this.Value = $this.Value.AddDays(7) }
                    ([ConsoleKey]::Enter) { 
                        $this.ShowCalendar = $false
                        $this.TextValue = $this.Value.ToString($this.Format)
                    }
                    default { $handled = $false }
                }
            } else {
                switch ($key.Key) {
                    ([ConsoleKey]::F4) { $this.ShowCalendar = $true }
                    ([ConsoleKey]::UpArrow) { $this.Value = $this.Value.AddDays(1); $this.TextValue = $this.Value.ToString($this.Format) }
                    ([ConsoleKey]::DownArrow) { $this.Value = $this.Value.AddDays(-1); $this.TextValue = $this.Value.ToString($this.Format) }
                    ([ConsoleKey]::LeftArrow) {
                        if ($this.CursorPosition -gt 0) { $this.CursorPosition-- }
                    }
                    ([ConsoleKey]::RightArrow) {
                        if ($this.CursorPosition -lt $this.TextValue.Length) { $this.CursorPosition++ }
                    }
                    ([ConsoleKey]::Home) { $this.CursorPosition = 0 }
                    ([ConsoleKey]::End) { $this.CursorPosition = $this.TextValue.Length }
                    ([ConsoleKey]::Backspace) {
                        if ($this.CursorPosition -gt 0) {
                            $this.TextValue = $this.TextValue.Remove($this.CursorPosition - 1, 1)
                            $this.CursorPosition--
                        }
                    }
                    ([ConsoleKey]::Delete) {
                        if ($this.CursorPosition -lt $this.TextValue.Length) {
                            $this.TextValue = $this.TextValue.Remove($this.CursorPosition, 1)
                        }
                    }
                    ([ConsoleKey]::Enter) {
                        $this._ValidateAndUpdate()
                    }
                    default {
                        if ($key.KeyChar -and ($key.KeyChar -match '[\d\-\/]')) {
                            $this.TextValue = $this.TextValue.Insert($this.CursorPosition, $key.KeyChar)
                            $this.CursorPosition++
                        } else {
                            $handled = $false
                        }
                    }
                }
            }
            
            if ($handled -and $this.Value -ne $originalValue -and $this.OnChange) {
                Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -Context "Change Event" -ScriptBlock { 
                    & $this.OnChange -NewValue $this.Value 
                }
                $this.RequestRedraw()
            }
            
            return $handled
        } catch { 
            Write-Log -Level Error -Message "DateInput input error for '$($this.Name)': $_"
            return $false 
        }
    }

_ValidateAndUpdate() {
        try {
            $newDate = [DateTime]::ParseExact($this.TextValue, $this.Format, $null)
            if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                $this.Value = $newDate
                $this.TextValue = $newDate.ToString($this.Format)
                return $true
            }
        } catch {
            # Reset to current value on parse error
            $this.TextValue = $this.Value.ToString($this.Format)
            Write-Log -Level Warning -Message "DateInput validation failed for '$($this.Name)': $_"
        }
        return $false
    }

ComboBoxComponent([string]$name) : base() {
        $this.Name = $name
        $this.IsFocusable = $true
        $this.Width = 30
        $this.Height = 3
    }

OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
#```
        
        try {
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            
            # AI: Draw main combobox
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Display selected item or placeholder
            $displayText = ""
            if ($this.SelectedItem) {
                if ($this.SelectedItem -is [string]) {
                    $displayText = $this.SelectedItem
                } elseif ($this.SelectedItem -is [hashtable] -and $this.SelectedItem.ContainsKey($this.DisplayMember)) {
                    $displayText = $this.SelectedItem[$this.DisplayMember]
                } else {
                    $displayText = $this.SelectedItem.ToString()
                }
            } else {
                $displayText = $this.Placeholder
            }
            
            $maxDisplayLength = $this.Width - 6
            if ($displayText.Length -gt $maxDisplayLength) {
                $displayText = $displayText.Substring(0, $maxDisplayLength - 3) + "..."
            }
            
            $textColor = $this.SelectedItem ? [ConsoleColor]::White : [ConsoleColor]::DarkGray
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y 1 -Text $displayText `
                -ForegroundColor $textColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw dropdown arrow
            $arrow = $this.IsDropDownOpen ? "▲" : "▼"
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 1 -Text $arrow `
                -ForegroundColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
        } catch { 
            Write-Log -Level Error -Message "ComboBox render error for '$($this.Name)': $_" 
        }
    }

HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $handled = $true
            $originalSelection = $this.SelectedItem
            
            if ($this.IsDropDownOpen) {
                switch ($key.Key) {
                    ([ConsoleKey]::Escape) {
                        $this.IsDropDownOpen = $false
                    }
                    ([ConsoleKey]::Enter) {
                        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
                            $this.SelectedItem = $this.Items[$this.SelectedIndex]
                        }
                        $this.IsDropDownOpen = $false
                    }
                    ([ConsoleKey]::UpArrow) {
                        if ($this.SelectedIndex -gt 0) {
                            $this.SelectedIndex--
                            $this._UpdateScrolling()
                        }
                    }
                    ([ConsoleKey]::DownArrow) {
                        if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                            $this.SelectedIndex++
                            $this._UpdateScrolling()
                        }
                    }
                    default { $handled = $false }
                }
            } else {
                switch ($key.Key) {
                    ([ConsoleKey]::Enter) { $this._OpenDropDown() }
                    ([ConsoleKey]::Spacebar) { $this._OpenDropDown() }
                    ([ConsoleKey]::DownArrow) { $this._OpenDropDown() }
                    ([ConsoleKey]::UpArrow) { $this._OpenDropDown() }
                    ([ConsoleKey]::F4) { $this._OpenDropDown() }
                    default { $handled = $false }
                }
            }
            
            if ($handled -and $this.SelectedItem -ne $originalSelection -and $this.OnSelectionChanged) {
                Invoke-WithErrorHandling -Component "$($this.Name).OnSelectionChanged" -Context "Selection Change" -ScriptBlock { 
                    & $this.OnSelectionChanged -SelectedItem $this.SelectedItem 
                }
                $this.RequestRedraw()
            }
            
            return $handled
        } catch { 
            Write-Log -Level Error -Message "ComboBox input error for '$($this.Name)': $_"
            return $false 
        }
    }

_OpenDropDown() {
        if ($this.Items.Count -gt 0) {
            $this.IsDropDownOpen = $true
            $this._FindCurrentSelection()
        }
    }

_FindCurrentSelection() {
        $this.SelectedIndex = -1
        if ($this.SelectedItem) {
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                if ($this._ItemsEqual($this.Items[$i], $this.SelectedItem)) {
                    $this.SelectedIndex = $i
                    break
                }
            }
        }
        if ($this.SelectedIndex -eq -1) { $this.SelectedIndex = 0 }
        $this._UpdateScrolling()
    }

_UpdateScrolling() {
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $this.MaxDropDownHeight)) {
            $this.ScrollOffset = $this.SelectedIndex - $this.MaxDropDownHeight + 1
        }
    }

_ItemsEqual([object]$item1, [object]$item2) {
        if ($item1 -is [string] -and $item2 -is [string]) {
            return $item1 -eq $item2
        } elseif ($item1 -is [hashtable] -and $item2 -is [hashtable]) {
            return $item1[$this.ValueMember] -eq $item2[$this.ValueMember]
        } else {
            return $item1 -eq $item2
        }
    }

SetItems([object[]]$items) {
        $this.Items = $items
        $this.SelectedItem = $null
        $this.SelectedIndex = -1
        $this.ScrollOffset = 0
        $this.IsDropDownOpen = $false
        $this.RequestRedraw()
    }

GetSelectedValue() {
        if ($this.SelectedItem -is [hashtable] -and $this.SelectedItem.ContainsKey($this.ValueMember)) {
            return $this.SelectedItem[$this.ValueMember]
        }
        return $this.SelectedItem
    }

KeybindingService() {
        $this.ContextStack = [System.Collections.Generic.List[string]]::new()
        $this.InitializeDefaultBindings()
        
        Write-Log -Level Info -Message "KeybindingService initialized"
    }

KeybindingService([bool]$enableChords) {
        $this.ContextStack = [System.Collections.Generic.List[string]]::new()
        $this.EnableChords = $enableChords
        $this.InitializeDefaultBindings()
        
        Write-Log -Level Info -Message "KeybindingService initialized with chords: $enableChords"
    }

InitializeDefaultBindings() {
        # AI: Standard application keybindings
        $this.KeyMap = @{
            "app.exit" = @{ Key = "Q"; Modifiers = @("Ctrl") }
            "app.help" = @{ Key = [System.ConsoleKey]::F1; Modifiers = @() }
            "nav.back" = @{ Key = [System.ConsoleKey]::Escape; Modifiers = @() }
            "nav.up" = @{ Key = [System.ConsoleKey]::UpArrow; Modifiers = @() }
            "nav.down" = @{ Key = [System.ConsoleKey]::DownArrow; Modifiers = @() }
            "nav.left" = @{ Key = [System.ConsoleKey]::LeftArrow; Modifiers = @() }
            "nav.right" = @{ Key = [System.ConsoleKey]::RightArrow; Modifiers = @() }
            "nav.select" = @{ Key = [System.ConsoleKey]::Enter; Modifiers = @() }
            "nav.pageup" = @{ Key = [System.ConsoleKey]::PageUp; Modifiers = @() }
            "nav.pagedown" = @{ Key = [System.ConsoleKey]::PageDown; Modifiers = @() }
            "nav.home" = @{ Key = [System.ConsoleKey]::Home; Modifiers = @() }
            "nav.end" = @{ Key = [System.ConsoleKey]::End; Modifiers = @() }
            "nav.tab" = @{ Key = [System.ConsoleKey]::Tab; Modifiers = @() }
            "nav.shifttab" = @{ Key = [System.ConsoleKey]::Tab; Modifiers = @("Shift") }
            "edit.delete" = @{ Key = [System.ConsoleKey]::Delete; Modifiers = @() }
            "edit.backspace" = @{ Key = [System.ConsoleKey]::Backspace; Modifiers = @() }
            "edit.new" = @{ Key = "n"; Modifiers = @() }
            "edit.save" = @{ Key = "s"; Modifiers = @("Ctrl") }
            "app.refresh" = @{ Key = [System.ConsoleKey]::F5; Modifiers = @() }
        }
    }

SetBinding([string]$actionName, [System.ConsoleKey]$key, [string[]]$modifiers) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "SetBinding:$actionName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                throw [System.ArgumentException]::new("Action name cannot be null or empty", "actionName")
            }
            
            $this.KeyMap[$actionName.ToLower()] = @{
                Key = $key
                Modifiers = if ($modifiers) { @($modifiers) } else { @() }
            }
            
            Write-Log -Level Debug -Message "Set keybinding: $actionName -> $key"
        }
    }

SetBinding([string]$actionName, [char]$key, [string[]]$modifiers) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "SetBinding:$actionName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                throw [System.ArgumentException]::new("Action name cannot be null or empty", "actionName")
            }
            
            $this.KeyMap[$actionName.ToLower()] = @{
                Key = $key
                Modifiers = if ($modifiers) { @($modifiers) } else { @() }
            }
            
            Write-Log -Level Debug -Message "Set keybinding: $actionName -> $key"
        }
    }

SetBinding([string]$actionName, [System.ConsoleKeyInfo]$keyInfo) {
        if ([string]::IsNullOrWhiteSpace($actionName)) {
            throw [System.ArgumentException]::new("Action name cannot be null or empty", "actionName")
        }
        
        $modifiers = @()
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) { $modifiers += "Ctrl" }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) { $modifiers += "Alt" }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) { $modifiers += "Shift" }

        $this.KeyMap[$actionName.ToLower()] = @{
            Key = $keyInfo.Key
            KeyChar = $keyInfo.KeyChar
            Modifiers = $modifiers
        }
        Write-Log -Level Debug -Message "Set keybinding for '$actionName': $($this.GetBindingDescription($actionName))"
    }

RemoveBinding([string]$actionName) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "RemoveBinding:$actionName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                return
            }
            
            $normalizedName = $actionName.ToLower()
            if ($this.KeyMap.ContainsKey($normalizedName)) {
                $this.KeyMap.Remove($normalizedName)
                Write-Log -Level Debug -Message "Removed keybinding: $actionName"
            }
        }
    }

IsAction([string]$actionName, [System.ConsoleKeyInfo]$keyInfo) {
        return $this.IsAction($actionName, $keyInfo, $null)
    }

IsAction([string]$actionName, [System.ConsoleKeyInfo]$keyInfo, [string]$context) {
        return Invoke-WithErrorHandling -Component "KeybindingService" -Context "IsAction:$actionName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                return $false
            }
            
            $normalizedName = $actionName.ToLower()
            if (-not $this.KeyMap.ContainsKey($normalizedName)) {
                return $false
            }
            
            $binding = $this.KeyMap[$normalizedName]
            
            # Check if the key matches
            $keyMatches = $false
            if ($binding.Key -is [System.ConsoleKey]) {
                $keyMatches = ($keyInfo.Key -eq $binding.Key)
            }
            elseif ($binding.Key -is [char]) {
                $keyMatches = ($keyInfo.KeyChar -eq $binding.Key)
            }
            elseif ($binding.ContainsKey('KeyChar') -and $binding.KeyChar -ne [char]0) {
                # Character-based binding (case-insensitive)
                $keyMatches = $keyInfo.KeyChar.ToString().Equals($binding.KeyChar.ToString(), [System.StringComparison]::OrdinalIgnoreCase)
            }
            else {
                # Try string comparison for backward compatibility
                $keyString = $binding.Key.ToString()
                if ($keyString.Length -eq 1) {
                    $keyMatches = ($keyInfo.KeyChar.ToString().ToUpper() -eq $keyString.ToUpper())
                }
                else {
                    # Try to match against ConsoleKey enum
                    try {
                        $consoleKey = [System.ConsoleKey]::Parse([System.ConsoleKey], $keyString, $true)
                        $keyMatches = ($keyInfo.Key -eq $consoleKey)
                    }
                    catch {
                        $keyMatches = $false
                    }
                }
            }
            
            if (-not $keyMatches) {
                return $false
            }
            
            # Check modifiers
            $hasCtrl = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) -ne 0
            $hasAlt = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) -ne 0
            $hasShift = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) -ne 0
            
            $expectedCtrl = $binding.Modifiers -contains "Ctrl"
            $expectedAlt = $binding.Modifiers -contains "Alt"
            $expectedShift = $binding.Modifiers -contains "Shift"
            
            return ($hasCtrl -eq $expectedCtrl) -and ($hasAlt -eq $expectedAlt) -and ($hasShift -eq $expectedShift)
        }
    }

GetAction([System.ConsoleKeyInfo]$keyInfo) {
        return Invoke-WithErrorHandling -Component "KeybindingService" -Context "GetAction" -ScriptBlock {
            foreach ($actionName in $this.KeyMap.Keys) {
                if ($this.IsAction($actionName, $keyInfo)) {
                    return $actionName
                }
            }
            return $null
        }
    }

RegisterGlobalHandler([string]$actionName, [scriptblock]$handler) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "RegisterGlobalHandler:$actionName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                throw [System.ArgumentException]::new("Action name cannot be null or empty", "actionName")
            }
            if ($null -eq $handler) {
                throw [System.ArgumentNullException]::new("handler", "Handler cannot be null")
            }
            
            $this.GlobalHandlers[$actionName.ToLower()] = $handler
            Write-Log -Level Debug -Message "Registered global handler: $actionName"
        }
    }

HandleKey([System.ConsoleKeyInfo]$keyInfo) {
        return $this.HandleKey($keyInfo, $null)
    }

HandleKey([System.ConsoleKeyInfo]$keyInfo, [string]$context) {
        return Invoke-WithErrorHandling -Component "KeybindingService" -Context "HandleKey" -ScriptBlock {
            # Check all registered actions
            foreach ($action in $this.KeyMap.Keys) {
                if ($this.IsAction($action, $keyInfo, $context)) {
                    # Execute global handler if registered
                    if ($this.GlobalHandlers.ContainsKey($action)) {
                        Write-Log -Level Debug -Message "Executing global handler: $action"
                        try {
                            return & $this.GlobalHandlers[$action] -KeyInfo $keyInfo -Context $context
                        }
                        catch {
                            Write-Log -Level Error -Message "Global handler failed for '$action': $_"
                            return $null
                        }
                    }
                    
                    # Return the action name for the caller to handle
                    return $action
                }
            }
            
            return $null
        }
    }

PushContext([string]$context) {
        if (-not [string]::IsNullOrWhiteSpace($context)) {
            $this.ContextStack.Add($context)
            Write-Log -Level Debug -Message "Pushed keybinding context: $context (Stack depth: $($this.ContextStack.Count))"
        }
    }

PopContext() {
        if ($this.ContextStack.Count -gt 0) {
            $context = $this.ContextStack[-1]
            $this.ContextStack.RemoveAt($this.ContextStack.Count - 1)
            Write-Log -Level Debug -Message "Popped keybinding context: $context (Stack depth: $($this.ContextStack.Count))"
            return $context
        }
        return $null
    }

GetCurrentContext() {
        if ($this.ContextStack.Count -gt 0) {
            return $this.ContextStack[-1]
        }
        return "global"
    }

GetBindingDescription([string]$actionName) {
        if ([string]::IsNullOrWhiteSpace($actionName)) {
            return $null
        }
        
        $normalizedName = $actionName.ToLower()
        if (-not $this.KeyMap.ContainsKey($normalizedName)) {
            return "Unbound"
        }
        
        $binding = $this.KeyMap[$normalizedName]
        $keyStr = if ($binding.ContainsKey('KeyChar') -and $binding.KeyChar -ne [char]0) {
            $binding.KeyChar.ToString().ToUpper()
        } elseif ($binding.Key -is [System.ConsoleKey]) {
            $binding.Key.ToString()
        } else {
            $binding.Key.ToString().ToUpper()
        }
        
        if ($binding.Modifiers.Count -gt 0) {
            return "$($binding.Modifiers -join '+') + $keyStr"
        }
        
        return $keyStr
    }

GetAllBindings() {
        return $this.GetAllBindings($false)
    }

GetAllBindings([bool]$groupByCategory) {
        if (-not $groupByCategory) {
            return $this.KeyMap.Clone()
        }
        
        # Group by category (part before the dot)
        $grouped = @{}
        foreach ($action in $this.KeyMap.Keys) {
            $parts = $action.Split('.')
            $category = if ($parts.Count -gt 1) { $parts[0] } else { "General" }
            if (-not $grouped.ContainsKey($category)) {
                $grouped[$category] = @{}
            }
            $grouped[$category][$action] = $this.KeyMap[$action]
        }
        
        return $grouped
    }

ExportBindings([string]$path) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "ExportBindings" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($path)) {
                throw [System.ArgumentException]::new("Path cannot be null or empty", "path")
            }
            
            $this.KeyMap | ConvertTo-Json -Depth 3 | Out-File -FilePath $path -Encoding UTF8
            Write-Log -Level Info -Message "Exported keybindings to: $path"
        }
    }

ImportBindings([string]$path) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "ImportBindings" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($path)) {
                throw [System.ArgumentException]::new("Path cannot be null or empty", "path")
            }
            
            if (-not (Test-Path $path)) {
                Write-Log -Level Warning -Message "Keybindings file not found: $path"
                return
            }
            
            try {
                $imported = Get-Content $path -Raw | ConvertFrom-Json
                foreach ($prop in $imported.PSObject.Properties) {
                    $bindingData = @{
                        Key = $prop.Value.Key
                        Modifiers = $prop.Value.Modifiers
                    }
                    if ($prop.Value.PSObject.Properties.Name -contains 'KeyChar') {
                        $bindingData['KeyChar'] = $prop.Value.KeyChar
                    }
                    $this.KeyMap[$prop.Name] = $bindingData
                }
                Write-Log -Level Info -Message "Imported keybindings from: $path"
            }
            catch {
                Write-Log -Level Error -Message "Failed to import keybindings from '$path': $_"
                throw
            }
        }
    }

Dialog([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 50
        $this.Height = 10
    }

Show() {
        $this.X = [Math]::Floor(($global:TuiState.BufferWidth - $this.Width) / 2)
        $this.Y = [Math]::Floor(($global:TuiState.BufferHeight - $this.Height) / 2)
        if ($null -eq $this.{_private_buffer} -or $this.{_private_buffer}.Width -ne $this.Width -or $this.{_private_buffer}.Height -ne $this.Height) {
            $this.{_private_buffer} = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        }
        Show-TuiOverlay -Element $this
    }

Close() {
        Close-TopTuiOverlay
    }

OnRender() {
        if ($null -eq $this.{_private_buffer}) { return }
        $this.{_private_buffer}.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
        Write-TuiBox -Buffer $this.{_private_buffer} -X 0 -Y 0 -Width $this.Width -Height $this.Height `
            -BorderStyle "Single" -BorderColor $this.BorderColor -BackgroundColor [ConsoleColor]::Black -Title $this.Title
        if (-not [string]::IsNullOrWhiteSpace($this.Message)) { $this.RenderMessage() }
        $this.RenderDialogContent()
    }

RenderMessage() {
        $messageY = 2; $messageX = 2; $maxWidth = $this.Width - 4
        $wrappedLines = Get-WordWrappedLines -Text $this.Message -MaxWidth $maxWidth
        foreach ($line in $wrappedLines) {
            if ($messageY -ge ($this.Height - 3)) { break }
            Write-TuiText -Buffer $this.{_private_buffer} -X $messageX -Y $messageY -Text $line -ForegroundColor $this.MessageColor
            $messageY++
        }
    }

RenderDialogContent() { }

HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Escape) { $this.OnCancel(); return $true }
        return $false
    }

OnConfirm() { $this.Close() }

OnCancel() { $this.Close() }

AlertDialog([string]$title, [string]$message) : base("AlertDialog") {
        $this.Title = $title; $this.Message = $message; $this.Height = 10
        $this.Width = [Math]::Min(80, [Math]::Max(40, $message.Length + 10))
    }

RenderDialogContent() {
        $buttonY = $this.Height - 2; $buttonLabel = "[ $($this.ButtonText) ]"
        $buttonX = [Math]::Floor(($this.Width - $buttonLabel.Length) / 2)
        Write-TuiText -Buffer $this.{_private_buffer} -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor ([ConsoleColor]::Yellow)
    }

HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) { $this.OnConfirm(); return $true }
        return ([Dialog]$this).HandleInput($key)
    }

ConfirmDialog([string]$title, [string]$message, [scriptblock]$onConfirm, [scriptblock]$onCancel) : base("ConfirmDialog") {
        $this.Title = $title; $this.Message = $message; $this.OnConfirmAction = $onConfirm; $this.OnCancelAction = $onCancel
        $this.Width = [Math]::Min(80, [Math]::Max(50, $message.Length + 10)); $this.Height = 10
    }

RenderDialogContent() {
        $buttonY = $this.Height - 3; $totalButtonWidth = ($this.Buttons.Count * 12) + (($this.Buttons.Count - 1) * 2)
        $buttonX = [Math]::Floor(($this.Width - $totalButtonWidth) / 2)
        for ($i = 0; $i -lt $this.Buttons.Count; $i++) {
            $isSelected = ($i -eq $this.SelectedButton)
            $buttonLabel = if ($isSelected) { "[ $($this.Buttons[$i]) ]" } else { "  $($this.Buttons[$i])  " }
            $color = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray }
            Write-TuiText -Buffer $this.{_private_buffer} -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor $color
            $buttonX += 14
        }
    }

HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::LeftArrow) { $this.SelectedButton = [Math]::Max(0, $this.SelectedButton - 1); $this.RequestRedraw(); return $true }
            ([ConsoleKey]::RightArrow) { $this.SelectedButton = [Math]::Min($this.Buttons.Count - 1, $this.SelectedButton + 1); $this.RequestRedraw(); return $true }
            ([ConsoleKey]::Tab) { $this.SelectedButton = ($this.SelectedButton + 1) % $this.Buttons.Count; $this.RequestRedraw(); return $true }
            ([ConsoleKey]::Enter) { if ($this.SelectedButton -eq 0) { $this.OnConfirm() } else { $this.OnCancel() }; return $true }
            ([ConsoleKey]::Spacebar) { if ($this.SelectedButton -eq 0) { $this.OnConfirm() } else { $this.OnCancel() }; return $true }
        }
        return ([Dialog]$this).HandleInput($key)
    }

OnConfirm() { $this.Close(); if ($this.OnConfirmAction) { Invoke-WithErrorHandling -Component "ConfirmDialog" -Context "OnConfirm" -ScriptBlock $this.OnConfirmAction } }

OnCancel() { $this.Close(); if ($this.OnCancelAction) { Invoke-WithErrorHandling -Component "ConfirmDialog" -Context "OnCancel" -ScriptBlock $this.OnCancelAction } }

InputDialog([string]$title, [string]$prompt, [scriptblock]$onSubmit, [scriptblock]$onCancel) : base("InputDialog") {
        $this.Title = $title
        $this.Prompt = $prompt
        $this.OnSubmitAction = $onSubmit
        $this.OnCancelAction = $onCancel
        $this.Width = [Math]::Min(80, [Math]::Max(50, $prompt.Length + 20))
        $this.Height = 12
    }

SetDefaultValue([string]$value) {
        $this.InputValue = $value
        $this.CursorPosition = $value.Length
    }

RenderDialogContent() {
        $promptY = 3; $promptX = 4
        Write-TuiText -Buffer $this.{_private_buffer} -X $promptX -Y $promptY -Text $this.Prompt -ForegroundColor [ConsoleColor]::White
        
        $inputY = 5; $inputX = 4; $inputWidth = $this.Width - 8
        Write-TuiBox -Buffer $this.{_private_buffer} -X $inputX -Y $inputY -Width $inputWidth -Height 3 -BorderStyle "Single" -BorderColor [ConsoleColor]::DarkGray
        
        $displayValue = $this.InputValue
        if ($displayValue.Length -gt ($inputWidth - 3)) {
            $displayValue = $displayValue.Substring($displayValue.Length - ($inputWidth - 3))
        }
        Write-TuiText -Buffer $this.{_private_buffer} -X ($inputX + 1) -Y ($inputY + 1) -Text $displayValue -ForegroundColor [ConsoleColor]::Yellow
        
        $buttonY = $this.Height - 3; $okLabel = "[ OK ]"; $cancelLabel = "[ Cancel ]"
        $totalWidth = $okLabel.Length + $cancelLabel.Length + 4
        $startX = [Math]::Floor(($this.Width - $totalWidth) / 2)
        Write-TuiText -Buffer $this.{_private_buffer} -X $startX -Y $buttonY -Text $okLabel -ForegroundColor [ConsoleColor]::Green
        Write-TuiText -Buffer $this.{_private_buffer} -X ($startX + $okLabel.Length + 4) -Y $buttonY -Text $cancelLabel -ForegroundColor [ConsoleColor]::Gray
    }

HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::Enter) { $this.OnSubmit(); return $true }
            ([ConsoleKey]::Escape) { $this.OnCancel(); return $true }
            ([ConsoleKey]::Backspace) { if ($this.CursorPosition -gt 0) { $this.InputValue = $this.InputValue.Remove($this.CursorPosition - 1, 1); $this.CursorPosition--; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::Delete) { if ($this.CursorPosition -lt $this.InputValue.Length) { $this.InputValue = $this.InputValue.Remove($this.CursorPosition, 1); $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::LeftArrow) { if ($this.CursorPosition -gt 0) { $this.CursorPosition--; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::RightArrow) { if ($this.CursorPosition -lt $this.InputValue.Length) { $this.CursorPosition++; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::Home) { $this.CursorPosition = 0; $this.RequestRedraw(); return $true }
            ([ConsoleKey]::End) { $this.CursorPosition = $this.InputValue.Length; $this.RequestRedraw(); return $true }
            default {
                if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or $key.KeyChar -in @(' ', '.', '-', '_', '@', '!', '?', ',', ';', ':', '/', '\', '(', ')', '[', ']', '{', '}')) {
                    $this.InputValue = $this.InputValue.Insert($this.CursorPosition, $key.KeyChar)
                    $this.CursorPosition++
                    $this.RequestRedraw()
                    return $true
                }
            }
        }
        return ([Dialog]$this).HandleInput($key)
    }

OnSubmit() {
        $this.Close()
        if ($this.OnSubmitAction) {
            Invoke-WithErrorHandling -Component "InputDialog" -Context "OnSubmit" -ScriptBlock { & $this.OnSubmitAction $this.InputValue }
        }
    }

OnCancel() {
        $this.Close()
        if ($this.OnCancelAction) {
            Invoke-WithErrorHandling -Component "InputDialog" -Context "OnCancel" -ScriptBlock $this.OnCancelAction
        }
    }

ProgressDialog([string]$title, [string]$message) : base("ProgressDialog") {
        $this.Title = $title; $this.Message = $message; $this.Width = 60; $this.Height = 10
    }

UpdateProgress([int]$percent, [string]$status = "") {
        $this.PercentComplete = [Math]::Max(0, [Math]::Min(100, $percent))
        if ($status) { $this.StatusText = $status }
        $this.RequestRedraw()
    }

RenderDialogContent() {
        $barY = 4; $barX = 4; $barWidth = $this.Width - 8
        $filledWidth = [Math]::Floor($barWidth * ($this.PercentComplete / 100.0))
        Write-TuiText -Buffer $this.{_private_buffer} -X $barX -Y $barY -Text ('─' * $barWidth) -ForegroundColor [ConsoleColor]::DarkGray
        if ($filledWidth -gt 0) { Write-TuiText -Buffer $this.{_private_buffer} -X $barX -Y $barY -Text ('█' * $filledWidth) -ForegroundColor [ConsoleColor]::Green }
        
        $percentText = "$($this.PercentComplete)%"; $percentX = [Math]::Floor(($this.Width - $percentText.Length) / 2)
        Write-TuiText -Buffer $this.{_private_buffer} -X $percentX -Y ($barY + 1) -Text $percentText -ForegroundColor [ConsoleColor]::White
        
        if ($this.StatusText) {
            $statusY = $barY + 3; $maxStatusWidth = $this.Width - 8
            $displayStatus = if ($this.StatusText.Length -gt $maxStatusWidth) { $this.StatusText.Substring(0, $maxStatusWidth - 3) + "..." } else { $this.StatusText }
            $statusX = [Math]::Floor(($this.Width - $displayStatus.Length) / 2)
            Write-TuiText -Buffer $this.{_private_buffer} -X $statusX -Y $statusY -Text $displayStatus -ForegroundColor [ConsoleColor]::Gray
        }
        
        if ($this.ShowCancel) {
            $buttonY = $this.Height - 2; $cancelLabel = "[ Cancel ]"; $buttonX = [Math]::Floor(($this.Width - $cancelLabel.Length) / 2)
            Write-TuiText -Buffer $this.{_private_buffer} -X $buttonX -Y $buttonY -Text $cancelLabel -ForegroundColor [ConsoleColor]::Yellow
        }
    }

HandleInput([ConsoleKeyInfo]$key) {
        if ($this.ShowCancel -and $key.Key -in @([ConsoleKey]::Escape, [ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            $this.IsCancelled = $true
            $this.Close()
            return $true
        }
        return $false
    }

ListDialog([string]$title, [string]$prompt, [string[]]$items, [scriptblock]$onSelect, [scriptblock]$onCancel) : base("ListDialog") {
        $this.Title = $title; $this.Prompt = $prompt; $this.Items = $items; $this.OnSelectAction = $onSelect; $this.OnCancelAction = $onCancel
        $this.SelectedIndices = [System.Collections.Generic.HashSet[int]]::new()
        $maxItemWidth = ($items | Measure-Object -Property Length -Maximum).Maximum
        $this.Width = [Math]::Min(80, [Math]::Max(40, $maxItemWidth + 10))
        $this.VisibleItems = [Math]::Min(10, $items.Count)
        $this.Height = $this.VisibleItems + 8
    }

RenderDialogContent() {
        if ($this.Prompt) { $promptY = 2; $promptX = 4; Write-TuiText -Buffer $this.{_private_buffer} -X $promptX -Y $promptY -Text $this.Prompt -ForegroundColor [ConsoleColor]::White }
        
        $listY = 4; $listX = 4; $listWidth = $this.Width - 8
        $endIndex = [Math]::Min($this.ScrollOffset + $this.VisibleItems, $this.Items.Count)
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $relativeY = $listY + ($i - $this.ScrollOffset); $item = $this.Items[$i]; $isSelected = ($i -eq $this.SelectedIndex); $isChecked = $this.SelectedIndices.Contains($i)
            if ($item.Length -gt ($listWidth - 4)) { $item = $item.Substring(0, $listWidth - 7) + "..." }
            $prefix = if ($this.AllowMultiple) { if ($isChecked) { "[x] " } else { "[ ] " } } else { "" }
            $displayText = "$prefix$item"
            $fg = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray }; $bg = if ($isSelected) { [ConsoleColor]::DarkGray } else { [ConsoleColor]::Black }
            Write-TuiText -Buffer $this.{_private_buffer} -X $listX -Y $relativeY -Text (' ' * $listWidth) -BackgroundColor $bg
            Write-TuiText -Buffer $this.{_private_buffer} -X $listX -Y $relativeY -Text $displayText -ForegroundColor $fg -BackgroundColor $bg
        }
        
        if ($this.ScrollOffset -gt 0) { Write-TuiText -Buffer $this.{_private_buffer} -X ($this.Width - 5) -Y $listY -Text "▲" -ForegroundColor [ConsoleColor]::DarkGray }
        if ($endIndex -lt $this.Items.Count) { Write-TuiText -Buffer $this.{_private_buffer} -X ($this.Width - 5) -Y ($listY + $this.VisibleItems - 1) -Text "▼" -ForegroundColor [ConsoleColor]::DarkGray }
        
        $instructY = $this.Height - 3; $instructions = if ($this.AllowMultiple) { "Space: Toggle, Enter: Confirm, Esc: Cancel" } else { "Enter: Select, Esc: Cancel" }; $instructX = [Math]::Floor(($this.Width - $instructions.Length) / 2)
        Write-TuiText -Buffer $this.{_private_buffer} -X $instructX -Y $instructY -Text $instructions -ForegroundColor [ConsoleColor]::DarkGray
    }

HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) { if ($this.SelectedIndex -gt 0) { $this.SelectedIndex--; if ($this.SelectedIndex -lt $this.ScrollOffset) { $this.ScrollOffset = $this.SelectedIndex }; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::DownArrow) { if ($this.SelectedIndex -lt ($this.Items.Count - 1)) { $this.SelectedIndex++; if ($this.SelectedIndex -ge ($this.ScrollOffset + $this.VisibleItems)) { $this.ScrollOffset = $this.SelectedIndex - $this.VisibleItems + 1 }; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::Spacebar) { if ($this.AllowMultiple) { if ($this.SelectedIndices.Contains($this.SelectedIndex)) { [void]$this.SelectedIndices.Remove($this.SelectedIndex) } else { [void]$this.SelectedIndices.Add($this.SelectedIndex) }; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::Enter) { $this.OnSelect(); return $true }
            ([ConsoleKey]::Escape) { $this.OnCancel(); return $true }
        }
        return $false
    }

OnSelect() {
        $this.Close()
        if ($this.OnSelectAction) {
            if ($this.AllowMultiple) {
                $selectedItems = @(); foreach ($index in $this.SelectedIndices) { $selectedItems += $this.Items[$index] }
                Invoke-WithErrorHandling -Component "ListDialog" -Context "OnSelect" -ScriptBlock { & $this.OnSelectAction $selectedItems }
            } else {
                $selectedItem = $this.Items[$this.SelectedIndex]
                Invoke-WithErrorHandling -Component "ListDialog" -Context "OnSelect" -ScriptBlock { & $this.OnSelectAction $selectedItem }
            }
        }
    }

OnCancel() {
        $this.Close()
        if ($this.OnCancelAction) {
            Invoke-WithErrorHandling -Component "ListDialog" -Context "OnCancel" -ScriptBlock $this.OnCancelAction
        }
    }

function Initialize-DialogSystem {
    Invoke-WithErrorHandling -Component "DialogSystem" -Context "Initialize" -ScriptBlock {
        Subscribe-Event -EventName "Confirm.Request" -Handler { param($EventData) $params = $EventData.Data; Show-ConfirmDialog @params }
        Subscribe-Event -EventName "Alert.Show" -Handler { param($EventData) $params = $EventData.Data; Show-AlertDialog @params }
        Subscribe-Event -EventName "Input.Request" -Handler { param($EventData) $params = $EventData.Data; Show-InputDialog @params }
        Write-Log -Level Info -Message "Class-based Dialog System initialized"
    }
}

function Close-TuiDialog { Invoke-WithErrorHandling -Component "DialogSystem" -Context "CloseDialog" -ScriptBlock { Close-TopTuiOverlay } }

DashboardScreen([hashtable]$services) : base("DashboardScreen", $services) {
        $this.Name = "DashboardScreen"
        $this.Components = [System.Collections.Generic.List[UIElement]]::new()
        $this.IsFocusable = $true
        $this.Enabled = $true
        $this.Visible = $true
        $this.Tasks = @()
        
        Write-Log -Level Info -Message "Creating DashboardScreen with NCurses architecture"
    }

Initialize() {
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "Initialize" -ScriptBlock {
            $this.Width = $global:TuiState.BufferWidth
            $this.Height = $global:TuiState.BufferHeight
            
            if ($null -ne $this.{_private_buffer}) {
                $this.{_private_buffer}.Resize($this.Width, $this.Height)
            }
            
            $this.MainPanel = [Panel]::new(0, 0, $this.Width, $this.Height, "PMC Terminal v5 - Dashboard")
            $this.MainPanel.HasBorder = $true
            $this.MainPanel.BorderStyle = "Double"
            $this.MainPanel.BorderColor = [ConsoleColor]::Cyan
            $this.MainPanel.BackgroundColor = [ConsoleColor]::Black
            $this.MainPanel.TitleColor = [ConsoleColor]::White
            $this.MainPanel.Name = "MainDashboardPanel"
            $this.AddChild($this.MainPanel)
            
            $summaryWidth = [Math]::Floor($this.Width * 0.4)
            $this.SummaryPanel = [Panel]::new(2, 2, $summaryWidth, 12, "Task Summary")
            $this.SummaryPanel.HasBorder = $true
            $this.SummaryPanel.BorderStyle = "Single"
            $this.SummaryPanel.BorderColor = [ConsoleColor]::Green
            $this.SummaryPanel.BackgroundColor = [ConsoleColor]::Black
            $this.SummaryPanel.Name = "SummaryPanel"
            $this.MainPanel.AddChild($this.SummaryPanel)
            
            $menuX = $summaryWidth + 4
            $menuWidth = $this.Width - $menuX - 2
            $this.MenuPanel = [Panel]::new($menuX, 2, $menuWidth, 15, "Main Menu")
            $this.MenuPanel.HasBorder = $true
            $this.MenuPanel.BorderStyle = "Single"
            $this.MenuPanel.BorderColor = [ConsoleColor]::Yellow
            $this.MenuPanel.BackgroundColor = [ConsoleColor]::Black
            $this.MenuPanel.Name = "MenuPanel"
            $this.MainPanel.AddChild($this.MenuPanel)
            
            $this.StatusPanel = [Panel]::new(2, 19, $this.Width - 4, $this.Height - 21, "System Status")
            $this.StatusPanel.HasBorder = $true
            $this.StatusPanel.BorderStyle = "Single"
            $this.StatusPanel.BorderColor = [ConsoleColor]::Magenta
            $this.StatusPanel.BackgroundColor = [ConsoleColor]::Black
            $this.StatusPanel.Name = "StatusPanel"
            $this.MainPanel.AddChild($this.StatusPanel)
            
            $this.MainMenu = [NavigationMenu]::new("MainMenu")
            $this.MainMenu.Move(0, 0)
            $this.MainMenu.Resize($this.MenuPanel.ContentWidth, $this.MenuPanel.ContentHeight)
            $this.BuildMainMenu()
            $this.MenuPanel.AddChild($this.MainMenu)
            
            $this.RefreshData()
            $this.UpdateDisplay()
            
            $this.RequestRedraw()
            $this.Render()
            
            Write-Log -Level Info -Message "DashboardScreen initialized with NCurses architecture"
        }
    }

BuildMainMenu() {
        try {
            # Capture the screen instance ($this) into a local variable. The scriptblocks
            # below will form a closure over this variable, giving them access to the screen's services.
            $screen_this = $this
            
            $this.MainMenu.AddItem([NavigationItem]::new("1", "Task Management", {
                $screen_this.Services.Navigation.GoTo("/tasks", @{})
            }))
            $this.MainMenu.AddItem([NavigationItem]::new("2", "Project Management", {
                # This action is not yet implemented, so we'll show a dialog.
                Show-AlertDialog -Title "Not Implemented" -Message "Project Management screen is coming soon!"
            }))
            $this.MainMenu.AddItem([NavigationItem]::new("3", "Settings", {
                # This action is not yet implemented, so we'll show a dialog.
                Show-AlertDialog -Title "Not Implemented" -Message "Settings screen is coming soon!"
            }))
            $this.MainMenu.AddSeparator()
            $this.MainMenu.AddItem([NavigationItem]::new("Q", "Quit Application", {
                 $screen_this.Services.Navigation.RequestExit()
            }))
            
            Write-Log -Level Debug -Message "Main menu built with $($this.MainMenu.Items.Count) items"
        } catch {
            Write-Log -Level Error -Message "Failed to build main menu: $_"
        }
    }

RefreshData() {
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "RefreshData" -ScriptBlock {
            $this.Tasks = @()
            $this.TotalTasks = 0
            $this.CompletedTasks = 0
            $this.PendingTasks = 0
            
            if ($null -eq $this.Services.DataManager) {
                Write-Log -Level Warning -Message "DataManager service not available"
                return
            }
            
            try {
                $this.Tasks = @($this.Services.DataManager.GetTasks())
                $this.TotalTasks = $this.Tasks.Count
                
                if ($this.TotalTasks -gt 0) {
                    $completedTasks = @($this.Tasks | Where-Object { $_.Status -eq [TaskStatus]::Completed })
                    $this.CompletedTasks = $completedTasks.Count
                    $this.PendingTasks = $this.TotalTasks - $this.CompletedTasks
                }
                
                Write-Log -Level Debug -Message "Dashboard data refreshed - $($this.TotalTasks) tasks loaded"
            } catch {
                Write-Log -Level Warning -Message "Failed to load tasks: $_"
                $this.Tasks = @()
            }
        }
    }

UpdateDisplay() {
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "UpdateDisplay" -ScriptBlock {
            $this.UpdateSummaryPanel()
            $this.SummaryPanel.RequestRedraw()
            
            $this.UpdateStatusPanel()
            $this.StatusPanel.RequestRedraw()
            
            $this.MenuPanel.RequestRedraw()
            
            $this.RequestRedraw()
        }
    }

UpdateSummaryPanel() {
        if ($null -eq $this.SummaryPanel) { return }
        
        $this.ClearPanelContent($this.SummaryPanel)
        
        $summaryLines = @(
            "Task Overview",
            "═══════════════",
            "",
            "Total Tasks:    $($this.TotalTasks)",
            "Completed:      $($this.CompletedTasks)",
            "Pending:        $($this.PendingTasks)",
            "",
            "Progress: $($this.GetProgressBar())",
            "",
            "Use number keys or",
            "arrow keys + Enter"
        )
        
        for ($i = 0; $i -lt $summaryLines.Count; $i++) {
            $color = if ($i -eq 0) { [ConsoleColor]::White } elseif ($i -eq 1) { [ConsoleColor]::Gray } else { [ConsoleColor]::Cyan }
            $this.WriteTextToPanel($this.SummaryPanel, $summaryLines[$i], 1, $i, $color)
        }
        
        $this.SummaryPanel.RequestRedraw()
    }

UpdateStatusPanel() {
        if ($null -eq $this.StatusPanel) { return }
        
        $this.ClearPanelContent($this.StatusPanel)
        
        $statusLines = @(
            "System Information",
            "════════════════════",
            "",
            "PowerShell Version: $($global:PSVersionTable.PSVersion)",
            "Platform:           $($global:PSVersionTable.Platform)",
            "Memory Usage:       $($this.GetMemoryUsage())",
            "Current Time:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        )
        
        for ($i = 0; $i -lt $statusLines.Count; $i++) {
            $color = if ($i -eq 0) { [ConsoleColor]::White } elseif ($i -eq 1) { [ConsoleColor]::Gray } else { [ConsoleColor]::Green }
            $this.WriteTextToPanel($this.StatusPanel, $statusLines[$i], 1, $i, $color)
        }
        
        $this.StatusPanel.RequestRedraw()
    }

GetProgressBar() {
        if ($this.TotalTasks -eq 0) { return "No tasks" }
        
        $percentage = [Math]::Round(($this.CompletedTasks / $this.TotalTasks) * 100)
        $barLength = 20
        $filledLength = [Math]::Round(($percentage / 100) * $barLength)
        $bar = "█" * $filledLength + "░" * ($barLength - $filledLength)
        return "$bar $percentage%"
    }

GetMemoryUsage() {
        try {
            $process = Get-Process -Id $global:PID
            $memoryMB = [Math]::Round($process.WorkingSet64 / 1MB, 2)
            return "$memoryMB MB"
        } catch {
            return "Unknown"
        }
    }

ClearPanelContent([Panel]$panel) {
        if ($null -eq $panel -or $null -eq $panel.{_private_buffer}) { return }
        
        $clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, $panel.BackgroundColor)
        for ($y = $panel.ContentY; $y -lt ($panel.ContentY + $panel.ContentHeight); $y++) {
            for ($x = $panel.ContentX; $x -lt ($panel.ContentX + $panel.ContentWidth); $x++) {
                $panel.{_private_buffer}.SetCell($x, $y, $clearCell)
            }
        }
    }

WriteTextToPanel([Panel]$panel, [string]$text, [int]$x, [int]$y, [ConsoleColor]$color) {
        if ($null -eq $panel -or $null -eq $panel.{_private_buffer}) { return }
        if ($y -ge $panel.ContentHeight) { return }
        
        $chars = $text.ToCharArray()
        for ($i = 0; $i -lt $chars.Length -and ($x + $i) -lt $panel.ContentWidth; $i++) {
            $cell = [TuiCell]::new($chars[$i], $color, $panel.BackgroundColor)
            $panel.{_private_buffer}.SetCell($panel.ContentX + $x + $i, $panel.ContentY + $y, $cell)
        }
    }

HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # This handler is now simplified. The TUI engine will automatically
        # route arrow keys/enter to the focused component (the MainMenu).
        # This handler only needs to process screen-specific shortcuts.
        $self = $this
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "HandleInput" -ScriptBlock {
            $keyChar = $keyInfo.KeyChar.ToString().ToUpper()
            
            # Screen-level shortcuts for convenience
            if ($keyChar -match '^[123Q]$') {
                $self.MainMenu.ExecuteAction($keyChar)
                return $true
            }
            
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Escape) {
                    $self.Services.Navigation.RequestExit()
                    return $true
                }
                ([ConsoleKey]::F5) {
                    $self.RefreshData()
                    $self.UpdateDisplay()
                    return $true
                }
            }
        }
        # Return $false because this screen-level handler did not consume the key.
        # This allows the TUI engine to know the key is available for other layers if needed.
        return $false
    }

OnEnter() {
        $this.RefreshData()
        $this.UpdateDisplay()
        
        # Set the initial focus to the MainMenu. This is critical for
        # allowing the menu to receive and handle arrow key/enter input.
        Set-ComponentFocus -Component $this.MainMenu
    }

OnExit() { }

OnDeactivate() {
        $this.Cleanup()
    }

Cleanup() {
        $this.Components.Clear()
        $this.Children.Clear()
    }

TaskListScreen([hashtable]$services) : base("TaskListScreen", $services) {
        $this.Name = "TaskListScreen"
        $this.Components = [System.Collections.Generic.List[UIElement]]::new()
        $this.IsFocusable = $true
        $this.Enabled = $true
        $this.Visible = $true
    }

Initialize() {
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "Initialize" -ScriptBlock {
            $this.Width = $global:TuiState.BufferWidth
            $this.Height = $global:TuiState.BufferHeight
            
            if ($null -ne $this.{_private_buffer}) {
                $this.{_private_buffer}.Resize($this.Width, $this.Height)
            }
            
            $this.MainPanel = [Panel]::new(0, 0, $this.Width, $this.Height, "Task List")
            $this.MainPanel.HasBorder = $true
            $this.MainPanel.BorderStyle = "Double"
            $this.MainPanel.BorderColor = [ConsoleColor]::Gray
            $this.MainPanel.BackgroundColor = [ConsoleColor]::Black
            $this.MainPanel.Name = "MainTaskPanel"
            $this.AddChild($this.MainPanel)
            
            $this.HeaderPanel = [Panel]::new(1, 1, $this.Width - 2, 3, "")
            $this.HeaderPanel.HasBorder = $false
            $this.HeaderPanel.BackgroundColor = [ConsoleColor]::Black
            $this.HeaderPanel.Name = "HeaderPanel"
            $this.MainPanel.AddChild($this.HeaderPanel)
            
            $this.TablePanel = [Panel]::new(1, 4, $this.Width - 2, $this.Height - 8, "")
            $this.TablePanel.HasBorder = $true
            $this.TablePanel.BorderStyle = "Single"
            $this.TablePanel.BorderColor = [ConsoleColor]::DarkGray
            $this.TablePanel.BackgroundColor = [ConsoleColor]::Black
            $this.TablePanel.Name = "TablePanel"
            $this.MainPanel.AddChild($this.TablePanel)
            
            $this.FooterPanel = [Panel]::new(1, $this.Height - 4, $this.Width - 2, 3, "")
            $this.FooterPanel.HasBorder = $false
            $this.FooterPanel.BackgroundColor = [ConsoleColor]::Black
            $this.FooterPanel.Name = "FooterPanel"
            $this.MainPanel.AddChild($this.FooterPanel)
            
            $this.TaskTable = [Table]::new("TaskTable")
            $this.TaskTable.Move(0, 0)
            $this.TaskTable.Resize($this.TablePanel.ContentWidth, $this.TablePanel.ContentHeight)
            $this.TaskTable.ShowBorder = $false

            $columns = @(
                [TableColumn]::new('Title', 'Task Title', 50),
                [TableColumn]::new('Status', 'Status', 15),
                [TableColumn]::new('Priority', 'Priority', 12),
                [TableColumn]::new('DueDate', 'Due Date', 15)
            )
            $this.TaskTable.SetColumns($columns)
            
            $this.TablePanel.AddChild($this.TaskTable)
            
            $this.RefreshData()
            $this.UpdateDisplay()
            
            $this.RequestRedraw()
            $this.Render()
        }
    }

RefreshData() {
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "RefreshData" -ScriptBlock {
            try {
                $this.AllTasks = @($this.Services.DataManager.GetTasks())
                if ($null -eq $this.AllTasks) { $this.AllTasks = @() }
            } catch {
                Write-Log -Level Warning -Message "Failed to load tasks: $_"
                $this.AllTasks = @()
            }
            
            $filterResult = switch ($this.FilterStatus) {
                "Active" { $this.AllTasks | Where-Object { $_.Status -ne [TaskStatus]::Completed } }
                "Completed" { $this.AllTasks | Where-Object { $_.Status -eq [TaskStatus]::Completed } }
                default { $this.AllTasks }
            }
            
            $this.FilteredTasks = [System.Collections.ArrayList]::new()
            if ($null -ne $filterResult) {
                if ($filterResult -is [array]) {
                    foreach ($item in $filterResult) { $this.FilteredTasks.Add($item) | Out-Null }
                } else {
                    $this.FilteredTasks.Add($filterResult) | Out-Null
                }
            }
            
            $this.TaskTable.SetData($this.FilteredTasks)
            
            if ($null -ne $this.FilteredTasks -and $this.SelectedIndex -ge $this.FilteredTasks.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.FilteredTasks.Count - 1)
            }
            
            $this.RequestRedraw()
        }
    }

UpdateDisplay() {
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "UpdateDisplay" -ScriptBlock {
            $taskCount = if ($null -ne $this.FilteredTasks) { $this.FilteredTasks.Count } else { 0 }
            $headerText = "Filter: $($this.FilterStatus) | Total: $taskCount tasks"
            $this.WriteTextToPanel($this.HeaderPanel, $headerText, 0, 0, [ConsoleColor]::White)
            $this.HeaderPanel.RequestRedraw()
            
            $footerText = "[↑↓]Navigate [Space]Toggle [N]ew [E]dit [D]elete [F]ilter [Esc]Back"
            $this.WriteTextToPanel($this.FooterPanel, $footerText, 0, 0, [ConsoleColor]::Yellow)
            $this.FooterPanel.RequestRedraw()
            
            $this.TaskTable.SelectedIndex = $this.SelectedIndex
            
            $this.RequestRedraw()
        }
    }

WriteTextToPanel([Panel]$panel, [string]$text, [int]$x, [int]$y, [ConsoleColor]$color) {
        if ($null -eq $panel -or $null -eq $panel.{_private_buffer}) { return }
        $chars = $text.ToCharArray()
        for ($i = 0; $i -lt $chars.Length -and ($x + $i) -lt $panel.ContentWidth; $i++) {
            $cell = [TuiCell]::new($chars[$i], $color, $panel.BackgroundColor)
            $panel.{_private_buffer}.SetCell($panel.ContentX + $x + $i, $panel.ContentY + $y, $cell)
        }
    }

HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Capture the screen instance ($this) into a local variable so the
        # scriptblock passed to Invoke-WithErrorHandling can access it.
        $self = $this
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "HandleInput" -ScriptBlock {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.SelectedIndex -gt 0) {
                        $self.SelectedIndex--
                        $self.UpdateDisplay()
                        return $true
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.SelectedIndex -lt ($self.FilteredTasks.Count - 1) -and $self.FilteredTasks.Count -gt 0) {
                        $self.SelectedIndex++
                        $self.UpdateDisplay()
                        return $true
                    }
                }
                ([ConsoleKey]::Spacebar) {
                    $self.ToggleSelectedTask()
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    $self.NavigateBack()
                    return $true
                }
                default {
                    $keyChar = $keyInfo.KeyChar.ToString().ToUpper()
                    switch ($keyChar) {
                        'N' { $self.ShowNewTaskDialog(); return $true }
                        'E' { $self.EditSelectedTask(); return $true }
                        'D' { $self.DeleteSelectedTask(); return $true }
                        'F' { $self.CycleFilter(); return $true }
                    }
                }
            }
        }
        return $false
    }

ToggleSelectedTask() {
        if ($this.FilteredTasks.Count -eq 0 -or $this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $this.FilteredTasks.Count) { return }
        $task = $this.FilteredTasks[$this.SelectedIndex]
        if ($null -eq $task) { return }
        $newCompletedStatus = $task.Status -ne [TaskStatus]::Completed
        $this.Services.DataManager.UpdateTask(@{ Task = $task; Completed = $newCompletedStatus })
        $this.RefreshData()
        $this.UpdateDisplay()
    }

ShowNewTaskDialog() {
        # Capture necessary context for the dialog's callback scriptblock.
        $dataManager = $this.Services.DataManager
        $screen = $this
        Show-InputDialog -Title "New Task" -Prompt "Enter task title:" -OnSubmit {
            param($Value)
            if (-not [string]::IsNullOrWhiteSpace($Value)) {
                $dataManager.AddTask($Value, "", "medium", "General")
                $screen.RefreshData()
                $screen.UpdateDisplay()
            }
        }
    }

EditSelectedTask() {
        if ($null -eq $this.FilteredTasks -or $this.FilteredTasks.Count -eq 0 -or $this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $this.FilteredTasks.Count) { return }
        $task = $this.FilteredTasks[$this.SelectedIndex]
        if ($null -eq $task) { return }
        # Capture necessary context for the dialog's callback scriptblock.
        $dataManager = $this.Services.DataManager
        $screen = $this
        Show-InputDialog -Title "Edit Task" -Prompt "New title:" -DefaultValue $task.Title -OnSubmit {
            param($Value)
            if (-not [string]::IsNullOrWhiteSpace($Value)) {
                $dataManager.UpdateTask(@{ Task = $task; Title = $Value })
                $screen.RefreshData()
                $screen.UpdateDisplay()
            }
        }
    }

DeleteSelectedTask() {
        if ($null -eq $this.FilteredTasks -or $this.FilteredTasks.Count -eq 0 -or $this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $this.FilteredTasks.Count) { return }
        $task = $this.FilteredTasks[$this.SelectedIndex]
        if ($null -eq $task) { return }
        # Capture necessary context for the dialog's callback scriptblock.
        $dataManager = $this.Services.DataManager
        $screen = $this
        Show-ConfirmDialog -Title "Delete Task" -Message "Are you sure you want to delete `"$($task.Title)`"?" -OnConfirm {
            $dataManager.RemoveTask($task)
            $screen.RefreshData()
            $screen.UpdateDisplay()
        }
    }

CycleFilter() {
        $this.FilterStatus = switch ($this.FilterStatus) {
            "All" { "Active" }
            "Active" { "Completed" }
            default { "All" }
        }
        $this.RefreshData()
        $this.UpdateDisplay()
    }

NavigateBack() {
        $this.Services.Navigation.PopScreen()
    }

OnEnter() {
        $this.RefreshData()
        $this.UpdateDisplay()
    }

OnExit() { }

Cleanup() {
        $this.Components.Clear()
        $this.Children.Clear()
    }

ScreenFactory([hashtable]$services) {
        $this.Services = $services ?? (throw [System.ArgumentNullException]::new("services"))
        Write-Log -Level Debug -Message "ScreenFactory initialized"
    }

RegisterScreen([string]$name, [type]$screenType) {
        if (-not ($screenType -eq [Screen] -or $screenType.IsSubclassOf([Screen]))) { 
            throw "Screen type '$($screenType.Name)' must inherit from the Screen class." 
        }
        $this.ScreenTypes[$name] = $screenType
        Write-Log -Level Info -Message "Registered screen factory: $name -> $($screenType.Name)"
    }

CreateScreen([string]$screenName, [hashtable]$parameters) {
        $screenType = $this.ScreenTypes[$screenName]
        if (-not $screenType) {
            throw "Unknown screen type: '$screenName'. Available screens: $($this.ScreenTypes.Keys -join ', ')"
        }
        
        try {
            $screen = $screenType::new($this.Services)
            if ($parameters) {
                foreach ($key in $parameters.Keys) { 
                    $screen.State[$key] = $parameters[$key] 
                }
            }
            Write-Log -Level Info -Message "Created screen: $screenName"
            return $screen
        } catch {
            Write-Log -Level Error -Message "Failed to create screen '$screenName': $($_.Exception.Message)"
            throw
        }
    }

GetRegisteredScreens() {
        return @($this.ScreenTypes.Keys)
    }

NavigationService([hashtable]$services) {
        $this.Services = $services ?? (throw [System.ArgumentNullException]::new("services"))
        $this.ScreenStack = [System.Collections.Generic.Stack[Screen]]::new()
        $this.ScreenFactory = [ScreenFactory]::new($services)
        $this.InitializeRoutes()
        Write-Log -Level Info -Message "NavigationService initialized"
    }

InitializeRoutes() {
        $this.RouteMap = @{
            "/" = "DashboardScreen"
            "/dashboard" = "DashboardScreen"
            "/tasks" = "TaskListScreen"
        }
        Write-Log -Level Debug -Message "Routes initialized: $($this.RouteMap.Keys -join ', ')"
    }

RegisterScreenClass([string]$name, [type]$screenType) {
        $this.ScreenFactory.RegisterScreen($name, $screenType)
    }

GoTo([string]$path, [hashtable]$parameters = @{}) {
        Invoke-WithErrorHandling -Component "NavigationService" -Context "GoTo:$path" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($path)) { 
                throw [System.ArgumentException]::new("Path cannot be empty.") 
            }
            if ($path -eq "/exit") { 
                $this.RequestExit()
                return 
            }
            
            $screenName = $this.RouteMap[$path]
            if (-not $screenName) {
                $availableRoutes = $this.RouteMap.Keys -join ', '
                throw "Unknown route: '$path'. Available routes: $availableRoutes"
            }
            
            Write-Log -Level Info -Message "Navigating to: $path -> $screenName"
            $this.PushScreen($screenName, $parameters)
        }
    }

PushScreen([string]$screenName, [hashtable]$parameters = @{}) {
        Invoke-WithErrorHandling -Component "NavigationService" -Context "PushScreen:$screenName" -ScriptBlock {
            Write-Log -Level Info -Message "Pushing screen: $screenName"
            
            if ($this.CurrentScreen) {
                Write-Log -Level Debug -Message "Exiting current screen: $($this.CurrentScreen.Name)"
                $this.CurrentScreen.OnExit()
                $this.ScreenStack.Push($this.CurrentScreen)
            }
            
            Write-Log -Level Debug -Message "Creating new screen: $screenName"
            $newScreen = $this.ScreenFactory.CreateScreen($screenName, $parameters)
            $this.CurrentScreen = $newScreen
            
            Write-Log -Level Debug -Message "Initializing screen: $screenName"
            $newScreen.Initialize()
            $newScreen.OnEnter()
            
            if (Get-Command "Push-Screen" -ErrorAction SilentlyContinue) {
                Write-Log -Level Debug -Message "Pushing screen to TUI engine"
                Push-Screen -Screen $newScreen
            } else {
                if ($global:TuiState) {
                    $global:TuiState.CurrentScreen = $newScreen
                    Request-TuiRefresh
                }
            }
            
            Publish-Event -EventName "Navigation.ScreenChanged" -Data @{ Screen = $screenName; Action = "Push" }
            Write-Log -Level Info -Message "Successfully pushed screen: $screenName"
        }
    }

PopScreen() {
        return Invoke-WithErrorHandling -Component "NavigationService" -Context "PopScreen" -ScriptBlock {
            if ($this.ScreenStack.Count -eq 0) { 
                Write-Log -Level Warning -Message "Cannot pop screen: stack is empty"
                return $false 
            }
            
            Write-Log -Level Info -Message "Popping screen"
            $this.CurrentScreen?.OnExit()
            $this.CurrentScreen = $this.ScreenStack.Pop()
            $this.CurrentScreen?.OnResume()
            
            if (Get-Command "Pop-Screen" -ErrorAction SilentlyContinue) {
                Pop-Screen
            } else {
                if ($global:TuiState) {
                    $global:TuiState.CurrentScreen = $this.CurrentScreen
                    Request-TuiRefresh
                }
            }
            
            Publish-Event -EventName "Navigation.ScreenPopped" -Data @{ Screen = $this.CurrentScreen.Name }
            return $true
        }
    }

RequestExit() {
        Write-Log -Level Info -Message "Exit requested"
        while ($this.PopScreen()) {} # Pop all screens
        $this.CurrentScreen?.OnExit()
        if (Get-Command "Stop-TuiEngine" -ErrorAction SilentlyContinue) {
            Stop-TuiEngine
        }
        Publish-Event -EventName "Application.Exit"
    }

GetCurrentScreen() { return $this.CurrentScreen }

IsValidRoute([string]$path) { return $this.RouteMap.ContainsKey($path) }

ListRegisteredScreens() {
        $screens = $this.ScreenFactory.GetRegisteredScreens()
        Write-Log -Level Info -Message "Registered screens: $($screens -join ', ')"
        Write-Host "Registered screens: $($screens -join ', ')" -ForegroundColor Green
    }

ListAvailableRoutes() {
        $routes = $this.RouteMap.Keys
        Write-Log -Level Info -Message "Available routes: $($routes -join ', ')"
        Write-Host "Available routes: $($routes -join ', ')" -ForegroundColor Green
    }

function Initialize-DataManager {
    <#
    .SYNOPSIS
    Creates a new, fully initialized instance of the DataManager service.
    #>
    return [DataManager]::new()
}

DataManager() {
        $this.{_dataStore} = @{
            Projects = [System.Collections.ArrayList]::new()
            Tasks = [System.Collections.ArrayList]::new()
            TimeEntries = @()
            ActiveTimers = @{}
            TodoTemplates = @{}
            Settings = @{
                DefaultView = "Dashboard"
                Theme = "Modern"
                AutoSave = $true
                BackupCount = 5
            }
            time_entries = @() # underscore format for action compatibility
            timers = @()       # for action compatibility
        }

        $this.{_dataFilePath} = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\pmc-data.json"
        $this.{_backupPath} = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\backups"

        Invoke-WithErrorHandling -Component "DataManager.Constructor" -Context "DataManager initialization" -ScriptBlock {
            $dataDirectory = Split-Path $this.{_dataFilePath} -Parent
            if (-not (Test-Path $dataDirectory)) {
                New-Item -ItemType Directory -Path $dataDirectory -Force | Out-Null
                Write-Log -Level Info -Message "Created data directory: $dataDirectory"
            }
            
            if (-not (Test-Path $this.{_backupPath})) {
                New-Item -ItemType Directory -Path $this.{_backupPath} -Force | Out-Null
                Write-Log -Level Info -Message "Created backup directory: $($this.{_backupPath})"
            }
            
            $this.LoadData()
            $this.InitializeEventHandlers()
            
            Write-Log -Level Info -Message "DataManager initialized successfully"
        }
    }

InitializeEventHandlers() {
        # Capture the current instance ($this) into a local variable so the
        # scriptblocks below can access it.
        $local:self = $this
        Invoke-WithErrorHandling -Component "DataManager.InitializeEventHandlers" -Context "Initializing data event handlers" -ScriptBlock {
            # The handler scriptblock captures $local:self from its parent scope.
            Subscribe-Event -EventName "Tasks.RefreshRequested" -Handler {
                param($EventData)
                Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Refreshed"; Tasks = @($local:self.{_dataStore}.Tasks) }
            }
            Write-Log -Level Debug -Message "Data event handlers initialized"
        }
    }

LoadData() {
        Invoke-WithErrorHandling -Component "DataManager.LoadData" -Context "Loading unified data from disk" -ScriptBlock {
            if (Test-Path $this.{_dataFilePath}) {
                try {
                    $loadedData = Get-Content -Path $this.{_dataFilePath} -Raw | ConvertFrom-Json -AsHashtable
                    
                    if ($loadedData -is [hashtable]) {
                        if ($loadedData.Tasks) {
                            $this.{_dataStore}.Tasks.Clear()
                            foreach ($taskData in $loadedData.Tasks) {
                                if ($taskData -is [hashtable]) { 
                                    try {
                                        $task = [PmcTask]::FromLegacyFormat($taskData)
                                        $this.{_dataStore}.Tasks.Add($task) | Out-Null
                                    } catch {
                                        Write-Log -Level Warning -Message "Failed to load task: $_"
                                    }
                                }
                            }
                            Write-Log -Level Debug -Message "Loaded $($this.{_dataStore}.Tasks.Count) tasks as PmcTask objects"
                        }
                        
                        if ($loadedData.Projects -is [hashtable]) {
                            $this.{_dataStore}.Projects.Clear()
                            foreach ($projectKey in $loadedData.Projects.Keys) {
                                $projectData = $loadedData.Projects[$projectKey]
                                if ($projectData -is [hashtable]) { $this.{_dataStore}.Projects.Add([PmcProject]::FromLegacyFormat($projectData)) }
                            }
                            Write-Log -Level Debug -Message "Re-hydrated $($this.{_dataStore}.Projects.Count) projects as PmcProject objects"
                        }
                        
                        foreach ($key in 'TimeEntries', 'ActiveTimers', 'TodoTemplates', 'Settings', 'time_entries', 'timers') {
                            if ($loadedData.ContainsKey($key)) { $this.{_dataStore}[$key] = $loadedData[$key] }
                        }
                        
                        Write-Log -Level Info -Message "Data loaded successfully from disk"
                    } else {
                        Write-Log -Level Warning -Message "Invalid data format in file, using defaults"
                    }
                } catch {
                    Write-Log -Level Error -Message "Failed to parse data file: $_"
                }
            } else {
                Write-Log -Level Info -Message "No existing data file found, creating sample data"
                
                $defaultProject = [PmcProject]::new("GENERAL", "General Tasks")
                $this.{_dataStore}.Projects.Add($defaultProject)
                
                $sampleTasks = @(
                    [PmcTask]::new("Welcome to PMC Terminal!", "This is your task management system", [TaskPriority]::High, "GENERAL"),
                    [PmcTask]::new("Review the documentation", "Check out the help files to learn more", [TaskPriority]::Medium, "GENERAL"),
                    [PmcTask]::new("Create your first project", "Use the project management features", [TaskPriority]::Low, "GENERAL")
                )
                
                foreach ($task in $sampleTasks) { $this.{_dataStore}.Tasks.Add($task) }
                
                Write-Log -Level Info -Message "Created $($sampleTasks.Count) sample tasks"
                $this.SaveData()
            }
            
            $this.{_lastSaveTime} = Get-Date
        }
    }

SaveData() {
        Invoke-WithErrorHandling -Component "DataManager.SaveData" -Context "Saving unified data to disk" -ScriptBlock {
            if (Test-Path $this.{_dataFilePath}) {
                $backupName = "pmc-data_{0:yyyyMMdd_HHmmss}.json" -f (Get-Date)
                Copy-Item -Path $this.{_dataFilePath} -Destination (Join-Path $this.{_backupPath} $backupName) -Force
                
                $backups = Get-ChildItem -Path $this.{_backupPath} -Filter "pmc-data_*.json" | Sort-Object LastWriteTime -Descending
                if ($backups.Count -gt $this.{_dataStore}.Settings.BackupCount) {
                    $backups | Select-Object -Skip $this.{_dataStore}.Settings.BackupCount | Remove-Item -Force
                }
            }
            
            $dataToSave = @{
                Tasks = @($this.{_dataStore}.Tasks | ForEach-Object { $_.ToLegacyFormat() })
                Projects = @{}
                TimeEntries = $this.{_dataStore}.TimeEntries
                ActiveTimers = $this.{_dataStore}.ActiveTimers
                TodoTemplates = $this.{_dataStore}.TodoTemplates
                Settings = $this.{_dataStore}.Settings
                time_entries = $this.{_dataStore}.time_entries
                timers = $this.{_dataStore}.timers
            }
            
            foreach ($project in $this.{_dataStore}.Projects) { $dataToSave.Projects[$project.Key] = $project.ToLegacyFormat() }
            
            $dataToSave | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.{_dataFilePath} -Encoding UTF8
            $this.{_lastSaveTime} = Get-Date; $this.{_dataModified} = $false
            Write-Log -Level Debug -Message "Data saved successfully"
        }
    }

AddTask([string]$Title, [string]$Description, [string]$Priority, [string]$ProjectKey, [string]$DueDate = "") {
        return Invoke-WithErrorHandling -Component "DataManager.AddTask" -Context "Adding new task" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($Title)) { 
                throw "Task title cannot be empty"
            }
            $taskPriority = [TaskPriority]::$Priority
            $newTask = [PmcTask]::new($Title, $Description, $taskPriority, $ProjectKey)
            if ($DueDate -and $DueDate -ne "N/A") {
                try { $newTask.DueDate = [datetime]::Parse($DueDate) } catch { }
            }
            $this.{_dataStore}.Tasks.Add($newTask); $this.{_dataModified} = $true
            if ($this.{_dataStore}.Settings.AutoSave) { $this.SaveData() }
            Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Created"; TaskId = $newTask.Id; Task = $newTask }
            return $newTask
        }
    }

UpdateTask([hashtable]$UpdateParameters) {
        return Invoke-WithErrorHandling -Component "DataManager.UpdateTask" -Context "Updating task" -ScriptBlock {
            if (-not $UpdateParameters.ContainsKey('Task')) {
                throw "The 'UpdateParameters' hashtable must contain a 'Task' key with the task object to update."
            }
            $Task = $UpdateParameters.Task
            $managedTask = $this.{_dataStore}.Tasks.Find({$_.Id -eq $Task.Id})
            if (-not $managedTask) { throw "Task not found in data store" }
            
            $updatedFields = @()
            if ($UpdateParameters.ContainsKey('Title')) { $managedTask.Title = $UpdateParameters.Title.Trim(); $updatedFields += "Title" }
            if ($UpdateParameters.ContainsKey('Description')) { $managedTask.Description = $UpdateParameters.Description; $updatedFields += "Description" }
            if ($UpdateParameters.ContainsKey('Priority')) { $managedTask.Priority = [TaskPriority]::$($UpdateParameters.Priority); $updatedFields += "Priority" }
            if ($UpdateParameters.ContainsKey('Category')) { $managedTask.ProjectKey = $UpdateParameters.Category; $managedTask.Category = $UpdateParameters.Category; $updatedFields += "Category" }
            if ($UpdateParameters.ContainsKey('DueDate')) {
                try { $managedTask.DueDate = ($UpdateParameters.DueDate -and $UpdateParameters.DueDate -ne "N/A") ? [datetime]::Parse($UpdateParameters.DueDate) : $null } catch { Write-Log -Level Warning -Message "Invalid due date format: $($UpdateParameters.DueDate)" }
                $updatedFields += "DueDate"
            }
            if ($UpdateParameters.ContainsKey('Progress')) { $managedTask.UpdateProgress($UpdateParameters.Progress); $updatedFields += "Progress" }
            if ($UpdateParameters.ContainsKey('Completed')) {
                if ($UpdateParameters.Completed) { $managedTask.Complete() } else { $managedTask.Status = [TaskStatus]::Pending; $managedTask.Completed = $false; $managedTask.Progress = 0 }
                $updatedFields += "Completed"
            }
            
            $managedTask.UpdatedAt = [datetime]::Now; $this.{_dataModified} = $true
            Write-Log -Level Info -Message "Updated task $($managedTask.Id) - Fields: $($updatedFields -join ', ')"
            
            if ($this.{_dataStore}.Settings.AutoSave) { $this.SaveData() }
            
            Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Updated"; TaskId = $managedTask.Id; Task = $managedTask; UpdatedFields = $updatedFields }
            return $managedTask
        }
    }

RemoveTask([PmcTask]$Task) {
        return Invoke-WithErrorHandling -Component "DataManager.RemoveTask" -Context "Removing task" -ScriptBlock {
            $taskToRemove = $this.{_dataStore}.Tasks.Find({param($t) $t.Id -eq $Task.Id})
            if ($taskToRemove) {
                [void]$this.{_dataStore}.Tasks.Remove($taskToRemove)
                $this.{_dataModified} = $true
                Write-Log -Level Info -Message "Deleted task $($Task.Id)"
                if ($this.{_dataStore}.Settings.AutoSave) { $this.SaveData() }
                Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Deleted"; TaskId = $Task.Id; Task = $Task }
                return $true
            }
            Write-Log -Level Warning -Message "Task not found with ID $($Task.Id)"; return $false
        }
    }

GetTasks([bool]$Completed = $null, [string]$Priority = $null, [string]$Category = $null) {
        return Invoke-WithErrorHandling -Component "DataManager.GetTasks" -Context "Retrieving tasks" -ScriptBlock {
            $tasks = $this.{_dataStore}.Tasks
                        if ($null -ne $Completed) { $tasks = $tasks | Where-Object { $_.Completed -eq $Completed } }
            if ($Priority) { $priorityEnum = [TaskPriority]::$Priority; $tasks = $tasks | Where-Object { $_.Priority -eq $priorityEnum } }
            if ($Category) { $tasks = $tasks | Where-Object { $_.ProjectKey -eq $Category -or $_.Category -eq $Category } }
            return @($tasks)
        }
    }

GetProjects() { return @($this.{_dataStore}.Projects) }

GetProject([string]$Key) { return $this.{_dataStore}.Projects.Find({$_.Key -eq $Key}) }

AddProject([PmcProject]$Project) {
        return Invoke-WithErrorHandling -Component "DataManager.AddProject" -Context "Adding project" -ScriptBlock {
            if ($this.{_dataStore}.Projects.Exists({$_.Key -eq $Project.Key})) { 
                throw "Project with key '$($Project.Key)' already exists"
            }
            $this.{_dataStore}.Projects.Add($Project); $this.{_dataModified} = $true
            Write-Log -Level Info -Message "Created project '$($Project.Name)' with key $($Project.Key)"
            if ($this.{_dataStore}.Settings.AutoSave) { $this.SaveData() }
            Publish-Event -EventName "Projects.Changed" -Data @{ Action = "Created"; ProjectKey = $Project.Key; Project = $Project }
            return $Project
        }
    }

function Initialize-NavigationService {
    param([hashtable]$Services)
    if (-not $Services) { throw [System.ArgumentNullException]::new("Services") }
    return [NavigationService]::new($Services)
}

function Initialize-TuiEngine {
    param(
        [int]$Width = [Console]::WindowWidth,
        [int]$Height = [Console]::WindowHeight - 1
    )
    Write-Log -Level Info -Message "Initializing TUI Engine v5.2 (Pure Compositor): ${Width}x${Height}"
    try {
        if ($Width -le 0 -or $Height -le 0) { throw "Invalid console dimensions: ${Width}x${Height}" }
        
        $global:TuiState.BufferWidth = $Width
        $global:TuiState.BufferHeight = $Height
        
        $global:TuiState.CompositorBuffer = [TuiBuffer]::new($Width, $Height, "MainCompositor")
        $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($Width, $Height, "PreviousCompositor")
        
        [Console]::CursorVisible = $false
        [Console]::Clear()
        
        $global:TuiState.EventHandlers = @{}
        [Console]::TreatControlCAsInput = $false
        
        Subscribe-Event -EventName "TUI.RefreshRequested" -Handler {
            Request-TuiRefresh
        } -Source "TuiEngine"

        Initialize-InputThread
        
        Publish-Event -EventName "System.EngineInitialized" -Data @{ Width = $Width; Height = $Height }
        Write-Log -Level Info -Message "TUI Engine v5.2 initialized successfully"
    }
    catch {
        Write-Host "FATAL: TUI Engine initialization failed. See error details below." -ForegroundColor Red
        $_.Exception | Format-List * -Force
        throw "TUI Engine initialization failed."
    }
}

function Initialize-InputThread {
    $global:TuiState.CancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
    $token = $global:TuiState.CancellationTokenSource.Token

    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('InputQueue', $global:TuiState.InputQueue)
    $runspace.SessionStateProxy.SetVariable('token', $token)
    
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    
    $ps.AddScript({
        try {
            while (-not $token.IsCancellationRequested) {
                if ([Console]::KeyAvailable) {
                    if ($InputQueue.Count -lt 100) { $InputQueue.Enqueue([Console]::ReadKey($true)) }
                } else {
                    Start-Sleep -Milliseconds 20
                }
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] { return }
        catch { Write-Warning "Input thread error: $_" }
    }) | Out-Null
    
    $global:TuiState.InputRunspace = $runspace
    $global:TuiState.InputPowerShell = $ps
    $global:TuiState.InputAsyncResult = $ps.BeginInvoke()
}

function Process-TuiInput {
    $processedAny = $false
    $keyInfo = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::None, $false, $false, $false)
    while ($global:TuiState.InputQueue.TryDequeue([ref]$keyInfo)) {
        $processedAny = $true
        try {
            Invoke-WithErrorHandling -Component "Engine.ProcessInput" -Context "Processing single key" -ScriptBlock { Process-SingleKeyInput -keyInfo $keyInfo }
        } catch {
            Write-Log -Level Error -Message "Error processing key input: $($_.Exception.Message)" -Data $_
            Request-TuiRefresh
        }
    }
    return $processedAny
}

function Process-SingleKeyInput {
    param($keyInfo)
    
    # 1. Give the topmost overlay (e.g., a dialog) exclusive input priority.
    if ($global:TuiState.OverlayStack.Count -gt 0) {
        $topOverlay = $global:TuiState.OverlayStack[-1]
        if ($topOverlay.HandleInput($keyInfo)) {
            return # Overlay handled the input, stop processing.
        }
    }

    # 2. If no overlay handled it, check for global tab navigation.
    if ($keyInfo.Key -eq [ConsoleKey]::Tab) {
        Move-Focus -Reverse ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift)
        return
    }
    
    # 3. Give the currently focused component a chance to handle the input.
    $focusedComponent = Get-FocusedComponent
    if ($focusedComponent -and $focusedComponent.HandleInput($keyInfo)) {
        return
    }
    
    # 4. Finally, let the current screen handle the input.
    $currentScreen = $global:TuiState.CurrentScreen
    if ($currentScreen) {
        try {
            $currentScreen.HandleInput($keyInfo)
        } catch { 
            Write-Warning "Screen input handler error: $_"
            Write-Log -Level Error -Message "HandleInput failed for screen '$($currentScreen.Name)': $_"
        }
    }
}

function Start-TuiLoop {
    param([UIElement]$InitialScreen)
    try {
        if (-not $global:TuiState.BufferWidth) { Initialize-TuiEngine }
        if ($InitialScreen) { Push-Screen -Screen $InitialScreen }
        if (-not $global:TuiState.CurrentScreen) { throw "No screen available. Push a screen before calling Start-TuiLoop." }

        $global:TuiState.Running = $true
        $frameTime = [System.Diagnostics.Stopwatch]::new()
        $targetFrameTime = 1000.0 / $global:TuiState.RenderStats.TargetFPS
        
        while ($global:TuiState.Running) {
            try {
                $frameTime.Restart()
                $hadInput = Process-TuiInput
                if ($global:TuiState.IsDirty -or $hadInput) { Render-Frame; $global:TuiState.IsDirty = $false }
                $elapsed = $frameTime.ElapsedMilliseconds
                if ($elapsed -lt $targetFrameTime) { Start-Sleep -Milliseconds ([Math]::Max(1, $targetFrameTime - $elapsed)) }
            }
            catch [Helios.HeliosException] {
                Write-Log -Level Error -Message "A TUI Exception occurred: $($_.Exception.Message)" -Data $_.Exception.Context
                Show-AlertDialog -Title "Application Error" -Message "An operation failed: $($_.Exception.Message)"
                $global:TuiState.IsDirty = $true
            }
            catch {
                Write-Log -Level Error -Message "A FATAL, unhandled exception occurred: $($_.Exception.Message)" -Data $_
                Show-AlertDialog -Title "Fatal Error" -Message "A critical error occurred. The application will now close."
                $global:TuiState.Running = $false
            }
        }
    }
    finally { Cleanup-TuiEngine }
}

function Render-Frame {
    try {
        $global:TuiState.RenderStats.FrameCount++
        
        Render-FrameCompositor
        
        # After rendering, copy the current compositor state to the previous state buffer for the next frame's diff.
        $global:TuiState.PreviousCompositorBuffer.Clear()
        $global:TuiState.PreviousCompositorBuffer.BlendBuffer($global:TuiState.CompositorBuffer, 0, 0)
        
        # Position the cursor out of the way to prevent visual artifacts
        [Console]::SetCursorPosition($global:TuiState.BufferWidth - 1, $global:TuiState.BufferHeight - 1)
    } catch { 
        Write-Log -Level Error -Message "A fatal error occurred during Render-Frame: $_" -Data $_
    }
}

function Render-FrameCompositor {
    try {
        # 1. Clear the master compositor buffer
        $clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, (Get-ThemeColor "Background"))
        $global:TuiState.CompositorBuffer.Clear($clearCell)
        
        # 2. Render current screen to its private buffer, then composite
        if ($global:TuiState.CurrentScreen) {
            Invoke-WithErrorHandling -Component ($global:TuiState.CurrentScreen.Name ?? "Screen") -Context "Screen Render" -ScriptBlock {
                $global:TuiState.CurrentScreen.Render()
                $screenBuffer = $global:TuiState.CurrentScreen.GetBuffer()
                if ($null -ne $screenBuffer) {
                    $global:TuiState.CompositorBuffer.BlendBuffer($screenBuffer, 0, 0)
                }
            }
        }
        
        # 3. Render overlays (e.g., dialogs) on top of the screen
        foreach ($overlay in $global:TuiState.OverlayStack) {
            Invoke-WithErrorHandling -Component ($overlay.Name ?? "Overlay") -Context "Overlay Render" -ScriptBlock {
                $overlay.Render()
                $overlayBuffer = $overlay.GetBuffer()
                if ($null -ne $overlayBuffer) {
                    $pos = $overlay.GetAbsolutePosition()
                    $global:TuiState.CompositorBuffer.BlendBuffer($overlayBuffer, $pos.X, $pos.Y)
                }
            }
        }
        
        # 4. Convert TuiBuffer to console output with optimal diffing
        Render-CompositorToConsole
        
    } catch {
        Write-Log -Level Error -Message "Compositor rendering failed: $_" -Data $_
    }
}

function Render-CompositorToConsole {
    $outputBuilder = [System.Text.StringBuilder]::new(20000)
    $currentBuffer = $global:TuiState.CompositorBuffer
    $previousBuffer = $global:TuiState.PreviousCompositorBuffer
    $lastFG = -1; $lastBG = -1
    $forceFullRender = $global:TuiState.RenderStats.FrameCount -eq 1

    try {
        for ($y = 0; $y -lt $currentBuffer.Height; $y++) {
            $rowChanged = $false
            for ($x = 0; $x -lt $currentBuffer.Width; $x++) {
                $newCell = $currentBuffer.GetCell($x, $y)
                $oldCell = $previousBuffer.GetCell($x, $y)
                
                if ($forceFullRender -or $newCell.DiffersFrom($oldCell)) {
                    if (-not $rowChanged) {
                        [void]$outputBuilder.Append("`e[$($y + 1);1H")
                        if ($x > 0) { [void]$outputBuilder.Append("`e[$($y + 1);$($x + 1)H") }
                        $rowChanged = $true
                    }

                    if ($newCell.ForegroundColor -ne $lastFG -or $newCell.BackgroundColor -ne $lastBG) {
                        $fgCode = Get-AnsiColorCode $newCell.ForegroundColor
                        $bgCode = Get-AnsiColorCode $newCell.BackgroundColor -IsBackground $true
                        [void]$outputBuilder.Append("`e[${fgCode};${bgCode}m")
                        $lastFG = $newCell.ForegroundColor
                        $lastBG = $newCell.BackgroundColor
                    }
                    [void]$outputBuilder.Append($newCell.Char)
                } elseif ($rowChanged) {
                    [void]$outputBuilder.Append("`e[$($y + 1);$($x + 2)H")
                }
            }
        }
        
        if ($lastFG -ne -1) { [void]$outputBuilder.Append("`e[0m") }
        
        if ($outputBuilder.Length -gt 10) {
            [Console]::Write($outputBuilder.ToString())
        }
    } catch {
        Write-Log -Level Error -Message "Compositor-to-console rendering failed: $_" -Data $_
    }
}

function Request-TuiRefresh { $global:TuiState.IsDirty = $true }

function Cleanup-TuiEngine {
    try {
        try { $global:TuiState.CancellationTokenSource?.Cancel() } catch { }
        $global:TuiState.InputPowerShell?.EndInvoke($global:TuiState.InputAsyncResult)
        $global:TuiState.InputPowerShell?.Dispose()
        $global:TuiState.InputRunspace?.Dispose()
        $global:TuiState.CancellationTokenSource?.Dispose()
        
        Stop-AllTuiAsyncJobs
        
        foreach ($handlerId in $global:TuiState.EventHandlers.Values) { try { Unsubscribe-Event -HandlerId $handlerId } catch {} }
        $global:TuiState.EventHandlers.Clear()
        
        if ($Host.Name -ne 'Visual Studio Code Host') {
            [Console]::Write("`e[0m"); [Console]::CursorVisible = $true; [Console]::Clear(); [Console]::ResetColor()
        }
    } catch { Write-Warning "A secondary error occurred during TUI cleanup: $_" }
}

function Push-Screen {
    param([UIElement]$Screen)
    if (-not $Screen) { return }
    
    Write-Log -Level Debug -Message "Pushing screen: $($Screen.Name)"
    
    try {
        $global:TuiState.FocusedComponent?.OnBlur()
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.OnExit()
            $global:TuiState.ScreenStack.Push($global:TuiState.CurrentScreen)
        }
        $global:TuiState.CurrentScreen = $Screen
        $global:TuiState.FocusedComponent = $null
        
        if ($Screen.Width -eq 10 -and $Screen.Height -eq 3) { # Default size
            $Screen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)
        }
        
        # Call OnEnter lifecycle method
        if ($Screen -is [Screen] -or $Screen.GetType().GetMethod("OnEnter")) {
            $Screen.OnEnter()
        }
        
        $Screen.RequestRedraw()
        
        Request-TuiRefresh
        Publish-Event -EventName "Screen.Pushed" -Data @{ ScreenName = $Screen.Name }
    } catch { 
        Write-Warning "Push screen error: $_"
        Write-Log -Level Error -Message "Failed to push screen '$($Screen.Name)': $_"
    }
}

function Pop-Screen {
    if ($global:TuiState.ScreenStack.Count -eq 0) { return $false }
    Write-Log -Level Debug -Message "Popping screen"
    try {
        $global:TuiState.FocusedComponent?.OnBlur()
        $screenToExit = $global:TuiState.CurrentScreen
        $global:TuiState.CurrentScreen = $global:TuiState.ScreenStack.Pop()
        $global:TuiState.FocusedComponent = $null
        
        $screenToExit?.OnExit()
        $global:TuiState.CurrentScreen?.OnResume()
        if ($global:TuiState.CurrentScreen.LastFocusedComponent) { Set-ComponentFocus -Component $global:TuiState.CurrentScreen.LastFocusedComponent }
        
        Request-TuiRefresh
        Publish-Event -EventName "Screen.Popped" -Data @{ ScreenName = $global:TuiState.CurrentScreen.Name }
        return $true
    } catch { Write-Warning "Pop screen error: $_"; return $false }
}

function Close-TopTuiOverlay {
    if ($global:TuiState.OverlayStack.Count > 0) {
        $global:TuiState.OverlayStack.RemoveAt($global:TuiState.OverlayStack.Count - 1)
        Request-TuiRefresh
    }
}

function Find-Focusable([UIElement]$Comp) {
        if ($Comp.IsFocusable -and $Comp.Visible -and $Comp.Enabled) {
            $focusableComponents.Add($Comp)
        }
        foreach ($child in $Comp.Children) { Find-Focusable $child }
    }

function Move-Focus { param([bool]$Reverse = $false); $next = Get-NextFocusableComponent -CurrentComponent $global:TuiState.FocusedComponent -Reverse $Reverse; if ($next) { Set-ComponentFocus -Component $next } }

function Stop-AllTuiAsyncJobs { Write-Log -Level Debug -Message "Stopping all TUI async jobs (none currently active)" }

function Stop-TuiEngine { Write-Log -Level Info -Message "Stop-TuiEngine called"; $global:TuiState.Running = $false; $global:TuiState.CancellationTokenSource?.Cancel(); Publish-Event -EventName "System.Shutdown" }

function Stop-TuiLoop { Stop-TuiEngine }

function Invoke-TuiMethod {
    <# .SYNOPSIS Safely invokes a method on a TUI component. #>
    param(
        [Parameter(Mandatory)] [hashtable]$Component,
        [Parameter(Mandatory)] [string]$MethodName,
        [Parameter()] [hashtable]$Arguments = @{}
    )
    if (-not $Component) { return }
    $method = $Component[$MethodName]
    if (-not ($method -is [scriptblock])) { return }

    $Arguments['self'] = $Component
    Invoke-WithErrorHandling -Component "$($Component.Name ?? $Component.Type).$MethodName" -Context "Invoking component method" -ScriptBlock { & $method @Arguments }
}

function Initialize-TuiFramework {
    Invoke-WithErrorHandling -Component "TuiFramework.Initialize" -Context "Initializing framework" -ScriptBlock {
        if (-not $global:TuiState) { throw "TUI Engine must be initialized before the TUI Framework." }
        Write-Log -Level Info -Message "TUI Framework initialized."
    }
}

function Invoke-TuiAsync {
    <# .SYNOPSIS Executes a script block asynchronously with job management. #>
    param(
        [Parameter(Mandatory)] [scriptblock]$ScriptBlock,
        [string]$JobName = "TuiAsyncJob_$(Get-Random)",
        [hashtable]$ArgumentList = @{}
    )
    Invoke-WithErrorHandling -Component "TuiFramework.Async" -Context "Starting async job: $JobName" -ScriptBlock {
        $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -Name $JobName
        $script:TuiAsyncJobs += $job
        Write-Log -Level Debug -Message "Started async job: $JobName" -Data @{ JobId = $job.Id }
        return $job
    }
}

function Stop-AllTuiAsyncJobs {
    Invoke-WithErrorHandling -Component "TuiFramework.StopAsync" -Context "Stopping all async jobs" -ScriptBlock {
        foreach ($job in $script:TuiAsyncJobs) {
            try {
                Stop-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                Write-Log -Level Debug -Message "Stopped async job: $($job.Name)"
            } catch {
                Write-Log -Level Warning -Message "Failed to stop job $($job.Name): $_"
            }
        }
        $script:TuiAsyncJobs = @()
        Write-Log -Level Info -Message "All TUI async jobs stopped."
    }
}

function Test-TuiState {
    param([switch]$ThrowOnError)
    $isValid = $global:TuiState -and $global:TuiState.Running -and $global:TuiState.CurrentScreen
    if (-not $isValid -and $ThrowOnError) { throw "TUI state is not properly initialized. Call Initialize-TuiEngine first." }
    return $isValid
}

