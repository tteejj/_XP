# ==============================================================================
# Axiom-Phoenix v4.0 - All Services (Load After Components)
# Core application services: action, navigation, data, theming, logging, events
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASE.###" to find specific sections.
# Each section ends with "END_PAGE: ASE.###"
# ==============================================================================

#region AsyncJobService Class

# ===== CLASS: AsyncJobService =====
# Module: async-jobs (from axiom)
# Dependencies: None
# Purpose: Framework utilities and async operations
class AsyncJobService {
    [hashtable]$AsyncJobs = @{}
    [int]$NextJobId = 1
    [bool]$IsRunning = $false
    
    AsyncJobService() {
        # Write-Verbose "AsyncJobService: Initialized"
    }
    
    [hashtable] StartAsync([scriptblock]$work, [string]$name = "") {
        try {
            $jobId = $this.NextJobId++
            $jobName = "AsyncJob_$jobId"
            if ($name) { $jobName = $name }
            
            # Use ThreadJob for lightweight async operations
            $job = Start-ThreadJob -ScriptBlock $work -Name $jobName
            
            $jobInfo = @{
                Id = $jobId
                Name = $jobName
                Job = $job
                StartedAt = [DateTime]::Now
                Status = "Running"
            }
            
            $this.AsyncJobs[$jobId] = $jobInfo
            
            # Write-Verbose "AsyncJobService: Started async job '$jobName' with ID $jobId"
            return $jobInfo
        }
        catch {
            Write-Error "Failed to start async job: $_"
            throw
        }
    }
    
    [object] GetAsyncResults([int]$jobId, [bool]$wait = $false) {
        if (-not $this.AsyncJobs.ContainsKey($jobId)) {
            throw "Async job with ID $jobId not found"
        }
        
        $jobInfo = $this.AsyncJobs[$jobId]
        $job = $jobInfo.Job
        
        if ($wait) {
            # Write-Verbose "AsyncJobService: Waiting for job $jobId to complete"
            Wait-Job -Job $job | Out-Null
        }
        
        if ($job.State -eq "Completed") {
            $result = Receive-Job -Job $job -Keep
            $jobInfo.Status = "Completed"
            return $result
        }
        elseif ($job.State -eq "Failed") {
            $jobInfo.Status = "Failed"
            $error = Receive-Job -Job $job -Keep
            throw "Async job $jobId failed: $error"
        }
        else {
            return $null
        }
    }
    
    [void] StopAllAsyncJobs() {
        # Write-Verbose "AsyncJobService: Stopping all async jobs"
        
        foreach ($jobInfo in $this.AsyncJobs.Values) {
            try {
                if ($jobInfo.Job.State -eq "Running") {
                    Stop-Job -Job $jobInfo.Job
                    Remove-Job -Job $jobInfo.Job -Force
                }
            }
            catch {
                Write-Warning "Failed to stop job $($jobInfo.Id): $_"
            }
        }
        
        $this.AsyncJobs.Clear()
    }
    
    [hashtable] GetState() {
        return @{
            IsRunning = $this.IsRunning
            AsyncJobCount = $this.AsyncJobs.Count
            ActiveJobs = $this.AsyncJobs.Values | Where-Object { $_.Status -eq "Running" } | Measure-Object | Select-Object -ExpandProperty Count
        }
    }
    
    [bool] IsRunning() {
        return $this.IsRunning
    }
    
    [void] Start() {
        $this.IsRunning = $true
        # Write-Verbose "AsyncJobService: Started"
    }
    
    [void] Stop() {
        $this.StopAllAsyncJobs()
        $this.IsRunning = $false
        # Write-Verbose "AsyncJobService: Stopped"
    }
    
    [void] Cleanup() {
        $this.Stop()
    }
}

#endregion
#<!-- END_PAGE: ASE.008 -->
