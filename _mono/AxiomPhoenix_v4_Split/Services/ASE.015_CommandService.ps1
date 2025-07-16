# ==============================================================================
# Axiom-Phoenix v4.0 - CommandService
# Command storage and retrieval with clipboard integration
# ==============================================================================

#region Command Class

# ===== CLASS: StoredCommand =====
class StoredCommand : ValidationBase {
    [string]$Id = [Guid]::NewGuid().ToString()  # Unique identifier
    [string]$Name                                # Short name for the command
    [string]$Command                             # The actual command string
    [string]$Description                         # Description of what it does
    [string[]]$Tags = @()                       # Tags for categorization
    [DateTime]$CreatedAt = [DateTime]::Now      # When it was created
    [DateTime]$LastUsed = [DateTime]::Now       # Last time it was accessed
    [int]$UseCount = 0                          # How many times it's been used
    [hashtable]$Metadata = @{}                  # Additional data
    
    StoredCommand() {}
    
    StoredCommand([string]$name, [string]$command, [string]$description) {
        [ValidationBase]::ValidateNotEmpty($name, "Name")
        [ValidationBase]::ValidateNotEmpty($command, "Command")
        
        $this.Name = $name
        $this.Command = $command
        $this.Description = $description
    }
    
    # MarkUsed: Update usage statistics
    [void] MarkUsed() {
        $this.LastUsed = [DateTime]::Now
        $this.UseCount++
    }
    
    # AddTag: Add a tag for categorization
    [void] AddTag([string]$tag) {
        [ValidationBase]::ValidateNotEmpty($tag, "Tag")
        if ($this.Tags -notcontains $tag) {
            $this.Tags += $tag
        }
    }
    
    # RemoveTag: Remove a tag
    [void] RemoveTag([string]$tag) {
        $this.Tags = $this.Tags | Where-Object { $_ -ne $tag }
    }
    
    # ToString: Display format
    [string] ToString() {
        return "$($this.Name): $($this.Command)"
    }
}

#endregion

#region CommandService Class

# ===== CLASS: CommandService =====
class CommandService {
    hidden [System.Collections.Generic.Dictionary[string, StoredCommand]]$_commandIndex
    hidden [DataManager]$_dataManager
    hidden [EventManager]$_eventManager
    
    CommandService([DataManager]$dataManager) {
        $this._dataManager = $dataManager
        $this._commandIndex = [System.Collections.Generic.Dictionary[string, StoredCommand]]::new()
        $this._LoadCommands()
    }
    
    CommandService([DataManager]$dataManager, [EventManager]$eventManager) {
        $this._dataManager = $dataManager
        $this._eventManager = $eventManager
        $this._commandIndex = [System.Collections.Generic.Dictionary[string, StoredCommand]]::new()
        $this._LoadCommands()
    }
    
    # Load commands from metadata storage
    hidden [void] _LoadCommands() {
        $commandsData = $this._dataManager.Metadata["StoredCommands"]
        if ($commandsData -and $commandsData -is [array]) {
            foreach ($cmdData in $commandsData) {
                try {
                    $command = [StoredCommand]::new()
                    $command.Id = $cmdData.Id
                    $command.Name = $cmdData.Name
                    $command.Command = $cmdData.Command
                    $command.Description = $cmdData.Description
                    $command.Tags = @($cmdData.Tags)
                    $command.CreatedAt = [DateTime]::Parse($cmdData.CreatedAt)
                    $command.LastUsed = [DateTime]::Parse($cmdData.LastUsed)
                    $command.UseCount = [int]$cmdData.UseCount
                    if ($cmdData.Metadata) {
                        $command.Metadata = $cmdData.Metadata.Clone()
                    }
                    
                    $this._commandIndex[$command.Id] = $command
                }
                catch {
                    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Error -Message "Failed to load command: $_"
                    } else {
                        Write-Warning "Failed to load command: $_"
                    }
                }
            }
        }
    }
    
    # Save commands to metadata storage
    hidden [void] _SaveCommands() {
        $commandsData = @()
        foreach ($command in $this._commandIndex.Values) {
            $commandsData += @{
                Id = $command.Id
                Name = $command.Name
                Command = $command.Command
                Description = $command.Description
                Tags = $command.Tags
                CreatedAt = $command.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ss")
                LastUsed = $command.LastUsed.ToString("yyyy-MM-ddTHH:mm:ss")
                UseCount = $command.UseCount
                Metadata = $command.Metadata.Clone()
            }
        }
        
        $this._dataManager.Metadata["StoredCommands"] = $commandsData
        
        if ($this._eventManager) {
            $this._eventManager.Publish("Commands.Changed", @{
                Action = "Saved"
                CommandCount = $this._commandIndex.Count
            })
        }
    }
    
    # Add a new command
    [StoredCommand] AddCommand([string]$name, [string]$command, [string]$description, [string[]]$tags = @()) {
        $newCommand = [StoredCommand]::new($name, $command, $description)
        
        foreach ($tag in $tags) {
            $newCommand.AddTag($tag)
        }
        
        $this._commandIndex[$newCommand.Id] = $newCommand
        $this._SaveCommands()
        
        if ($this._eventManager) {
            $this._eventManager.Publish("Commands.Changed", @{
                Action = "Added"
                Command = $newCommand
            })
        }
        
        return $newCommand
    }
    
    # Update an existing command
    [StoredCommand] UpdateCommand([StoredCommand]$command) {
        if (-not $this._commandIndex.ContainsKey($command.Id)) {
            throw [System.InvalidOperationException]::new("Command with ID '$($command.Id)' not found")
        }
        
        $this._commandIndex[$command.Id] = $command
        $this._SaveCommands()
        
        if ($this._eventManager) {
            $this._eventManager.Publish("Commands.Changed", @{
                Action = "Updated"
                Command = $command
            })
        }
        
        return $command
    }
    
    # Delete a command
    [bool] DeleteCommand([string]$commandId) {
        if (-not $this._commandIndex.ContainsKey($commandId)) {
            return $false
        }
        
        $command = $this._commandIndex[$commandId]
        $this._commandIndex.Remove($commandId) | Out-Null
        $this._SaveCommands()
        
        if ($this._eventManager) {
            $this._eventManager.Publish("Commands.Changed", @{
                Action = "Deleted"
                CommandId = $commandId
            })
        }
        
        return $true
    }
    
    # Get all commands
    [StoredCommand[]] GetCommands() {
        return @($this._commandIndex.Values)
    }
    
    # Get a specific command by ID
    [StoredCommand] GetCommand([string]$commandId) {
        if ($this._commandIndex.ContainsKey($commandId)) {
            return $this._commandIndex[$commandId]
        }
        return $null
    }
    
    # Search commands by name, description, or tags
    [StoredCommand[]] SearchCommands([string]$searchTerm) {
        $searchTerm = $searchTerm.ToLower()
        $results = @()
        
        foreach ($command in $this._commandIndex.Values) {
            if ($command.Name.ToLower() -match $searchTerm -or
                $command.Description.ToLower() -match $searchTerm -or
                $command.Command.ToLower() -match $searchTerm -or
                ($command.Tags | Where-Object { $_.ToLower() -match $searchTerm })) {
                $results += $command
            }
        }
        
        # Sort by usage frequency and recency
        return $results | Sort-Object -Property UseCount, LastUsed -Descending
    }
    
    # Get commands by tag
    [StoredCommand[]] GetCommandsByTag([string]$tag) {
        return @($this._commandIndex.Values | Where-Object { $_.Tags -contains $tag })
    }
    
    # Execute command (copy to clipboard and mark as used)
    [bool] ExecuteCommand([string]$commandId) {
        $command = $this.GetCommand($commandId)
        if ($null -eq $command) {
            return $false
        }
        
        try {
            # Copy command to clipboard
            $command.Command | Set-Clipboard
            
            # Mark as used
            $command.MarkUsed()
            $this._SaveCommands()
            
            if ($this._eventManager) {
                $this._eventManager.Publish("Commands.Executed", @{
                    Command = $command
                    ExecutedAt = [DateTime]::Now
                })
            }
            
            return $true
        }
        catch {
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Error -Message "Failed to execute command '$($command.Name)': $_"
            } else {
                Write-Warning "Failed to execute command '$($command.Name)': $_"
            }
            return $false
        }
    }
    
    # Get most frequently used commands
    [StoredCommand[]] GetTopCommands([int]$count = 10) {
        return @($this._commandIndex.Values | 
            Sort-Object -Property UseCount -Descending | 
            Select-Object -First $count)
    }
    
    # Get recently used commands
    [StoredCommand[]] GetRecentCommands([int]$count = 10) {
        return @($this._commandIndex.Values | 
            Sort-Object -Property LastUsed -Descending | 
            Select-Object -First $count)
    }
}

#endregion