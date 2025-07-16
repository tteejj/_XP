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

# ===== CLASS: ViewDefinitionService =====  
# Module: view-definition-service
# Dependencies: None
# Purpose: Centralized service for defining how data models are presented in UI components
class ViewDefinitionService {
    hidden [hashtable]$_definitions = @{}
    
    ViewDefinitionService() {
        $this._RegisterDefaultViewDefinitions()
    }
    
    [hashtable] GetViewDefinition([string]$viewName) {
        if (-not $this._definitions.ContainsKey($viewName)) {
            throw "View definition '$viewName' not found. Available definitions: $($this._definitions.Keys -join ', ')"
        }
        return $this._definitions[$viewName]
    }
    
    [void] RegisterViewDefinition([string]$viewName, [hashtable]$definition) {
        if ([string]::IsNullOrWhiteSpace($viewName)) {
            throw "View name cannot be null or empty"
        }
        
        if (-not $definition -or -not $definition.ContainsKey("Columns") -or -not $definition.ContainsKey("Transformer")) {
            throw "View definition must contain 'Columns' and 'Transformer' keys"
        }
        
        $this._definitions[$viewName] = $definition
    }
    
    [string[]] GetAvailableViewNames() {
        return $this._definitions.Keys
    }
    
    hidden [void] _RegisterDefaultViewDefinitions() {
        # Task summary view for lists and grids - Enhanced with dynamic styling
        $this.RegisterViewDefinition('task.summary', @{
            Columns = @(
                @{ Name="Status";   Header="S"; Width=3 },
                @{ Name="Priority"; Header="!"; Width=3 },
                @{ Name="Title";    Header="Task Title"; Width=40 },
                @{ Name="Progress"; Header="Progress"; Width=8 }
            )
            Transformer = {
                param($task)
                
                # Status indicator with style
                $statusChar = switch ($task.Status) {
                    ([TaskStatus]::Pending) { "○" }
                    ([TaskStatus]::InProgress) { "◐" }
                    ([TaskStatus]::Completed) { "●" }
                    ([TaskStatus]::Cancelled) { "✗" }
                    default { "?" }
                }
                
                # Priority indicator with style
                $priorityChar = switch ($task.Priority) {
                    ([TaskPriority]::Low) { "↓" }
                    ([TaskPriority]::Medium) { "→" }
                    ([TaskPriority]::High) { "↑" }
                    default { "→" }
                }
                
                # Progress display with conditional styling
                $progressText = "$($task.Progress)%"
                
                # Check if task is overdue
                $isOverdue = $task.DueDate -and $task.DueDate -lt [DateTime]::Now -and $task.Status -ne [TaskStatus]::Completed
                
                return @{
                    Status   = @{ 
                        Text = $statusChar
                        Style = "task.status.$($task.Status.ToString().ToLower())"
                    }
                    Priority = @{ 
                        Text = $priorityChar
                        Style = "task.priority.$($task.Priority.ToString().ToLower())"
                    }
                    Title    = @{ 
                        Text = $task.Title
                        Style = if ($isOverdue) { "task.title.overdue" } else { "task.title.normal" }
                    }
                    Progress = @{ 
                        Text = $progressText
                        Style = if ($task.Progress -eq 100) { "task.progress.complete" } 
                                elseif ($task.Progress -ge 75) { "task.progress.high" }
                                elseif ($task.Progress -ge 50) { "task.progress.medium" }
                                else { "task.progress.low" }
                    }
                }
            }
        })
        
        # Task detail view with more information
        $this.RegisterViewDefinition('task.detailed', @{
            Columns = @(
                @{ Name="Status";     Header="Status"; Width=12 },
                @{ Name="Priority";   Header="Priority"; Width=10 },
                @{ Name="Title";      Header="Task Title"; Width=30 },
                @{ Name="Progress";   Header="Progress"; Width=10 },
                @{ Name="DueDate";    Header="Due Date"; Width=12 },
                @{ Name="Project";    Header="Project"; Width=15 }
            )
            Transformer = {
                param($task)
                
                # Full status name
                $statusText = switch ($task.Status) {
                    ([TaskStatus]::Pending) { "Pending" }
                    ([TaskStatus]::InProgress) { "In Progress" }
                    ([TaskStatus]::Completed) { "Completed" }
                    ([TaskStatus]::Cancelled) { "Cancelled" }
                    default { "Unknown" }
                }
                
                # Full priority name
                $priorityText = switch ($task.Priority) {
                    ([TaskPriority]::Low) { "Low" }
                    ([TaskPriority]::Medium) { "Medium" }
                    ([TaskPriority]::High) { "High" }
                    default { "Unknown" }
                }
                
                # Formatted due date
                $dueDateText = if ($task.DueDate) {
                    $task.DueDate.ToString("MM/dd/yyyy")
                } else {
                    "None"
                }
                
                # Progress with bar
                $progressText = "$($task.Progress)%"
                
                # Project key or default
                $projectText = "None"
                if ($task.ProjectKey) { $projectText = $task.ProjectKey }
                
                return @{
                    Status   = $statusText
                    Priority = $priorityText
                    Title    = $task.Title
                    Progress = $progressText
                    DueDate  = $dueDateText
                    Project  = $projectText
                }
            }
        })
        
        # Compact task view for narrow displays
        $this.RegisterViewDefinition('task.compact', @{
            Columns = @(
                @{ Name="Status";   Header="S"; Width=1 },
                @{ Name="Title";    Header="Task"; Width=30 }
            )
            Transformer = {
                param($task)
                
                # Single character status
                $statusChar = switch ($task.Status) {
                    ([TaskStatus]::Pending) { "○" }
                    ([TaskStatus]::InProgress) { "◐" }
                    ([TaskStatus]::Completed) { "●" }
                    ([TaskStatus]::Cancelled) { "✗" }
                    default { "?" }
                }
                
                return @{
                    Status = $statusChar
                    Title  = $task.Title
                }
            }
        })
        
        # Project summary view - Enhanced with dynamic styling
        $this.RegisterViewDefinition('project.summary', @{
            Columns = @(
                @{ Name="Key";        Header="Key"; Width=10 },
                @{ Name="Name";       Header="Project Name"; Width=30 },
                @{ Name="Status";     Header="Status"; Width=10 },
                @{ Name="Owner";      Header="Owner"; Width=15 }
            )
            Transformer = {
                param($project)
                
                $statusText = if ($project.IsActive) { "Active" } else { "Inactive" }
                $ownerText = if ($project.Owner) { $project.Owner } else { "Unassigned" }
                
                # Check if project is overdue
                $isOverdue = $project.BFDate -and $project.BFDate -lt [DateTime]::Now -and $project.IsActive
                
                return @{
                    Key    = @{ 
                        Text = $project.Key
                        Style = "project.key.normal"
                    }
                    Name   = @{ 
                        Text = $project.Name
                        Style = if ($isOverdue) { "project.name.overdue" } 
                                elseif (-not $project.IsActive) { "project.name.inactive" }
                                else { "project.name.normal" }
                    }
                    Status = @{ 
                        Text = $statusText
                        Style = if ($project.IsActive) { "project.status.active" } else { "project.status.inactive" }
                    }
                    Owner  = @{ 
                        Text = $ownerText
                        Style = if ($project.Owner) { "project.owner.assigned" } else { "project.owner.unassigned" }
                    }
                }
            }
        })
        
        # Dashboard recent tasks view - compact for overview
        $this.RegisterViewDefinition('dashboard.recent.tasks', @{
            Columns = @(
                @{ Name="Status";   Header="S"; Width=1 },
                @{ Name="Priority"; Header="!"; Width=1 },
                @{ Name="Title";    Header="Recent Tasks"; Width=35 },
                @{ Name="Age";      Header="Age"; Width=8 }
            )
            Transformer = {
                param($task)
                
                # Status indicator with unicode symbols
                $statusChar = switch ($task.Status) {
                    ([TaskStatus]::Pending) { "○" }
                    ([TaskStatus]::InProgress) { "◐" }
                    ([TaskStatus]::Completed) { "●" }
                    ([TaskStatus]::Cancelled) { "✗" }
                    default { "?" }
                }
                
                # Priority indicator
                $priorityChar = switch ($task.Priority) {
                    ([TaskPriority]::Low) { "↓" }
                    ([TaskPriority]::Medium) { "→" }
                    ([TaskPriority]::High) { "↑" }
                    default { "?" }
                }
                
                # Calculate age in days
                $age = [DateTime]::Now - $task.CreatedAt
                $ageText = if ($age.Days -gt 0) {
                    "$($age.Days)d"
                } elseif ($age.Hours -gt 0) {
                    "$($age.Hours)h"
                } else {
                    "$($age.Minutes)m"
                }
                
                return @{
                    Status   = $statusChar
                    Priority = $priorityChar
                    Title    = $task.Title
                    Age      = $ageText
                }
            }
        })
        
        # Dashboard summary statistics view
        $this.RegisterViewDefinition('dashboard.task.stats', @{
            Columns = @(
                @{ Name="Metric";    Header="Task Statistics"; Width=20 },
                @{ Name="Value";     Header="Count"; Width=8 },
                @{ Name="Indicator"; Header=""; Width=5 }
            )
            Transformer = {
                param($statsData)
                
                # This transformer expects a hashtable with metrics
                # Example: @{ Name="Total Tasks"; Count=15; Type="info" }
                
                $indicator = switch ($statsData.Type) {
                    "success" { "✓" }
                    "warning" { "⚠" }
                    "error" { "✗" }
                    "info" { "ⓘ" }
                    default { " " }
                }
                
                return @{
                    Metric    = $statsData.Name
                    Value     = $statsData.Count.ToString()
                    Indicator = $indicator
                }
            }
        })
        
        # Dashboard navigation menu view
        $this.RegisterViewDefinition('dashboard.navigation', @{
            Columns = @(
                @{ Name="Key";         Header="Key"; Width=5 },
                @{ Name="Action";      Header="Quick Actions"; Width=25 },
                @{ Name="Description"; Header="Description"; Width=20 }
            )
            Transformer = {
                param($navItem)
                
                return @{
                    Key         = "[$($navItem.Key)]"
                    Action      = $navItem.Name
                    Description = $navItem.Description
                }
            }
        })
    }
}
#<!-- END_PAGE: ASE.011 -->
