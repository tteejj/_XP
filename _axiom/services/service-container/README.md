# service-container Module

## Overview
The `service-container` module provides a robust, centralized dependency injection container with lifecycle management for the PMC Terminal application. It supports lazy initialization, singleton/transient lifestyles, circular dependency detection, and managed resource cleanup.

## Features
- **Dependency Injection** - Centralized service registration and resolution
- **Lifecycle Management** - Automatic initialization and cleanup of services
- **Lazy Loading** - Services are created only when needed
- **Singleton/Transient Support** - Control service lifetimes
- **Circular Dependency Detection** - Prevents infinite loops during resolution
- **Resource Cleanup** - Automatic disposal of `IDisposable` services
- **Diagnostic Capabilities** - Introspection of registered services

## Service Container Class

### ServiceContainer Methods

#### Registration Methods

##### Register()
Registers an already created service instance (eager loading).

```powershell
$container = Initialize-ServiceContainer
$logger = Initialize-Logger
$container.Register("Logger", $logger)
```

##### RegisterFactory()
Registers a factory scriptblock for lazy service creation.

```powershell
# Singleton factory (default)
$container.RegisterFactory("DataManager", { 
    param($container)
    Initialize-DataManager 
})

# Transient factory
$container.RegisterFactory("HttpClient", { 
    param($container)
    New-Object System.Net.Http.HttpClient 
}, $false)
```

**Parameters:**
- `name` (Required) - Unique service name
- `factory` (Required) - ScriptBlock that creates the service
- `isSingleton` (Optional) - Whether to cache the instance (default: `$true`)

#### Resolution Methods

##### GetService()
Retrieves a service by name, creating it if necessary.

```powershell
$dataManager = $container.GetService("DataManager")
$httpClient = $container.GetService("HttpClient")
```

**Error Handling:**
- Throws `InvalidOperationException` if service not found
- Lists available services in error message
- Detects and prevents circular dependencies

##### GetAllRegisteredServices()
Returns diagnostic information about all registered services.

```powershell
$services = $container.GetAllRegisteredServices()
$services | Format-Table Name, Type, Initialized, Lifestyle
```

**Output Structure:**
```powershell
@{
    Name = "ServiceName"
    Type = "Instance" | "Factory"
    Initialized = $true | $false
    Lifestyle = "Singleton" | "Transient"
}
```

#### Lifecycle Methods

##### Cleanup()
Automatically disposes all singleton services that implement `IDisposable`.

```powershell
try {
    # Application code
} finally {
    $container.Cleanup()
}
```

**Process:**
1. Finds all singleton service instances
2. Checks if they implement `IDisposable`
3. Calls `Dispose()` on each disposable service
4. Clears all service registrations

## Functions

### Initialize-ServiceContainer
Factory function that creates and returns a new `ServiceContainer` instance.

```powershell
$container = Initialize-ServiceContainer
```

## Usage Patterns

### Basic Service Registration

```powershell
# Initialize container
$container = Initialize-ServiceContainer

# Register eager services
$logger = Initialize-Logger
$container.Register("Logger", $logger)

# Register lazy services
$container.RegisterFactory("DataManager", { 
    param($c)
    Initialize-DataManager -Logger $c.GetService("Logger")
})

# Use services
$dataManager = $container.GetService("DataManager")
```

### Service Dependencies

```powershell
# Services can depend on other services
$container.RegisterFactory("EmailService", {
    param($c)
    $logger = $c.GetService("Logger")
    $config = $c.GetService("Configuration")
    New-EmailService -Logger $logger -Config $config
})

$container.RegisterFactory("NotificationService", {
    param($c)
    $email = $c.GetService("EmailService")
    $sms = $c.GetService("SmsService")
    New-NotificationService -Email $email -Sms $sms
})
```

### Transient Services

```powershell
# Each request creates a new instance
$container.RegisterFactory("HttpClient", {
    param($c)
    New-Object System.Net.Http.HttpClient
}, $false) # $false = transient

$client1 = $container.GetService("HttpClient")
$client2 = $container.GetService("HttpClient")
# $client1 -ne $client2 (different instances)
```

### Disposable Services

```powershell
# Services that implement IDisposable
$container.RegisterFactory("DatabaseConnection", {
    param($c)
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = "..."
    $connection.Open()
    return $connection
})

# Automatic cleanup
try {
    $db = $container.GetService("DatabaseConnection")
    # Use database
} finally {
    $container.Cleanup() # Automatically calls Dispose() on connection
}
```

## Advanced Features

### Circular Dependency Detection

The container automatically detects circular dependencies:

```powershell
# This will throw an InvalidOperationException
$container.RegisterFactory("ServiceA", {
    param($c)
    $b = $c.GetService("ServiceB")
    return New-ServiceA -B $b
})

$container.RegisterFactory("ServiceB", {
    param($c)
    $a = $c.GetService("ServiceA")
    return New-ServiceB -A $a
})

# Throws: "Circular dependency detected: ServiceA -> ServiceB -> ServiceA"
$serviceA = $container.GetService("ServiceA")
```

### Service Introspection

```powershell
# Check what services are registered
$services = $container.GetAllRegisteredServices()

# Find uninitialized services
$uninitializedServices = $services | Where-Object { -not $_.Initialized }

# Count singleton vs transient
$singletons = $services | Where-Object { $_.Lifestyle -eq "Singleton" }
$transients = $services | Where-Object { $_.Lifestyle -eq "Transient" }
```

## Error Handling

### Service Not Found
```powershell
try {
    $service = $container.GetService("NonExistentService")
} catch [System.InvalidOperationException] {
    Write-Host "Service not found: $($_.Exception.Message)"
    # Message includes list of available services
}
```

### Circular Dependencies
```powershell
try {
    $service = $container.GetService("ServiceA")
} catch [System.InvalidOperationException] {
    if ($_.Exception.Message -match "Circular dependency") {
        Write-Host "Circular dependency detected: $($_.Exception.Message)"
    }
}
```

### Registration Conflicts
```powershell
try {
    $container.Register("Logger", $logger1)
    $container.Register("Logger", $logger2) # Throws exception
} catch [System.InvalidOperationException] {
    Write-Host "Service already registered: $($_.Exception.Message)"
}
```

## Best Practices

### 1. Initialize Early
```powershell
# Initialize container at application startup
$container = Initialize-ServiceContainer
```

### 2. Use Factories for Complex Services
```powershell
# Prefer factories over eager registration
$container.RegisterFactory("ComplexService", {
    param($c)
    $dependency1 = $c.GetService("Dependency1")
    $dependency2 = $c.GetService("Dependency2")
    New-ComplexService -Dep1 $dependency1 -Dep2 $dependency2
})
```

### 3. Implement IDisposable for Resources
```powershell
class MyService : IDisposable {
    [void] Dispose() {
        # Clean up resources
    }
}
```

### 4. Use Meaningful Service Names
```powershell
# Good
$container.RegisterFactory("DatabaseConnectionPool", $factory)

# Bad
$container.RegisterFactory("DB", $factory)
```

### 5. Handle Dependencies Explicitly
```powershell
# Explicit dependency injection
$container.RegisterFactory("EmailService", {
    param($c)
    $logger = $c.GetService("Logger")
    $config = $c.GetService("Configuration")
    New-EmailService -Logger $logger -Config $config
})
```

## Integration with Application

### Application Startup
```powershell
# Create container
$container = Initialize-ServiceContainer

# Register core services
$container.RegisterFactory("Logger", { Initialize-Logger })
$container.RegisterFactory("Configuration", { Initialize-Configuration })

# Register application services
$container.RegisterFactory("DataManager", { 
    param($c)
    Initialize-DataManager -Logger $c.GetService("Logger")
})

# Register UI services
$container.RegisterFactory("ThemeManager", {
    param($c)
    Initialize-ThemeManager -Logger $c.GetService("Logger")
})
```

### Application Shutdown
```powershell
try {
    # Run application
    Start-Application $container
} finally {
    # Cleanup all services
    $container.Cleanup()
}
```

## Performance Considerations

- **Lazy Loading** - Services are created only when needed
- **Singleton Caching** - Instances are cached for reuse
- **Efficient Resolution** - O(1) lookup for registered services
- **Minimal Overhead** - Container adds negligible performance cost

## Thread Safety

The container is designed for single-threaded use within PowerShell. For multi-threaded scenarios:
- Create separate containers per thread
- Use thread-safe service implementations
- Synchronize access to shared resources

## Dependencies
- **exceptions** - For structured error handling with `Invoke-WithErrorHandling`
- **PowerShell 7.0+** - For advanced language features and .NET integration

## Common Patterns

### Repository Pattern
```powershell
$container.RegisterFactory("UserRepository", {
    param($c)
    $db = $c.GetService("DatabaseConnection")
    New-UserRepository -Connection $db
})
```

### Service Locator Pattern
```powershell
# Pass container to services that need to resolve dependencies
$container.RegisterFactory("OrchestrationService", {
    param($c)
    New-OrchestrationService -ServiceContainer $c
})
```

### Factory Pattern
```powershell
$container.RegisterFactory("CommandFactory", {
    param($c)
    New-CommandFactory -ServiceContainer $c
})
```

The service container provides a robust foundation for building maintainable, testable, and well-architected PowerShell applications with proper separation of concerns and dependency management.
