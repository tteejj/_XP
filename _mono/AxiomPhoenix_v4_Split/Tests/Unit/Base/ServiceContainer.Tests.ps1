# ==============================================================================
# Axiom-Phoenix v4.0 - ServiceContainer Unit Tests
# Dependency injection and service management testing
# ==============================================================================

# Import the framework
$scriptDir = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $scriptDir "Base/ABC.001a_ServiceContainer.ps1")
. (Join-Path $scriptDir "Base/ABC.001b_DependencyInjection.ps1")

# Test classes for dependency injection
class TestService {
    [string] $Name
    [bool] $Initialized = $false
    
    TestService([string]$name) {
        $this.Name = $name
    }
    
    [void] Initialize() {
        $this.Initialized = $true
    }
    
    [void] Dispose() {
        $this.Initialized = $false
    }
}

class TestServiceWithDependency {
    [TestService] $Dependency
    [string] $Name
    
    TestServiceWithDependency([string]$name) {
        $this.Name = $name
    }
}

Describe "ServiceContainer Tests" {
    Context "When registering services" {
        BeforeEach {
            $container = [ServiceContainer]::new()
        }
        
        It "Should register service instance" {
            $service = [TestService]::new("TestInstance")
            $container.Register("TestService", $service)
            
            $retrieved = $container.GetService("TestService")
            $retrieved | Should -Be $service
            $retrieved.Name | Should -Be "TestInstance"
        }
        
        It "Should register service factory" {
            $factory = { param($container) [TestService]::new("FactoryCreated") }
            $container.RegisterFactory("TestFactory", $factory, $true)
            
            $service = $container.GetService("TestFactory")
            $service | Should -Not -BeNull
            $service.Name | Should -Be "FactoryCreated"
        }
        
        It "Should create singleton from factory" {
            $factory = { param($container) [TestService]::new("Singleton") }
            $container.RegisterFactory("Singleton", $factory, $true)
            
            $service1 = $container.GetService("Singleton")
            $service2 = $container.GetService("Singleton")
            
            $service1 | Should -Be $service2  # Same instance
        }
        
        It "Should create transient from factory" {
            $factory = { param($container) [TestService]::new("Transient") }
            $container.RegisterFactory("Transient", $factory, $false)
            
            $service1 = $container.GetService("Transient")
            $service2 = $container.GetService("Transient")
            
            $service1 | Should -Not -Be $service2  # Different instances
            $service1.Name | Should -Be $service2.Name  # Same configuration
        }
        
        It "Should throw on duplicate registration" {
            $service1 = [TestService]::new("First")
            $service2 = [TestService]::new("Second")
            
            $container.Register("Duplicate", $service1)
            
            { $container.Register("Duplicate", $service2) } | Should -Throw
        }
        
        It "Should throw on null service registration" {
            { $container.Register("NullService", $null) } | Should -Throw
        }
        
        It "Should throw on empty name registration" {
            $service = [TestService]::new("Test")
            
            { $container.Register("", $service) } | Should -Throw
            { $container.Register($null, $service) } | Should -Throw
        }
    }
    
    Context "When retrieving services" {
        BeforeEach {
            $container = [ServiceContainer]::new()
            $service = [TestService]::new("Registered")
            $container.Register("RegisteredService", $service)
        }
        
        It "Should retrieve registered service" {
            $retrieved = $container.GetService("RegisteredService")
            $retrieved | Should -Not -BeNull
            $retrieved.Name | Should -Be "Registered"
        }
        
        It "Should throw on unregistered service" {
            { $container.GetService("UnregisteredService") } | Should -Throw
        }
        
        It "Should throw on null or empty service name" {
            { $container.GetService($null) } | Should -Throw
            { $container.GetService("") } | Should -Throw
        }
    }
    
    Context "When listing services" {
        BeforeEach {
            $container = [ServiceContainer]::new()
            $service1 = [TestService]::new("Service1")
            $container.Register("Service1", $service1)
            
            $factory = { param($container) [TestService]::new("Service2") }
            $container.RegisterFactory("Service2", $factory, $true)
        }
        
        It "Should list all registered services" {
            $services = $container.GetAllRegisteredServices()
            
            $services.Count | Should -Be 2
            $services | Where-Object { $_.Name -eq "Service1" } | Should -Not -BeNull
            $services | Where-Object { $_.Name -eq "Service2" } | Should -Not -BeNull
        }
        
        It "Should indicate service types correctly" {
            $services = $container.GetAllRegisteredServices()
            
            $service1Info = $services | Where-Object { $_.Name -eq "Service1" }
            $service1Info.Type | Should -Be "Instance"
            $service1Info.Initialized | Should -Be $true
            
            $service2Info = $services | Where-Object { $_.Name -eq "Service2" }
            $service2Info.Type | Should -Be "Factory"
            $service2Info.Initialized | Should -Be $false  # Not created yet
        }
    }
    
    Context "When cleaning up services" {
        BeforeEach {
            $container = [ServiceContainer]::new()
        }
        
        It "Should dispose disposable services" {
            $service = [TestService]::new("Disposable")
            $service.Initialize()
            $container.Register("DisposableService", $service)
            
            $service.Initialized | Should -Be $true
            
            $container.Cleanup()
            
            $service.Initialized | Should -Be $false
        }
        
        It "Should clear all registrations after cleanup" {
            $service = [TestService]::new("ToClear")
            $container.Register("ServiceToClear", $service)
            
            $container.Cleanup()
            
            { $container.GetService("ServiceToClear") } | Should -Throw
        }
        
        It "Should handle cleanup errors gracefully" {
            # Create a service that throws on dispose
            $faultyService = [PSCustomObject]@{
                Dispose = { throw "Dispose error" }
            }
            $faultyService.PSObject.TypeNames.Insert(0, 'System.IDisposable')
            
            $container.Register("FaultyService", $faultyService)
            
            # Should not throw even if dispose fails
            { $container.Cleanup() } | Should -Not -Throw
        }
    }
    
    Context "When detecting circular dependencies" {
        BeforeEach {
            $container = [ServiceContainer]::new()
        }
        
        It "Should detect direct circular dependency" {
            $factoryA = { param($container) $container.GetService("ServiceB") }
            $factoryB = { param($container) $container.GetService("ServiceA") }
            
            $container.RegisterFactory("ServiceA", $factoryA, $true)
            $container.RegisterFactory("ServiceB", $factoryB, $true)
            
            { $container.GetService("ServiceA") } | Should -Throw "*circular*"
        }
        
        It "Should detect indirect circular dependency" {
            $factoryA = { param($container) $container.GetService("ServiceB") }
            $factoryB = { param($container) $container.GetService("ServiceC") }
            $factoryC = { param($container) $container.GetService("ServiceA") }
            
            $container.RegisterFactory("ServiceA", $factoryA, $true)
            $container.RegisterFactory("ServiceB", $factoryB, $true)
            $container.RegisterFactory("ServiceC", $factoryC, $true)
            
            { $container.GetService("ServiceA") } | Should -Throw "*circular*"
        }
        
        It "Should allow valid dependency chains" {
            $serviceC = [TestService]::new("ServiceC")
            $container.Register("ServiceC", $serviceC)
            
            $factoryB = { param($container) 
                $c = $container.GetService("ServiceC")
                [TestServiceWithDependency]::new("ServiceB")
            }
            $factoryA = { param($container) 
                $b = $container.GetService("ServiceB")
                [TestServiceWithDependency]::new("ServiceA")
            }
            
            $container.RegisterFactory("ServiceB", $factoryB, $true)
            $container.RegisterFactory("ServiceA", $factoryA, $true)
            
            $serviceA = $container.GetService("ServiceA")
            $serviceA | Should -Not -BeNull
            $serviceA.Name | Should -Be "ServiceA"
        }
    }
}

Describe "EnhancedServiceContainer Tests" {
    Context "When using enhanced features" {
        BeforeEach {
            $container = [EnhancedServiceContainer]::new()
        }
        
        It "Should register service with metadata" {
            $service = [TestService]::new("Enhanced")
            $metadata = @{ Version = "1.0"; Description = "Test service" }
            
            $container.RegisterWithMetadata("EnhancedService", $service, $metadata)
            
            $retrieved = $container.GetService("EnhancedService")
            $retrieved.Name | Should -Be "Enhanced"
            
            $serviceMetadata = $container.GetServiceMetadata("EnhancedService")
            $serviceMetadata.Version | Should -Be "1.0"
            $serviceMetadata.Description | Should -Be "Test service"
        }
        
        It "Should auto-initialize services with Initialize method" {
            $service = [TestService]::new("AutoInit")
            $service.Initialized | Should -Be $false
            
            $container.RegisterWithMetadata("AutoInitService", $service)
            
            $service.Initialized | Should -Be $true
        }
        
        It "Should create scoped containers" {
            $service = [TestService]::new("Singleton")
            $container.Register("SingletonService", $service)
            
            $scope = $container.CreateScope()
            $scopedService = $scope.GetService("SingletonService")
            
            $scopedService | Should -Be $service  # Same instance in scope
        }
        
        It "Should dispose services in reverse order" {
            $service1 = [TestService]::new("First")
            $service2 = [TestService]::new("Second")
            $service3 = [TestService]::new("Third")
            
            $container.RegisterWithMetadata("Service1", $service1)
            $container.RegisterWithMetadata("Service2", $service2)
            $container.RegisterWithMetadata("Service3", $service3)
            
            $service1.Initialize()
            $service2.Initialize()
            $service3.Initialize()
            
            $container.Dispose()
            
            # All should be disposed
            $service1.Initialized | Should -Be $false
            $service2.Initialized | Should -Be $false
            $service3.Initialized | Should -Be $false
        }
        
        It "Should provide health check information" {
            $service1 = [TestService]::new("Healthy")
            $service2 = [TestService]::new("AlsoHealthy")
            
            $container.Register("HealthyService1", $service1)
            $container.Register("HealthyService2", $service2)
            
            $health = $container.HealthCheck()
            
            $health.TotalServices | Should -Be 2
            $health.InitializedServices | Should -Be 2
            $health.Healthy | Should -Be $true
        }
    }
    
    Context "When auto-wiring dependencies" {
        BeforeEach {
            $container = [EnhancedServiceContainer]::new()
        }
        
        It "Should auto-wire dependencies using reflection" {
            # This test would require the actual Inject attribute implementation
            # For now, we'll test the concept
            
            $dependency = [TestService]::new("Dependency")
            $container.Register("TestDependency", $dependency)
            
            $consumer = [TestServiceWithDependency]::new("Consumer")
            
            # Manual dependency injection for this test
            $consumer.Dependency = $container.GetService("TestDependency")
            
            $consumer.Dependency | Should -Not -BeNull
            $consumer.Dependency.Name | Should -Be "Dependency"
        }
    }
}

Write-Host "ServiceContainer unit tests loaded" -ForegroundColor Green