# DataManager Class Definition
# Split from data-manager.psm1 to resolve class dependency issues

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

class DataManager {
    hidden [hashtable] $DataStore
    hidden [string] $DataFilePath
    hidden [bool] $AutoSaveEnabled = $true
    
    DataManager() {
        $this.DataStore = $script:Data
        $global:Data = $script:Data
        $this.DataFilePath = $script:DataPath
        $this.AutoSaveEnabled = $this.DataStore.Settings.AutoSave
    }

    [void] LoadData() { Load-UnifiedData }
    [void] SaveData() { Save-UnifiedData }
    
    [PmcTask] AddTask([string]$Title, [string]$Description, [string]$Priority, [string]$ProjectKey) { 
        return Add-PmcTask -Title $Title -Description $Description -Priority $Priority -Category $ProjectKey 
    }

    # AI: FIX - Changed method to accept a hashtable for flexible updates via splatting.
    [PmcTask] UpdateTask([hashtable]$UpdateParameters) {
        if (-not $UpdateParameters.ContainsKey('Task')) {
            throw [System.ArgumentException]::new("The 'UpdateParameters' hashtable must contain a 'Task' key with the task object to update.")
        }
        return Update-PmcTask @UpdateParameters
    }
    
    [void] RemoveTask([PmcTask]$Task) {
        Remove-PmcTask -Task $Task
    }
    
    [PmcTask[]] GetTasks() { 
        return Get-PmcTasks 
    }

    [PmcProject[]] GetProjects() { 
        return Get-PmcProjects 
    }
}
