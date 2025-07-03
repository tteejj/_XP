class NavigationItem {
    [string] $Key
    [string] $Label
    [scriptblock] $Action
    [bool] $Enabled = $true
    [bool] $Visible = $true
    [string] $Description = ""
    [ConsoleColor] $KeyColor = [ConsoleColor]::Yellow
    [ConsoleColor] $LabelColor = [ConsoleColor]::White
    
    NavigationItem([string]$key, [string]$label, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($key))   { throw [ArgumentException]::new("Navigation key cannot be null or empty") }
        if ([string]::IsNullOrWhiteSpace($label)) { throw [ArgumentException]::new("Navigation label cannot be null or empty") }
        if ($null -eq $action)                    { throw [ArgumentNullException]::new("action", "Navigation action cannot be null") }
        
        $this.Key = $key.ToUpper()
        $this.Label = $label
        $this.Action = $action
    }
    
    [void] Execute() {
        if (-not $this.Enabled) {
            Write-Log -Level Warning -Message "Attempted to execute disabled navigation item: $($this.Key)"
            return
        }
        
        try {
            Write-Log -Level Debug -Message "Executing navigation item: $($this.Key) - $($this.Label)"
            & $this.Action
        }
        catch {
            Write-Log -Level Error -Message "Navigation action failed for item '$($this.Key)': $_"
            throw
        }
    }
    
    [string] FormatDisplay([bool]$showDescription = $false) {
        $display = "[$($this.Key)] "
        
        if ($this.Enabled) {
            $display += $this.Label
        }
        else {
            $display += "$($this.Label) (Disabled)"
        }
        
        if ($showDescription -and -not [string]::IsNullOrWhiteSpace($this.Description)) {
            $display += " - $($this.Description)"
        }
        
        return $display
    }
}
