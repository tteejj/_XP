# Data Manager Module
# Unified data persistence and CRUD operations with event integration

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Module-level state variables
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
    }
    
    if (-not (Test-Path $script:BackupPath)) {
        New-Item -ItemType Directory -Path $script:BackupPath -Force | Out-Null
    }
    
    # Return a simple object for now
    return [PSCustomObject]@{
        PSTypeName = 'DataManager'
        LoadData = { Load-UnifiedData }
        SaveData = { Save-UnifiedData }
    }
}

function Load-UnifiedData {
    Write-Host "Load-UnifiedData called"
}

function Save-UnifiedData {
    Write-Host "Save-UnifiedData called"
}

# Export functions
# Export-ModuleMember -Function *  # This breaks dot-sourcing!
