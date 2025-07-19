# ViewDefinitionService - Flexible data display configuration
# Minimal implementation focused on performance

class ViewDefinition {
    [string]$Name
    [hashtable[]]$Columns = @()
    [scriptblock]$Filter = $null
    [scriptblock]$Sort = $null
    [hashtable]$Cache = @{}
    
    ViewDefinition([string]$name) {
        $this.Name = $name
    }
    
    [void] AddColumn([string]$name, [string]$property, [int]$width, [scriptblock]$formatter = $null) {
        $this.Columns += @{
            Name = $name
            Property = $property
            Width = $width
            Formatter = $formatter
        }
    }
    
    [object[]] ApplyView([object[]]$data) {
        # Simple caching based on data count
        $cacheKey = "$($data.Count)"
        if ($this.Cache.ContainsKey($cacheKey)) {
            return $this.Cache[$cacheKey]
        }
        
        # Apply filter if defined
        if ($this.Filter) {
            $data = $data | Where-Object $this.Filter
        }
        
        # Apply sort if defined
        if ($this.Sort) {
            $data = $data | Sort-Object $this.Sort
        }
        
        # Cache and return
        $this.Cache[$cacheKey] = $data
        return $data
    }
    
    [string] FormatRow([object]$item) {
        $parts = @()
        foreach ($col in $this.Columns) {
            $value = $item.($col.Property)
            if ($col.Formatter) {
                $value = & $col.Formatter $value
            }
            $text = if ($null -eq $value) { "" } else { $value.ToString() }
            if ($text.Length -gt $col.Width) {
                $text = $text.Substring(0, $col.Width - 3) + "..."
            }
            $parts += $text.PadRight($col.Width)
        }
        return $parts -join " "
    }
}

class ViewDefinitionService {
    hidden [hashtable]$Views = @{}
    
    ViewDefinitionService() {
        $this.InitializeDefaultViews()
    }
    
    [void] InitializeDefaultViews() {
        # Task list view
        $taskView = [ViewDefinition]::new("TaskList")
        $taskView.AddColumn("Status", "Status", 3, { 
            param($s) 
            switch($s) {
                "Todo" { "[ ]" }
                "InProgress" { "[~]" }
                "Done" { "[✓]" }
                default { "[ ]" }
            }
        })
        $taskView.AddColumn("Title", "Title", 40, $null)
        $taskView.AddColumn("Due", "DueDate", 10, {
            param($d)
            if ($d) { $d.ToString("yyyy-MM-dd") } else { "" }
        })
        $taskView.Sort = { $_.Status, $_.DueDate }
        $this.Views["TaskList"] = $taskView
        
        # Project view
        $projectView = [ViewDefinition]::new("ProjectList")
        $projectView.AddColumn("Name", "Name", 30, $null)
        $projectView.AddColumn("Tasks", "TaskCount", 8, {
            param($c)
            "$c tasks"
        })
        $projectView.AddColumn("Progress", "Progress", 10, {
            param($p)
            $pct = [math]::Round($p * 100)
            "$pct%"
        })
        $this.Views["ProjectList"] = $projectView
    }
    
    [ViewDefinition] GetView([string]$name) {
        if ($this.Views.ContainsKey($name)) {
            return $this.Views[$name]
        }
        return $null
    }
    
    [void] RegisterView([ViewDefinition]$view) {
        $this.Views[$view.Name] = $view
    }
    
    [string[]] FormatData([string]$viewName, [object[]]$data) {
        $view = $this.GetView($viewName)
        if (-not $view) { return @() }
        
        $filteredData = $view.ApplyView($data)
        $result = @()
        foreach ($item in $filteredData) {
            $result += $view.FormatRow($item)
        }
        return $result
    }
}

# Global singleton instance
$global:ViewDefinitionService = [ViewDefinitionService]::new()