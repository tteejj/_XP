class ScreenFactory {
    hidden [hashtable] $Services
    hidden [hashtable] $ScreenTypes = @{}
    
    ScreenFactory([hashtable]$services) {
        $this.Services = $services ?? (throw [System.ArgumentNullException]::new("services"))
        Write-Log -Level Debug -Message "ScreenFactory initialized"
    }
    
    [void] RegisterScreen([string]$name, [type]$screenType) {
        if (-not ($screenType -eq [Screen] -or $screenType.IsSubclassOf([Screen]))) { 
            throw "Screen type '$($screenType.Name)' must inherit from the Screen class." 
        }
        $this.ScreenTypes[$name] = $screenType
        Write-Log -Level Info -Message "Registered screen factory: $name -> $($screenType.Name)"
    }
    
    [Screen] CreateScreen([string]$screenName, [hashtable]$parameters) {
        $screenType = $this.ScreenTypes[$screenName]
        if (-not $screenType) {
            throw "Unknown screen type: '$screenName'. Available screens: $($this.ScreenTypes.Keys -join ', ')"
        }
        
        try {
            $screen = $screenType::new($this.Services)
            if ($parameters) {
                foreach ($key in $parameters.Keys) { 
                    $screen.State[$key] = $parameters[$key] 
                }
            }
            Write-Log -Level Info -Message "Created screen: $screenName"
            return $screen
        } catch {
            Write-Log -Level Error -Message "Failed to create screen '$screenName': $($_.Exception.Message)"
            throw
        }
    }
    
    [string[]] GetRegisteredScreens() {
        return @($this.ScreenTypes.Keys)
    }
}
