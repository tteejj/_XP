# ==============================================================================
# Axiom-Phoenix v4.0 - Service Container
# Provides a robust, centralized dependency injection container with lifecycle management.
# ==============================================================================
#Requires -Version 7.2

function Initialize-ServiceContainer {
    <#
    .SYNOPSIS
    Creates and returns a new instance of the ServiceContainer.
    #>
    [CmdletBinding()]
    param()
    
    return Invoke-WithErrorHandling -Component "ServiceContainer.Initialize" -Context "Creating new service container instance" -ScriptBlock {
        Write-Verbose "ServiceContainer: Initializing new instance."
        return [ServiceContainer]::new()
    }
}

# The ServiceContainer is a central registry for application-wide services.
# It supports lazy initialization, singleton/transient lifestyles, circular
# dependency detection, and managed resource cleanup.
class ServiceContainer {
    #region Private State
    hidden [hashtable] $_services = @{}
    hidden [hashtable] $_serviceFactories = @{}
    #endregion

    #region Constructor
    ServiceContainer() {
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "ServiceContainer created."
        }
        Write-Verbose "ServiceContainer: Instance constructed."
    }
    #endregion

    #region Public Methods
    # Registers an already created service instance (eager loading).
    [void] Register(
        # FIX: Removed [Parameter] and [Validate] attributes
        [string]$name,
        [object]$serviceInstance
    ) {
        Invoke-WithErrorHandling -Component "ServiceContainer" -Context "Register" -AdditionalData @{ ServiceName = $name } -ScriptBlock {
            # FIX: Added manual validation
            if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
            if ($null -eq $serviceInstance) { throw [System.ArgumentNullException]::new("serviceInstance") }

            if ($this.{_services}.ContainsKey($name) -or $this.{_serviceFactories}.ContainsKey($name)) {
                throw [System.InvalidOperationException]::new("A service or factory with the name '$name' is already registered.")
            }

            $this.{_services}[$name] = $serviceInstance
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Debug -Message "Registered eager service instance: '$name'."
            }
            Write-Verbose "ServiceContainer: Registered eager instance for '$name' of type '$($serviceInstance.GetType().Name)'."
        }
    }

    # Registers a factory scriptblock used to create the service on-demand (lazy loading).
    [void] RegisterFactory(
        # FIX: Removed [Parameter] and [Validate] attributes
        [string]$name,
        [scriptblock]$factory,
        [bool]$isSingleton = $true
    ) {
        Invoke-WithErrorHandling -Component "ServiceContainer" -Context "RegisterFactory" -AdditionalData @{ ServiceName = $name } -ScriptBlock {
            # FIX: Added manual validation
            if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
            if ($null -eq $factory) { throw [System.ArgumentNullException]::new("factory") }

            if ($this.{_services}.ContainsKey($name) -or $this.{_serviceFactories}.ContainsKey($name)) {
                throw [System.InvalidOperationException]::new("A service or factory with the name '$name' is already registered.")
            }
            
            $this.{_serviceFactories}[$name] = @{
                Factory = $factory
                IsSingleton = $isSingleton
                Instance = $null # To hold the singleton instance once created
            }
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Debug -Message "Registered service factory: '$name' (Singleton: $isSingleton)."
            }
            Write-Verbose "ServiceContainer: Registered factory for '$name' (Singleton: $isSingleton)."
        }
    }

    # Retrieves a service by its name.
    [object] GetService([string]$name) {
        return Invoke-WithErrorHandling -Component "ServiceContainer" -Context "GetService" -AdditionalData @{ ServiceName = $name } -ScriptBlock {
            # FIX: Added manual validation
            if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }

            # 1. Return from eager-loaded services
            if ($this.{_services}.ContainsKey($name)) {
                Write-Verbose "ServiceContainer: Returning eager-loaded instance of '$name'."
                return $this.{_services}[$name]
            }

            # 2. Check for a factory
            if ($this.{_serviceFactories}.ContainsKey($name)) {
                return $this._InitializeServiceFromFactory($name, [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase))
            }

            # 3. If not found, throw a detailed error
            $available = $this.GetAllRegisteredServices() | Select-Object -ExpandProperty Name
            throw [System.InvalidOperationException]::new("Service '$name' not found. Available services: $($available -join ', ')")
        }
    }
    
    # Retrieves a list of all registered services and their status.
    [object[]] GetAllRegisteredServices() {
        $list = [System.Collections.Generic.List[object]]::new()
        
        foreach ($key in $this.{_services}.Keys) {
            $list.Add([pscustomobject]@{
                Name = $key
                Type = 'Instance'
                Initialized = $true
                Lifestyle = 'Singleton' # Eager instances are always singletons
            })
        }
        
        foreach ($key in $this.{_serviceFactories}.Keys) {
            $factoryInfo = $this.{_serviceFactories}[$key]
            $list.Add([pscustomobject]@{
                Name = $key
                Type = 'Factory'
                Initialized = ($null -ne $factoryInfo.Instance)
                Lifestyle = if ($factoryInfo.IsSingleton) { 'Singleton' } else { 'Transient' }
            })
        }
        
        return $list.ToArray() | Sort-Object Name
    }

    # Cleans up all managed singleton services that implement IDisposable.
    [void] Cleanup() {
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "ServiceContainer cleanup initiated."
        }
        Write-Verbose "ServiceContainer: Initiating cleanup of disposable singleton services."
        
        # Collect all singleton instances
        $instancesToClean = [System.Collections.Generic.List[object]]::new()
        $this.{_services}.Values | ForEach-Object { $instancesToClean.Add($_) }
        $this.{_serviceFactories}.Values | Where-Object { $_.IsSingleton -and $_.Instance } | ForEach-Object { $instancesToClean.Add($_.Instance) }

        foreach ($service in $instancesToClean) {
            if ($service -is [System.IDisposable]) {
                try {
                    Write-Verbose "ServiceContainer: Disposing service of type '$($service.GetType().FullName)'."
                    $service.Dispose()
                } catch {
                    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Error -Message "Error disposing service of type '$($service.GetType().FullName)': $($_.Exception.Message)"
                    }
                }
            }
        }
        
        $this.{_services}.Clear()
        $this.{_serviceFactories}.Clear()
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "ServiceContainer cleanup complete."
        }
        Write-Verbose "ServiceContainer: Cleanup complete. All service registries cleared."
    }
    #endregion

    #region Private Methods
    # The core logic for instantiating a service from its factory.
    hidden [object] _InitializeServiceFromFactory([string]$name, [System.Collections.Generic.HashSet[string]]$resolutionChain) {
        $factoryInfo = $this.{_serviceFactories}[$name]
        
        # For singletons, if an instance already exists, return it immediately.
        if ($factoryInfo.IsSingleton -and $null -ne $factoryInfo.Instance) {
            Write-Verbose "ServiceContainer: Returning cached singleton instance of '$name'."
            return $factoryInfo.Instance
        }

        # Circular dependency detection
        if ($resolutionChain.Contains($name)) {
            $chain = ($resolutionChain -join ' -> ') + " -> $name"
            throw [System.InvalidOperationException]::new("Circular dependency detected while resolving service '$name'. Chain: $chain")
        }
        [void]$resolutionChain.Add($name)
        
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "Instantiating service '$name' from factory."
        }
        Write-Verbose "ServiceContainer: Invoking factory to create instance of '$name'."
        
        # Invoke the factory, passing the container itself as an argument.
        $serviceInstance = & $factoryInfo.Factory $this

        # If it's a singleton, cache the new instance.
        if ($factoryInfo.IsSingleton) {
            $factoryInfo.Instance = $serviceInstance
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Debug -Message "Cached singleton instance of service '$name'."
            }
            Write-Verbose "ServiceContainer: Cached new singleton instance of '$name'."
        }

        # Unwind the resolution chain
        [void]$resolutionChain.Remove($name)
        
        return $serviceInstance
    }
    #endregion
}

# Export the factory function
Export-ModuleMember -Function Initialize-ServiceContainer