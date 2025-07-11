# ==============================================================================
# Axiom-Phoenix v4.0 - FileSystemService
# Centralizes all interactions with the file system
# ==============================================================================

using namespace System.IO

class FileSystemService {
    [Logger]$Logger
    
    FileSystemService([Logger]$logger) {
        $this.Logger = $logger
        Write-Log -Level Debug -Message "FileSystemService: Initialized"
    }
    
    # Creates a directory if it doesn't exist
    [bool] CreateDirectory([string]$path) {
        try {
            if (-not (Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
                $this.Logger.Log("Created directory: $path", "Info")
                return $true
            }
            return $true
        }
        catch {
            $this.Logger.Log("Failed to create directory $path : $_", "Error")
            return $false
        }
    }
    
    # Lists items in a directory
    [System.IO.FileSystemInfo[]] GetDirectoryItems([string]$path, [bool]$showHidden = $false) {
        if ([string]::IsNullOrEmpty($path) -or -not (Test-Path $path -PathType Container)) {
            $this.Logger.Log("Path '$path' is invalid or not a directory", "Warning")
            return @()
        }
        
        try {
            $params = @{
                Path = $path
                ErrorAction = 'SilentlyContinue'
            }
            if ($showHidden) {
                $params.Force = $true
            }
            
            $items = Get-ChildItem @params
            return $items
        }
        catch {
            $this.Logger.LogException($_.Exception, "Failed to list directory contents for '$path'")
            return @()
        }
    }
    
    # Checks if a file exists
    [bool] FileExists([string]$path) {
        return Test-Path $path -PathType Leaf
    }
    
    # Checks if a directory exists
    [bool] DirectoryExists([string]$path) {
        return Test-Path $path -PathType Container
    }
    
    # Copies a file
    [bool] CopyFile([string]$source, [string]$destination) {
        try {
            Copy-Item -Path $source -Destination $destination -Force
            $this.Logger.Log("Copied file from $source to $destination", "Info")
            return $true
        }
        catch {
            $this.Logger.LogException($_.Exception, "Failed to copy file from $source to $destination")
            return $false
        }
    }
    
    # Deletes a file or directory
    [bool] DeleteItem([string]$path, [bool]$recurse = $false) {
        try {
            if (Test-Path $path) {
                Remove-Item -Path $path -Force -Recurse:$recurse
                $this.Logger.Log("Deleted item: $path", "Info")
                return $true
            }
            return $true
        }
        catch {
            $this.Logger.LogException($_.Exception, "Failed to delete item: $path")
            return $false
        }
    }
    
    # Gets the parent directory of a path
    [string] GetParentDirectory([string]$path) {
        return Split-Path -Path $path -Parent
    }
    
    # Combines paths safely
    [string] CombinePath([string]$path1, [string]$path2) {
        return Join-Path -Path $path1 -ChildPath $path2
    }
    
    # Creates a unique project folder name
    [string] CreateUniqueProjectFolder([string]$basePath, [string]$projectKey, [string]$projectName) {
        # Sanitize project name for filesystem
        $safeName = $projectName -replace '[^\w\s\-]', ''
        $safeName = $safeName -replace '\s+', '_'
        
        $folderName = "${projectKey}_${safeName}"
        $fullPath = Join-Path $basePath $folderName
        
        # If folder already exists, append a number
        $counter = 1
        $originalPath = $fullPath
        while (Test-Path $fullPath) {
            $fullPath = "${originalPath}_$counter"
            $counter++
        }
        
        return $fullPath
    }
    
    # Cleanup
    [void] Cleanup() {
        Write-Log -Level Debug -Message "FileSystemService: Cleanup complete"
    }
}
