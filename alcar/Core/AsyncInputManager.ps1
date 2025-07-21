# AsyncInputManager - Asynchronous input system for faster, more responsive UI
# Allows command entry while navigating, enabled via -AsyncInput flag

class AsyncInputManager {
    [System.Collections.Concurrent.ConcurrentQueue[object]]$InputQueue
    [System.Collections.Concurrent.ConcurrentQueue[object]]$CommandQueue
    [System.Threading.Thread]$InputThread
    [bool]$IsRunning = $false
    [bool]$IsEnabled = $false
    [string]$CommandBuffer = ""
    [bool]$InCommandMode = $false
    [System.DateTime]$LastKeyTime = [System.DateTime]::Now
    
    # Command history
    [System.Collections.ArrayList]$CommandHistory = @()
    [int]$HistoryIndex = -1
    
    # Platform detection
    [bool]$IsLinux = $false
    [bool]$IsWindows = $false
    
    AsyncInputManager() {
        $this.InputQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
        $this.CommandQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
        
        # Detect platform
        $this.IsWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
        $this.IsLinux = -not $this.IsWindows
    }
    
    [void] Enable() {
        if ($this.IsEnabled) { return }
        
        $this.IsEnabled = $true
        $this.IsRunning = $true
        
        # Start input thread
        $this.StartInputThread()
        
        Write-Debug "AsyncInputManager enabled"
    }
    
    [void] Disable() {
        if (-not $this.IsEnabled) { return }
        
        $this.IsEnabled = $false
        $this.IsRunning = $false
        
        # Stop input thread
        if ($this.InputThread -and $this.InputThread.IsAlive) {
            $this.InputThread.Join(1000)
        }
        
        Write-Debug "AsyncInputManager disabled"
    }
    
    [void] StartInputThread() {
        $inputScript = {
            param($manager)
            
            # Set up terminal for raw input on Linux
            if ($manager.IsLinux) {
                # Save current terminal settings
                $sttySettings = & stty -g 2>$null
                
                # Set terminal to raw mode
                & stty -echo -icanon min 0 time 0 2>$null
            }
            
            try {
                while ($manager.IsRunning) {
                    if ([Console]::KeyAvailable) {
                        $keyInfo = [Console]::ReadKey($true)
                        $manager.ProcessKey($keyInfo)
                    } else {
                        [System.Threading.Thread]::Sleep(10)
                    }
                }
            } finally {
                # Restore terminal settings on Linux
                if ($manager.IsLinux -and $sttySettings) {
                    & stty $sttySettings 2>$null
                }
            }
        }
        
        $this.InputThread = [System.Threading.Thread]::new($inputScript)
        $this.InputThread.Start($this)
    }
    
    [void] ProcessKey([ConsoleKeyInfo]$keyInfo) {
        $this.LastKeyTime = [System.DateTime]::Now
        
        # Check for command mode trigger (/)
        if ($keyInfo.KeyChar -eq '/' -and -not $this.InCommandMode) {
            $this.InCommandMode = $true
            $this.CommandBuffer = "/"
            return
        }
        
        # Handle command mode input
        if ($this.InCommandMode) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Enter) {
                    # Execute command
                    if ($this.CommandBuffer.Length -gt 1) {
                        $cmd = $this.CommandBuffer.Substring(1)  # Remove leading /
                        $this.CommandQueue.Enqueue(@{
                            Type = "Command"
                            Command = $cmd
                            Timestamp = [System.DateTime]::Now
                        })
                        
                        # Add to history
                        if ($this.CommandHistory[-1] -ne $cmd) {
                            $this.CommandHistory.Add($cmd) | Out-Null
                        }
                    }
                    
                    $this.CommandBuffer = ""
                    $this.InCommandMode = $false
                    $this.HistoryIndex = -1
                }
                
                ([ConsoleKey]::Escape) {
                    # Cancel command
                    $this.CommandBuffer = ""
                    $this.InCommandMode = $false
                    $this.HistoryIndex = -1
                }
                
                ([ConsoleKey]::Backspace) {
                    # Remove last character
                    if ($this.CommandBuffer.Length -gt 1) {
                        $this.CommandBuffer = $this.CommandBuffer.Substring(0, $this.CommandBuffer.Length - 1)
                    } elseif ($this.CommandBuffer -eq "/") {
                        $this.CommandBuffer = ""
                        $this.InCommandMode = $false
                    }
                }
                
                ([ConsoleKey]::UpArrow) {
                    # Previous command from history
                    if ($this.CommandHistory.Count -gt 0) {
                        if ($this.HistoryIndex -eq -1) {
                            $this.HistoryIndex = $this.CommandHistory.Count - 1
                        } elseif ($this.HistoryIndex -gt 0) {
                            $this.HistoryIndex--
                        }
                        
                        if ($this.HistoryIndex -ge 0) {
                            $this.CommandBuffer = "/" + $this.CommandHistory[$this.HistoryIndex]
                        }
                    }
                }
                
                ([ConsoleKey]::DownArrow) {
                    # Next command from history
                    if ($this.HistoryIndex -ge 0 -and $this.HistoryIndex -lt $this.CommandHistory.Count - 1) {
                        $this.HistoryIndex++
                        $this.CommandBuffer = ":" + $this.CommandHistory[$this.HistoryIndex]
                    } elseif ($this.HistoryIndex -eq $this.CommandHistory.Count - 1) {
                        $this.HistoryIndex = -1
                        $this.CommandBuffer = "/"
                    }
                }
                
                ([ConsoleKey]::Tab) {
                    # Command completion
                    $partial = $this.CommandBuffer.Substring(1)
                    $matches = $this.GetCommandCompletions($partial)
                    
                    if ($matches.Count -eq 1) {
                        $this.CommandBuffer = "/" + $matches[0]
                    } elseif ($matches.Count -gt 1) {
                        # Show completions (queue for display)
                        $this.CommandQueue.Enqueue(@{
                            Type = "ShowCompletions"
                            Completions = $matches
                            Timestamp = [System.DateTime]::Now
                        })
                    }
                }
                
                default {
                    # Add character to buffer
                    if ($keyInfo.KeyChar -and [char]::IsLetterOrDigit($keyInfo.KeyChar) -or 
                        " -_/.".Contains($keyInfo.KeyChar)) {
                        $this.CommandBuffer += $keyInfo.KeyChar
                    }
                }
            }
        } else {
            # Normal navigation mode - queue the key
            $this.InputQueue.Enqueue(@{
                Type = "Key"
                KeyInfo = $keyInfo
                Timestamp = [System.DateTime]::Now
            })
        }
    }
    
    [object] GetNextInput() {
        $input = $null
        if ($this.InputQueue.TryDequeue([ref]$input)) {
            return $input
        }
        return $null
    }
    
    [object] GetNextCommand() {
        $command = $null
        if ($this.CommandQueue.TryDequeue([ref]$command)) {
            return $command
        }
        return $null
    }
    
    [bool] HasInput() {
        return -not $this.InputQueue.IsEmpty
    }
    
    [bool] HasCommand() {
        return -not $this.CommandQueue.IsEmpty
    }
    
    [string] GetCommandBuffer() {
        return $this.CommandBuffer
    }
    
    [bool] IsInCommandMode() {
        return $this.InCommandMode
    }
    
    [string[]] GetCommandCompletions([string]$partial) {
        $commands = @(
            "task new",
            "task edit",
            "task delete",
            "task complete",
            "time start",
            "time stop",
            "time add",
            "project new",
            "project edit",
            "project close",
            "note add",
            "note edit",
            "file open",
            "file browse",
            "quit",
            "help",
            "search",
            "filter active",
            "filter all",
            "filter project",
            "workspace save",
            "workspace load",
            "workspace list"
        )
        
        if ([string]::IsNullOrEmpty($partial)) {
            return $commands
        }
        
        return $commands | Where-Object { $_.StartsWith($partial, [StringComparison]::OrdinalIgnoreCase) }
    }
    
    [void] ProcessCommands([object]$screen) {
        while ($this.HasCommand()) {
            $cmd = $this.GetNextCommand()
            
            switch ($cmd.Type) {
                "Command" {
                    $this.ExecuteCommand($cmd.Command, $screen)
                }
                
                "ShowCompletions" {
                    # Screen should handle showing completions
                    if ($screen -and $screen.PSObject.Methods.Name -contains "ShowCompletions") {
                        $screen.ShowCompletions($cmd.Completions)
                    }
                }
            }
        }
    }
    
    [void] ExecuteCommand([string]$command, [object]$screen) {
        $parts = $command -split ' ', 2
        $verb = $parts[0]
        $args = if ($parts.Count -gt 1) { $parts[1] } else { "" }
        
        switch ($verb) {
            "task" {
                $this.HandleTaskCommand($args, $screen)
            }
            
            "time" {
                $this.HandleTimeCommand($args, $screen)
            }
            
            "project" {
                $this.HandleProjectCommand($args, $screen)
            }
            
            "note" {
                $this.HandleNoteCommand($args, $screen)
            }
            
            "file" {
                $this.HandleFileCommand($args, $screen)
            }
            
            "filter" {
                $this.HandleFilterCommand($args, $screen)
            }
            
            "workspace" {
                $this.HandleWorkspaceCommand($args, $screen)
            }
            
            "search" {
                if ($screen -and $screen.PSObject.Methods.Name -contains "Search") {
                    $screen.Search($args)
                }
            }
            
            "help" {
                $this.ShowHelp($screen)
            }
            
            "quit" {
                if ($screen) {
                    $screen.Active = $false
                }
            }
            
            default {
                Write-Debug "Unknown command: $command"
            }
        }
    }
    
    [void] HandleTaskCommand([string]$args, [object]$screen) {
        $parts = $args -split ' ', 2
        $action = $parts[0]
        
        switch ($action) {
            "new" {
                if ($screen -and $screen.PSObject.Methods.Name -contains "NewTask") {
                    $screen.NewTask()
                }
            }
            
            "edit" {
                if ($screen -and $screen.PSObject.Methods.Name -contains "EditCurrent") {
                    $screen.EditCurrent()
                }
            }
            
            "complete" {
                if ($screen -and $screen.PSObject.Methods.Name -contains "CompleteTask") {
                    $screen.CompleteTask()
                }
            }
        }
    }
    
    [void] HandleTimeCommand([string]$args, [object]$screen) {
        $parts = $args -split ' ', 2
        $action = $parts[0]
        
        switch ($action) {
            "start" {
                if ($screen -and $screen.PSObject.Methods.Name -contains "StartTimer") {
                    $screen.StartTimer()
                } elseif ($screen -and $screen.PSObject.Methods.Name -contains "ToggleTimer") {
                    $screen.ToggleTimer()
                }
            }
            
            "stop" {
                if ($screen -and $screen.PSObject.Methods.Name -contains "StopTimer") {
                    $screen.StopTimer()
                } elseif ($screen -and $screen.PSObject.Methods.Name -contains "ToggleTimer") {
                    $screen.ToggleTimer()
                }
            }
        }
    }
    
    [void] ShowHelp([object]$screen) {
        # Queue help display
        $this.CommandQueue.Enqueue(@{
            Type = "ShowHelp"
            Timestamp = [System.DateTime]::Now
        })
    }
}

# Global instance (created when needed)
$global:AsyncInputManager = $null