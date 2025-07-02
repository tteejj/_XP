# Data Manager Module - Fixed for dot-sourcing
Set-StrictMode -Version Latest

$script:Data = @{
    Projects = New-Object System.Collections.ArrayList
    Tasks = New-Object System.Collections.ArrayList
    TimeEntries = @()
    ActiveTimers = @{}
    TodoTemplates = @{}
    Settings = @{
        DefaultView = "Dashboard"
        Theme = "Modern"
        AutoSave = $true
        BackupCount = 5
    }
    time_entries = @()
    timers = @()
}

$script:DataPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\pmc-data.json"
$script:BackupPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\backups"
$script:LastSaveTime = $null
$script:DataModified = $false

function Initialize-DataManager {
    [CmdletBinding()]
    param()
    
    $dataDirectory = Split-Path $script:DataPath -Parent
    if (-not (Test-Path $dataDirectory)) {
        New-Item -ItemType Directory -Path $dataDirectory -Force | Out-Null
        Write-Log -Level Info -Message "Created data directory: $dataDirectory"
    }
    
    if (-not (Test-Path $script:BackupPath)) {
        New-Item -ItemType Directory -Path $script:BackupPath -Force | Out-Null
        Write-Log -Level Info -Message "Created backup directory: $script:BackupPath"
    }
    
    Load-UnifiedData
    Initialize-DataEventHandlers
    
    Write-Log -Level Info -Message "DataManager initialized successfully"
    
    # Return object that DataManager class would have created
    return [PSCustomObject]@{
        PSTypeName = 'DataManager'
        DataStore = $script:Data
        DataFilePath = $script:DataPath
        AutoSaveEnabled = $script:Data.Settings.AutoSave
    }
}

function Load-UnifiedData {
    [CmdletBinding()]
    param()
    
    if (Test-Path $script:DataPath) {
        try {
            $loadedData = Get-Content -Path $script:DataPath -Raw | ConvertFrom-Json -AsHashtable
            
            if ($loadedData -is [hashtable]) {
                if ($loadedData.Tasks) {
                    $script:Data.Tasks.Clear()
                    foreach ($taskData in $loadedData.Tasks) {
                        if ($taskData -is [hashtable]) {
                            $script:Data.Tasks.Add($taskData) | Out-Null
                        }
                    }
                    Write-Log -Level Debug -Message "Loaded $($script:Data.Tasks.Count) tasks"
                }
                
                if ($loadedData.Projects -is [hashtable]) {
                    $script:Data.Projects.Clear()
                    foreach ($projectKey in $loadedData.Projects.Keys) {
                        $projectData = $loadedData.Projects[$projectKey]
                        if ($projectData -is [hashtable]) {
                            $script:Data.Projects.Add($projectData) | Out-Null
                        }
                    }
                    Write-Log -Level Debug -Message "Loaded $($script:Data.Projects.Count) projects"
                }
                
                foreach ($key in 'TimeEntries', 'ActiveTimers', 'TodoTemplates', 'Settings', 'time_entries', 'timers') {
                    if ($loadedData.ContainsKey($key)) {
                        $script:Data[$key] = $loadedData[$key]
                    }
                }
                
                $global:Data = $script:Data
                Write-Log -Level Info -Message "Data loaded successfully from disk"
            } else {
                Write-Log -Level Warning -Message "Invalid data format in file, using defaults"
                $global:Data = $script:Data
            }
        } catch {
            Write-Log -Level Error -Message "Failed to parse data file: $_"
            $global:Data = $script:Data
        }
    } else {
        Write-Log -Level Info -Message "No existing data file found, using defaults"
        $global:Data = $script:Data
    }
    
    $script:LastSaveTime = Get-Date
}

function Save-UnifiedData {
    [CmdletBinding()]
    param()
    
    if (Test-Path $script:DataPath) {
        $backupName = "pmc-data_{0:yyyyMMdd_HHmmss}.json" -f (Get-Date)
        Copy-Item -Path $script:DataPath -Destination (Join-Path $script:BackupPath $backupName) -Force
        
        $backups = Get-ChildItem -Path $script:BackupPath -Filter "pmc-data_*.json" | Sort-Object LastWriteTime -Descending
        if ($backups.Count -gt $script:Data.Settings.BackupCount) {
            $backups | Select-Object -Skip $script:Data.Settings.BackupCount | Remove-Item -Force
        }
    }
    
    $dataToSave = @{
        Tasks = @($script:Data.Tasks)
        Projects = @{}
        TimeEntries = $script:Data.TimeEntries
        ActiveTimers = $script:Data.ActiveTimers
        TodoTemplates = $script:Data.TodoTemplates
        Settings = $script:Data.Settings
        time_entries = $script:Data.time_entries
        timers = $script:Data.timers
    }
    
    foreach ($project in $script:Data.Projects) {
        if ($project.Key) {
            $dataToSave.Projects[$project.Key] = $project
        }
    }
    
    $dataToSave | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:DataPath -Encoding UTF8
    $script:LastSaveTime = Get-Date
    $script:DataModified = $false
    Write-Log -Level Debug -Message "Data saved successfully"
}

function Initialize-DataEventHandlers {
    Subscribe-Event -EventName "Tasks.RefreshRequested" -Handler {
        Publish-Event -EventName "Tasks.Changed" -Data @{
            Action = "Refreshed"
            Tasks = @($script:Data.Tasks)
        }
    }
    Write-Log -Level Debug -Message "Data event handlers initialized"
}

# Simple stub functions for now
function Add-PmcTask { param($Title) Write-Host "Add-PmcTask: $Title" }
function Update-PmcTask { param($Task) Write-Host "Update-PmcTask" }
function Remove-PmcTask { param($Task) Write-Host "Remove-PmcTask" }
function Get-PmcTasks { return @($script:Data.Tasks) }
function Get-PmcProjects { return @($script:Data.Projects) }
function Get-PmcProject { param($Key) return $null }
function Add-PmcProject { param($Project) Write-Host "Add-PmcProject" }
