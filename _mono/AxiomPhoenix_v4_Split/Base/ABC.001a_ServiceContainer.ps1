# ==============================================================================
# Axiom-Phoenix v4.0 - Base Classes (Load First)
# Core framework classes with NO external dependencies
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ABC.###" to find specific sections.
# Each section ends with "END_PAGE: ABC.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Management.Automation
using namespace System.Threading

# Disable verbose output during TUI rendering
$script:TuiVerbosePreference = 'SilentlyContinue'

#region ServiceContainer Class
class ServiceContainer {
    hidden [hashtable] $_services = @{}
    hidden [hashtable] $_serviceFactories = @{}

    ServiceContainer() {
        # Don't use Write-Log during construction - Logger doesn't exist yet
        Write-Verbose "ServiceContainer: Instance constructed."
    }

    [void] Register([string]$name, [object]$serviceInstance) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
        if ($null -eq $serviceInstance) { throw [System.ArgumentNullException]::new("serviceInstance") }

        if ($this._services.ContainsKey($name) -or $this._serviceFactories.ContainsKey($name)) {
            throw [System.InvalidOperationException]::new("A service or factory with the name '$name' is already registered.")
        }

        $this._services[$name] = $serviceInstance
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "Registered eager service instance: '$name'."
        }
        Write-Verbose "ServiceContainer: Registered eager instance for '$name' of type '$($serviceInstance.GetType().Name)'."
    }

    [void] RegisterFactory([string]$name, [scriptblock]$factory, [bool]$isSingleton = $true) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
        if ($null -eq $factory) { throw [System.ArgumentNullException]::new("factory") }

        if ($this._services.ContainsKey($name) -or $this._serviceFactories.ContainsKey($name)) {
            throw [System.InvalidOperationException]::new("A service or factory with the name '$name' is already registered.")
        }
        
        $this._serviceFactories[$name] = @{
            Factory = $factory
            IsSingleton = $isSingleton
            Instance = $null
        }
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "Registered service factory: '$name' (Singleton: $isSingleton)."
        }
        Write-Verbose "ServiceContainer: Registered factory for '$name' (Singleton: $isSingleton)."
    }

    [object] GetService([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }

        if ($this._services.ContainsKey($name)) {
            Write-Verbose "ServiceContainer: Returning eager-loaded instance of '$name'."
            return $this._services[$name]
        }

        if ($this._serviceFactories.ContainsKey($name)) {
            return $this._InitializeServiceFromFactory($name, [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase))
        }

        $available = $this.GetAllRegisteredServices() | Select-Object -ExpandProperty Name
        throw [System.InvalidOperationException]::new("Service '$name' not found. Available services: $($available -join ', ')")
    }
    
    [object[]] GetAllRegisteredServices() {
        $list = [System.Collections.Generic.List[object]]::new()
        
        foreach ($key in $this._services.Keys) {
            $list.Add([pscustomobject]@{
                Name = $key
                Type = 'Instance'
                Initialized = $true
                Lifestyle = 'Singleton'
            })
        }
        
        foreach ($key in $this._serviceFactories.Keys) {
            $factoryInfo = $this._serviceFactories[$key]
            $lifestyle = 'Transient'
            if ($factoryInfo.IsSingleton) { $lifestyle = 'Singleton' }
            $list.Add([pscustomobject]@{
                Name = $key
                Type = 'Factory'
                Initialized = ($null -ne $factoryInfo.Instance)
                Lifestyle = $lifestyle
            })
        }
        
        return $list.ToArray() | Sort-Object Name
    }

    [void] Cleanup() {
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "ServiceContainer cleanup initiated."
        }
        Write-Verbose "ServiceContainer: Initiating cleanup of disposable singleton services."
        
        $instancesToClean = [System.Collections.Generic.List[object]]::new()
        $this._services.Values | ForEach-Object { $instancesToClean.Add($_) }
        $this._serviceFactories.Values | Where-Object { $_.IsSingleton -and $_.Instance } | ForEach-Object { $instancesToClean.Add($_.Instance) }

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
        
        $this._services.Clear()
        $this._serviceFactories.Clear()
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "ServiceContainer cleanup complete."
        }
        Write-Verbose "ServiceContainer: Cleanup complete. All service registries cleared."
    }

    hidden [object] _InitializeServiceFromFactory([string]$name, [System.Collections.Generic.HashSet[string]]$resolutionChain) {
        $factoryInfo = $this._serviceFactories[$name]
        
        if ($factoryInfo.IsSingleton -and $null -ne $factoryInfo.Instance) {
            Write-Verbose "ServiceContainer: Returning cached singleton instance of '$name'."
            return $factoryInfo.Instance
        }

        if ($resolutionChain.Contains($name)) {
            $chain = ($resolutionChain -join ' -> ') + " -> $name"
            throw [System.InvalidOperationException]::new("Circular dependency detected while resolving service '$name'. Chain: $chain")
        }
        [void]$resolutionChain.Add($name)
        
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "Instantiating service '$name' from factory."
        }
        Write-Verbose "ServiceContainer: Invoking factory to create instance of '$name'."
        
        $serviceInstance = & $factoryInfo.Factory $this

        if ($factoryInfo.IsSingleton) {
            $factoryInfo.Instance = $serviceInstance
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Debug -Message "Cached singleton instance of service '$name'."
            }
            Write-Verbose "ServiceContainer: Cached new singleton instance of '$name'."
        }

        [void]$resolutionChain.Remove($name)
        
        return $serviceInstance
    }
}
#endregion
#<!-- END_PAGE: ABC.007 -->