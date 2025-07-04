# ==============================================================================
# Axiom-Phoenix v4.0 - TUI Framework Integration Module
# PURPOSE: Provides helper functions and services for interacting with the TUI engine.
# This version is updated for the class-based, lifecycle-aware architecture.
# ==============================================================================

using module ui-classes
using module tui-primitives
using module theme-manager
using module logger
using module exceptions

# The TuiFrameworkService class encapsulates utility functions and can be
# registered with the service container for easy access by other components.
class TuiFrameworkService {
    hidden [System.Collections.Concurrent.ConcurrentDictionary[guid, object]] $_asyncJobs
    
    TuiFrameworkService() {
        $this._asyncJobs = [System.Collections.Concurrent.ConcurrentDictionary[guid, object]]::new()
        Write-Log -Level Info "TuiFrameworkService initialized."
    }
    
    # Executes a script block asynchronously using a lightweight thread job.
    # Ideal for I/O-bound operations like network requests or file access.
    [System.Management.Automation.Job] StartAsync(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [Parameter()][hashtable]$ArgumentList = @{}
    ) {
        return Invoke-WithErrorHandling -Component "TuiFramework.StartAsync" -Context "Starting async thread job" -ScriptBlock {
            $job = Start-ThreadJob -ScriptBlock $ScriptBlock -ArgumentList @($ArgumentList)
            $this._asyncJobs[$job.InstanceId] = $job
            Write-Log -Level Debug -Message "Started async thread job: $($job.Name)" -Data @{ JobId = $job.InstanceId }
            return $job
        }
    }

    # Checks for completed async jobs and returns their results, cleaning them up by default.
    [object[]] GetAsyncResults([switch]$RemoveCompleted = $true) {
        return Invoke-WithErrorHandling -Component "TuiFramework.GetAsyncResults" -Context "Checking async job results" -ScriptBlock {
            $results = @()
            $completedJobs = $this._asyncJobs.Values | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') }
            
            foreach ($job in $completedJobs) {
                $jobResult = [pscustomobject]@{
                    JobId = $job.InstanceId
                    Name = $job.Name
                    State = $job.State
                    Output = if ($job.State -eq 'Completed') { Receive-Job -Job $job -Keep } else { $null }
                    Error = if ($job.State -eq 'Failed') { $job.Error | Select-Object -First 1 } else { $null }
                }
                $results += $jobResult
                
                if ($RemoveCompleted) {
                    $this._asyncJobs.TryRemove($job.InstanceId, [ref]$null) | Out-Null
                    Remove-Job -Job $job -Force
                }
            }
            return $results
        }
    }

    # Stops all tracked asynchronous jobs. Should be called during application cleanup.
    [void] StopAllAsyncJobs() {
        Invoke-WithErrorHandling -Component "TuiFramework.StopAllAsync" -Context "Stopping all tracked async jobs" -ScriptBlock {
            foreach ($job in $this._asyncJobs.Values) {
                try {
                    Stop-Job -Job $job -Force
                    Remove-Job -Job $job -Force
                } catch {
                    Write-Log -Level Warning -Message "Failed to stop or remove job $($job.Name): $($_.Exception.Message)"
                }
            }
            $this._asyncJobs.Clear()
            Write-Log -Level Info -Message "All tracked TUI async jobs stopped."
        }
    }
    
    # Returns the global TUI state object for debugging or advanced scenarios.
    [hashtable] GetState() {
        return $global:TuiState
    }

    # Tests if the TUI is in a valid, running state.
    [bool] IsRunning() {
        return $global:TuiState -and $global:TuiState.Running -and $global:TuiState.CurrentScreen
    }
}

# Factory function to create the TuiFrameworkService instance.
# This is what gets registered with the service container.
function Initialize-TuiFrameworkService {
    [CmdletBinding()]
    param()
    
    # Check for the ThreadJob module dependency
    if (-not (Get-Module -Name 'ThreadJob' -ListAvailable)) {
        Write-Warning "The 'ThreadJob' module is not installed. Asynchronous features will be limited. Please run 'Install-Module ThreadJob'."
    }
    
    return [TuiFrameworkService]::new()
}


# --- DEPRECATED/REMOVED FUNCTIONS ---
# The following functions from the original module have been removed as they are
# either obsolete due to the class-based architecture or have been encapsulated
# within the TuiFrameworkService class.

# REMOVED: Invoke-TuiMethod
# Rationale: Obsolete. With strongly-typed classes, we now use direct method
# invocation (e.g., $component.HandleInput()), which is cleaner, more performant,
# and provides better IntelliSense support.

# REMOVED: Stop-AllTuiAsyncJobs, Get-TuiAsyncResults, Invoke-TuiAsync
# Rationale: This logic is now encapsulated as methods within the TuiFrameworkService class,
# allowing the service to manage the state of the jobs it creates and to use
# modern, lightweight thread jobs instead of process-based jobs.

# REMOVED: Get-TuiState, Test-TuiState
# Rationale: Encapsulated as methods within TuiFrameworkService to promote
# a service-based architecture over loose global function calls.

Export-ModuleMember -Function Initialize-TuiFrameworkService