# ServiceContainer - Lightweight service layer for business logic separation
# Performance-focused implementation without heavy reflection

class ServiceContainer {
    hidden [hashtable]$Services = @{}
    hidden [hashtable]$Factories = @{}
    
    # Register a service instance
    [void] RegisterService([string]$name, [object]$instance) {
        $this.Services[$name] = $instance
    }
    
    # Register a factory for lazy initialization
    [void] RegisterFactory([string]$name, [scriptblock]$factory) {
        $this.Factories[$name] = $factory
    }
    
    # Get a service (lazy initialize if needed)
    [object] GetService([string]$name) {
        if ($this.Services.ContainsKey($name)) {
            return $this.Services[$name]
        }
        
        if ($this.Factories.ContainsKey($name)) {
            $instance = & $this.Factories[$name]
            $this.Services[$name] = $instance
            return $instance
        }
        
        return $null
    }
    
    # Check if service exists
    [bool] HasService([string]$name) {
        return $this.Services.ContainsKey($name) -or $this.Factories.ContainsKey($name)
    }
}

# Global service container instance
$global:ServiceContainer = [ServiceContainer]::new()

# Register core services
$global:ServiceContainer.RegisterFactory("TaskService", {
    . "$PSScriptRoot/TaskService.ps1"
    return [TaskService]::new()
})

$global:ServiceContainer.RegisterFactory("ProjectService", {
    . "$PSScriptRoot/ProjectService.ps1" 
    return [ProjectService]::new()
})

# ViewDefinitionService is already created as singleton
$global:ServiceContainer.RegisterService("ViewDefinitionService", $global:ViewDefinitionService)