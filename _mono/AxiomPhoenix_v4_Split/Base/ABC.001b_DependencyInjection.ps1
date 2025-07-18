# ==============================================================================
# Axiom-Phoenix v4.0 - Enhanced Dependency Injection
# Improved DI with interfaces, lifecycle management, and type safety
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent

#region DI Interfaces and Attributes

# Service lifecycle interfaces - Using PowerShell approach
# IDisposableService - Services that need cleanup
# IInitializableService - Services that need initialization

# Service attribute for marking injectable services
class ServiceAttribute : System.Attribute {
    [string] $Name
    [string] $Lifestyle = "Singleton"  # Singleton, Transient, Scoped
    
    ServiceAttribute([string]$name) {
        $this.Name = $name
    }
    
    ServiceAttribute([string]$name, [string]$lifestyle) {
        $this.Name = $name
        $this.Lifestyle = $lifestyle
    }
}

# Dependency attribute for marking injection points
class InjectAttribute : System.Attribute {
    [string] $ServiceName
    [bool] $Required = $true
    
    InjectAttribute([string]$serviceName) {
        $this.ServiceName = $serviceName
    }
    
    InjectAttribute([string]$serviceName, [bool]$required) {
        $this.ServiceName = $serviceName
        $this.Required = $required
    }
}

#endregion

#region Enhanced Service Container

class EnhancedServiceContainer : ServiceContainer {
    hidden [ConcurrentDictionary[string, object]] $_scopedServices
    hidden [hashtable] $_serviceMetadata = @{}
    hidden [List[string]] $_initializationOrder = [List[string]]::new()
    hidden [bool] $_isDisposed = $false
    
    EnhancedServiceContainer() : base() {
        $this._scopedServices = [ConcurrentDictionary[string, object]]::new()
    }
    
    # Register service with metadata
    [void] RegisterWithMetadata([string]$name, [object]$serviceInstance, [hashtable]$metadata = @{}) {
        $this.Register($name, $serviceInstance)
        $this._serviceMetadata[$name] = $metadata
        
        # Track initialization order for proper disposal
        $this._initializationOrder.Add($name)
        
        # Auto-initialize if service has Initialize method
        if ($serviceInstance.PSObject.Methods['Initialize']) {
            $serviceInstance.Initialize()
        }
    }
    
    # Auto-wire dependencies using reflection
    [void] AutoWire([object]$instance) {
        $type = $instance.GetType()
        $properties = $type.GetProperties()
        
        foreach ($property in $properties) {
            $injectAttr = $property.GetCustomAttribute([InjectAttribute])
            if ($injectAttr) {
                try {
                    $service = $this.GetService($injectAttr.ServiceName)
                    $property.SetValue($instance, $service)
                } catch {
                    if ($injectAttr.Required) {
                        throw "Required dependency '$($injectAttr.ServiceName)' not found for property '$($property.Name)'"
                    }
                }
            }
        }
    }
    
    # Create scoped container for request/screen-scoped services
    [EnhancedServiceContainer] CreateScope() {
        $scope = [EnhancedServiceContainer]::new()
        
        # Copy singleton services to scope
        foreach ($kvp in $this._services.GetEnumerator()) {
            $scope._services[$kvp.Key] = $kvp.Value
        }
        
        # Copy factories
        foreach ($kvp in $this._serviceFactories.GetEnumerator()) {
            $scope._serviceFactories[$kvp.Key] = $kvp.Value
        }
        
        return $scope
    }
    
    # Dispose all services in reverse initialization order
    [void] Dispose() {
        if ($this._isDisposed) { return }
        
        # Dispose in reverse order
        for ($i = $this._initializationOrder.Count - 1; $i -ge 0; $i--) {
            $serviceName = $this._initializationOrder[$i]
            $service = $this._services[$serviceName]
            
            if ($service.PSObject.Methods['Dispose']) {
                try {
                    $service.Dispose()
                } catch {
                    Write-Log -Level Warning -Message "Error disposing service '$serviceName': $($_.Exception.Message)"
                }
            }
        }
        
        # Dispose scoped services
        foreach ($service in $this._scopedServices.Values) {
            if ($service.PSObject.Methods['Dispose']) {
                try {
                    $service.Dispose()
                } catch {
                    Write-Log -Level Warning -Message "Error disposing scoped service: $($_.Exception.Message)"
                }
            }
        }
        
        $this._services.Clear()
        $this._serviceFactories.Clear()
        $this._scopedServices.Clear()
        $this._serviceMetadata.Clear()
        $this._initializationOrder.Clear()
        $this._isDisposed = $true
    }
    
    # Get service metadata
    [hashtable] GetServiceMetadata([string]$serviceName) {
        if ($this._serviceMetadata.ContainsKey($serviceName)) {
            return $this._serviceMetadata[$serviceName]
        }
        return @{}
    }
    
    # Health check for all services
    [hashtable] HealthCheck() {
        $report = @{
            TotalServices = $this._services.Count + $this._serviceFactories.Count
            InitializedServices = $this._services.Count
            FactoryServices = $this._serviceFactories.Count
            ScopedServices = $this._scopedServices.Count
            FailedServices = @()
            Healthy = $true
        }
        
        # Check each service
        foreach ($kvp in $this._services.GetEnumerator()) {
            try {
                $service = $kvp.Value
                if ($service -and $service.PSObject.Methods['HealthCheck']) {
                    $serviceHealth = $service.HealthCheck()
                    if (-not $serviceHealth) {
                        $report.FailedServices += $kvp.Key
                        $report.Healthy = $false
                    }
                }
            } catch {
                $report.FailedServices += $kvp.Key
                $report.Healthy = $false
            }
        }
        
        return $report
    }
}

#endregion

#region Service Registration Helpers

# Auto-register services from assemblies/modules
function Register-ServicesFromModule {
    param(
        [EnhancedServiceContainer]$container,
        [string]$ModulePath
    )
    
    $types = Get-ChildItem $ModulePath -Filter "*.ps1" | ForEach-Object {
        try {
            . $_.FullName
            # Get classes with ServiceAttribute
            # Note: PowerShell reflection for classes is limited, this is a simplified approach
        } catch {
            Write-Log -Level Warning -Message "Failed to load module $($_.Name): $($_.Exception.Message)"
        }
    }
}

# Register service with type checking
function Register-TypedService {
    param(
        [EnhancedServiceContainer]$container,
        [string]$name,
        [object]$instance,
        [type]$interfaceType = $null
    )
    
    if ($interfaceType -and -not ($instance -is $interfaceType)) {
        throw "Service '$name' does not implement required interface '$($interfaceType.Name)'"
    }
    
    $metadata = @{
        RegisteredAt = [DateTime]::Now
        InterfaceType = $interfaceType?.Name
        ImplementationType = $instance.GetType().Name
    }
    
    $container.RegisterWithMetadata($name, $instance, $metadata)
}

#endregion

Write-Host "Enhanced Dependency Injection system loaded" -ForegroundColor Green