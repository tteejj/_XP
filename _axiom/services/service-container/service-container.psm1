# ==============================================================================
# PMC Terminal Axiom-Phoenix v4.0 - Service Container Module
# ==============================================================================
# Purpose: Provides a centralized dependency injection container for all services
# Features:
#   - Service registration with lifecycle management
#   - Constructor-based dependency injection
#   - Lazy loading and singleton patterns
#   - Service resolution with dependency graph
#   - Circular dependency detection
# ==============================================================================

using namespace System
using namespace System.Collections.Generic

# Service lifecycle enumeration
enum ServiceLifecycle {
    Singleton    # One instance for entire application lifetime
    Transient    # New instance every time requested
    Scoped       # One instance per scope (future enhancement)
}

# Service registration metadata
class ServiceRegistration {
    [string] $Name
    [type] $ServiceType
    [type] $ImplementationType
    [ServiceLifecycle] $Lifecycle
    [scriptblock] $Factory
    [object] $Instance
    [bool] $IsResolved
    [string[]] $Dependencies
    [hashtable] $Metadata
    
    ServiceRegistration() {
        $this.Lifecycle = [ServiceLifecycle]::Singleton
        $this.IsResolved = $false
        $this.Dependencies = @()
        $this.Metadata = @{}
    }
}

# Main service container class
class ServiceContainer {
    hidden [Dictionary[string, ServiceRegistration]] $registrations
    hidden [HashSet[string]] $resolvingServices
    hidden [bool] $isLocked
    hidden [hashtable] $scopedInstances
    
    ServiceContainer() {
        $this.registrations = [Dictionary[string, ServiceRegistration]]::new()
        $this.resolvingServices = [HashSet[string]]::new()
        $this.isLocked = $false
        $this.scopedInstances = @{}
    }
    
    # Register a service with explicit implementation type
    [void] Register([string]$name, [type]$serviceType, [type]$implementationType) {
        $this.Register($name, $serviceType, $implementationType, [ServiceLifecycle]::Singleton)
    }
    
    # Register a service with explicit implementation type and lifecycle
    [void] Register([string]$name, [type]$serviceType, [type]$implementationType, [ServiceLifecycle]$lifecycle) {
        $this.ValidateNotLocked()
        
        if ($this.registrations.ContainsKey($name)) {
            throw "Service '$name' is already registered"
        }
        
        if (-not $implementationType.IsSubclassOf($serviceType) -and $implementationType -ne $serviceType) {
            if (-not ($serviceType.IsInterface -and $implementationType.GetInterfaces() -contains $serviceType)) {
                throw "Implementation type '$($implementationType.FullName)' does not implement service type '$($serviceType.FullName)'"
            }
        }
        
        $registration = [ServiceRegistration]::new()
        $registration.Name = $name
        $registration.ServiceType = $serviceType
        $registration.ImplementationType = $implementationType
        $registration.Lifecycle = $lifecycle
        
        # Analyze constructor dependencies
        $registration.Dependencies = $this.AnalyzeDependencies($implementationType)
        
        $this.registrations[$name] = $registration
        
        Write-Log -Level Debug -Message "Registered service '$name' as $($implementationType.Name) with lifecycle $lifecycle"
    }
    
    # Register a service with a factory function
    [void] RegisterFactory([string]$name, [type]$serviceType, [scriptblock]$factory) {
        $this.RegisterFactory($name, $serviceType, $factory, [ServiceLifecycle]::Singleton)
    }
    
    # Register a service with a factory function and lifecycle
    [void] RegisterFactory([string]$name, [type]$serviceType, [scriptblock]$factory, [ServiceLifecycle]$lifecycle) {
        $this.ValidateNotLocked()
        
        if ($this.registrations.ContainsKey($name)) {
            throw "Service '$name' is already registered"
        }
        
        $registration = [ServiceRegistration]::new()
        $registration.Name = $name
        $registration.ServiceType = $serviceType
        $registration.Factory = $factory
        $registration.Lifecycle = $lifecycle
        
        $this.registrations[$name] = $registration
        
        Write-Log -Level Debug -Message "Registered factory for service '$name' with lifecycle $lifecycle"
    }
    
    # Register an existing instance as a singleton
    [void] RegisterInstance([string]$name, [object]$instance) {
        $this.ValidateNotLocked()
        
        if ($this.registrations.ContainsKey($name)) {
            throw "Service '$name' is already registered"
        }
        
        if ($null -eq $instance) {
            throw "Cannot register null instance"
        }
        
        $registration = [ServiceRegistration]::new()
        $registration.Name = $name
        $registration.ServiceType = $instance.GetType()
        $registration.ImplementationType = $instance.GetType()
        $registration.Lifecycle = [ServiceLifecycle]::Singleton
        $registration.Instance = $instance
        $registration.IsResolved = $true
        
        $this.registrations[$name] = $registration
        
        Write-Log -Level Debug -Message "Registered instance for service '$name' of type $($instance.GetType().Name)"
    }
    
    # Resolve a service by name
    [object] Resolve([string]$name) {
        if (-not $this.registrations.ContainsKey($name)) {
            throw "Service '$name' is not registered"
        }
        
        # Check for circular dependencies
        if ($this.resolvingServices.Contains($name)) {
            $cycle = $this.resolvingServices -join " -> "
            throw "Circular dependency detected: $cycle -> $name"
        }
        
        $registration = $this.registrations[$name]
        
        # Return existing instance for singletons
        if ($registration.Lifecycle -eq [ServiceLifecycle]::Singleton -and $registration.IsResolved) {
            return $registration.Instance
        }
        
        # Add to resolving set
        [void]$this.resolvingServices.Add($name)
        
        try {
            $instance = $null
            
            if ($null -ne $registration.Factory) {
                # Use factory to create instance
                $instance = & $registration.Factory $this
            }
            elseif ($null -ne $registration.ImplementationType) {
                # Create instance using constructor injection
                $instance = $this.CreateInstance($registration.ImplementationType)
            }
            else {
                throw "No factory or implementation type specified for service '$name'"
            }
            
            if ($null -eq $instance) {
                throw "Failed to create instance for service '$name'"
            }
            
            # Store instance for singletons
            if ($registration.Lifecycle -eq [ServiceLifecycle]::Singleton) {
                $registration.Instance = $instance
                $registration.IsResolved = $true
            }
            
            Write-Log -Level Debug -Message "Resolved service '$name' as $($instance.GetType().Name)"
            
            return $instance
        }
        finally {
            # Remove from resolving set
            [void]$this.resolvingServices.Remove($name)
        }
    }
    
    # Resolve a service by type
    [object] ResolveByType([type]$serviceType) {
        $matches = @()
        
        foreach ($registration in $this.registrations.Values) {
            if ($registration.ServiceType -eq $serviceType) {
                $matches += $registration
            }
        }
        
        if ($matches.Count -eq 0) {
            throw "No service registered for type '$($serviceType.FullName)'"
        }
        
        if ($matches.Count -gt 1) {
            throw "Multiple services registered for type '$($serviceType.FullName)'. Use Resolve(name) instead."
        }
        
        return $this.Resolve($matches[0].Name)
    }
    
    # Try to resolve a service, return null if not found
    [object] TryResolve([string]$name) {
        try {
            return $this.Resolve($name)
        }
        catch {
            return $null
        }
    }
    
    # Check if a service is registered
    [bool] IsRegistered([string]$name) {
        return $this.registrations.ContainsKey($name)
    }
    
    # Get all registered service names
    [string[]] GetRegisteredServices() {
        return $this.registrations.Keys
    }
    
    # Lock the container (prevent further registrations)
    [void] Lock() {
        $this.isLocked = $true
        Write-Log -Level Debug -Message "Service container locked"
    }
    
    # Create a scoped container (for future use)
    [ServiceContainer] CreateScope() {
        # TODO: Implement scoped containers for request-scoped services
        throw "Scoped containers not yet implemented"
    }
    
    # Private helper methods
    hidden [void] ValidateNotLocked() {
        if ($this.isLocked) {
            throw "Service container is locked. No new registrations allowed."
        }
    }
    
    hidden [string[]] AnalyzeDependencies([type]$type) {
        $dependencies = @()
        
        # Get all constructors
        $constructors = $type.GetConstructors()
        
        if ($constructors.Count -eq 0) {
            return $dependencies
        }
        
        # Use the constructor with most parameters (convention)
        $constructor = $constructors | Sort-Object { $_.GetParameters().Count } -Descending | Select-Object -First 1
        
        foreach ($param in $constructor.GetParameters()) {
            # Look for a service that matches the parameter type
            foreach ($registration in $this.registrations.Values) {
                if ($registration.ServiceType -eq $param.ParameterType) {
                    $dependencies += $registration.Name
                    break
                }
            }
        }
        
        return $dependencies
    }
    
    hidden [object] CreateInstance([type]$type) {
        # Get all constructors
        $constructors = $type.GetConstructors()
        
        if ($constructors.Count -eq 0) {
            throw "Type '$($type.FullName)' has no public constructors"
        }
        
        # Try constructors from most to least parameters
        $sortedConstructors = $constructors | Sort-Object { $_.GetParameters().Count } -Descending
        
        foreach ($constructor in $sortedConstructors) {
            $parameters = $constructor.GetParameters()
            $args = @()
            $canResolve = $true
            
            foreach ($param in $parameters) {
                # Special handling for hashtable parameter (services container)
                if ($param.ParameterType -eq [hashtable]) {
                    # Create a hashtable proxy for the service container
                    $servicesProxy = @{}
                    foreach ($key in $this.registrations.Keys) {
                        $servicesProxy[$key] = $this.Resolve($key)
                    }
                    $args += $servicesProxy
                    continue
                }
                
                # Try to resolve by type
                $resolved = $false
                foreach ($registration in $this.registrations.Values) {
                    if ($registration.ServiceType -eq $param.ParameterType) {
                        try {
                            $args += $this.Resolve($registration.Name)
                            $resolved = $true
                            break
                        }
                        catch {
                            # Continue to next registration
                        }
                    }
                }
                
                if (-not $resolved) {
                    # Check if parameter has default value
                    if ($param.HasDefaultValue) {
                        $args += $param.DefaultValue
                    }
                    else {
                        $canResolve = $false
                        break
                    }
                }
            }
            
            if ($canResolve) {
                try {
                    return $constructor.Invoke($args)
                }
                catch {
                    Write-Log -Level Warning -Message "Failed to invoke constructor for $($type.FullName): $_"
                }
            }
        }
        
        throw "Could not create instance of type '$($type.FullName)'. Unable to resolve all constructor dependencies."
    }
}

# Global functions for module export
function New-ServiceContainer {
    <#
    .SYNOPSIS
    Creates a new service container instance
    
    .DESCRIPTION
    Creates a new dependency injection container for managing application services
    
    .EXAMPLE
    $container = New-ServiceContainer
    #>
    return [ServiceContainer]::new()
}

function Initialize-ServiceContainer {
    <#
    .SYNOPSIS
    Initializes the global service container with PMC Terminal services
    
    .DESCRIPTION
    Sets up all the standard services used by PMC Terminal with proper registration
    
    .PARAMETER Services
    Existing services hashtable to migrate to container (optional)
    
    .EXAMPLE
    $container = Initialize-ServiceContainer -Services $existingServices
    #>
    param(
        [hashtable]$Services = @{}
    )
    
    $container = New-ServiceContainer
    
    # Register existing service instances if provided
    foreach ($key in $Services.Keys) {
        if ($null -ne $Services[$key]) {
            $container.RegisterInstance($key, $Services[$key])
        }
    }
    
    Write-Log -Level Info -Message "Service container initialized with $($container.GetRegisteredServices().Count) services"
    
    return $container
}

# Export module members
Export-ModuleMember -Function New-ServiceContainer, Initialize-ServiceContainer