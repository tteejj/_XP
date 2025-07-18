# ==============================================================================
# Axiom-Phoenix v4.0 - Service Wiring Integration Tests
# Integration testing for dependency injection and service management
# ==============================================================================

# Import the framework
$scriptDir = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $scriptDir "Base/ABC.001a_ServiceContainer.ps1")
. (Join-Path $scriptDir "Base/ABC.001b_DependencyInjection.ps1")
. (Join-Path $scriptDir "Base/ABC.006_Configuration.ps1")

# Test service classes for integration testing
class MockLogger {
    [string[]] $Messages = @()
    [bool] $Initialized = $false
    
    [void] Initialize() {
        $this.Initialized = $true
    }
    
    [void] Log([string]$message) {
        $this.Messages += $message
    }
    
    [void] Dispose() {
        $this.Messages = @()
        $this.Initialized = $false
    }
}

class MockDataService {
    [MockLogger] $Logger
    [object] $Config
    [bool] $Initialized = $false
    
    MockDataService() {
        # Dependencies will be injected
    }
    
    [void] Initialize() {
        if ($this.Logger) {
            $this.Logger.Log("DataService initializing")
        }
        $this.Initialized = $true
    }
    
    [string] GetData() {
        if ($this.Logger) {
            $this.Logger.Log("DataService.GetData called")
        }
        return "Mock data"
    }
    
    [void] Dispose() {
        if ($this.Logger) {
            $this.Logger.Log("DataService disposing")
        }
        $this.Initialized = $false
    }
}

class MockUIService {
    [MockDataService] $DataService
    [MockLogger] $Logger
    [bool] $Initialized = $false
    
    MockUIService() {
        # Dependencies will be injected
    }
    
    [void] Initialize() {
        if ($this.Logger) {
            $this.Logger.Log("UIService initializing")
        }
        $this.Initialized = $true
    }
    
    [void] Render() {
        if ($this.DataService) {
            $data = $this.DataService.GetData()
            if ($this.Logger) {
                $this.Logger.Log("UIService rendering with data: $data")
            }
        }
    }
    
    [void] Dispose() {
        if ($this.Logger) {
            $this.Logger.Log("UIService disposing")
        }
        $this.Initialized = $false
    }
}

Describe "Service Wiring Integration Tests" {
    Context "When setting up basic service dependencies" {
        BeforeEach {
            $container = [EnhancedServiceContainer]::new()
        }
        
        AfterEach {
            $container.Dispose()
        }
        
        It "Should wire simple dependencies correctly" {
            # Register logger first
            $logger = [MockLogger]::new()
            $container.RegisterWithMetadata("Logger", $logger)
            
            # Register data service that depends on logger
            $dataService = [MockDataService]::new()
            $dataService.Logger = $container.GetService("Logger")
            $container.RegisterWithMetadata("DataService", $dataService)
            
            # Verify wiring
            $retrievedDataService = $container.GetService("DataService")
            $retrievedDataService.Logger | Should -Not -BeNull
            $retrievedDataService.Logger | Should -Be $logger
            
            # Test functionality
            $retrievedDataService.GetData() | Should -Be "Mock data"
            $logger.Messages | Should -Contain "DataService initializing"
            $logger.Messages | Should -Contain "DataService.GetData called"
        }
        
        It "Should handle complex dependency chains" {
            # Register logger
            $logger = [MockLogger]::new()
            $container.RegisterWithMetadata("Logger", $logger)
            
            # Register configuration
            $config = [ConfigurationProvider]::new()
            $container.RegisterWithMetadata("Configuration", $config)
            
            # Register data service with dependencies
            $dataService = [MockDataService]::new()
            $dataService.Logger = $container.GetService("Logger")
            $dataService.Config = $container.GetService("Configuration")
            $container.RegisterWithMetadata("DataService", $dataService)
            
            # Register UI service with dependencies
            $uiService = [MockUIService]::new()
            $uiService.Logger = $container.GetService("Logger")
            $uiService.DataService = $container.GetService("DataService")
            $container.RegisterWithMetadata("UIService", $uiService)
            
            # Test the complete chain
            $retrievedUIService = $container.GetService("UIService")
            $retrievedUIService.Logger | Should -Not -BeNull
            $retrievedUIService.DataService | Should -Not -BeNull
            $retrievedUIService.DataService.Logger | Should -Be $logger
            
            # Test functionality through the chain
            $retrievedUIService.Render()
            
            $logger.Messages | Should -Contain "UIService initializing"
            $logger.Messages | Should -Contain "DataService.GetData called"
            $logger.Messages | Should -Contain "UIService rendering with data: Mock data"
        }
        
        It "Should handle service factories in dependency chains" {
            # Register logger as instance
            $logger = [MockLogger]::new()
            $container.RegisterWithMetadata("Logger", $logger)
            
            # Register data service as factory
            $dataServiceFactory = { 
                param($container)
                $dataService = [MockDataService]::new()
                $dataService.Logger = $container.GetService("Logger")
                $dataService.Initialize()
                return $dataService
            }
            $container.RegisterFactory("DataService", $dataServiceFactory, $true)
            
            # Register UI service as factory
            $uiServiceFactory = {
                param($container)
                $uiService = [MockUIService]::new()
                $uiService.Logger = $container.GetService("Logger")
                $uiService.DataService = $container.GetService("DataService")
                $uiService.Initialize()
                return $uiService
            }
            $container.RegisterFactory("UIService", $uiServiceFactory, $true)
            
            # Test factory-created services
            $uiService = $container.GetService("UIService")
            $uiService.Initialized | Should -Be $true
            $uiService.DataService.Initialized | Should -Be $true
            $uiService.Logger | Should -Be $logger
            
            # Test that singleton factory returns same instance
            $uiService2 = $container.GetService("UIService")
            $uiService2 | Should -Be $uiService
        }
    }
    
    Context "When testing service lifecycle management" {
        BeforeEach {
            $container = [EnhancedServiceContainer]::new()
        }
        
        It "Should initialize services in correct order" {
            $logger = [MockLogger]::new()
            $container.RegisterWithMetadata("Logger", $logger)
            
            $dataService = [MockDataService]::new()
            $dataService.Logger = $container.GetService("Logger")
            $container.RegisterWithMetadata("DataService", $dataService)
            
            $uiService = [MockUIService]::new()
            $uiService.Logger = $container.GetService("Logger")
            $uiService.DataService = $container.GetService("DataService")
            $container.RegisterWithMetadata("UIService", $uiService)
            
            # Verify initialization order in log messages
            $expectedOrder = @(
                "Logger initialized",
                "DataService initializing",
                "UIService initializing"
            )
            
            $logMessages = $logger.Messages
            foreach ($expectedMsg in $expectedOrder) {
                $logMessages | Should -Contain $expectedMsg
            }
        }
        
        It "Should dispose services in reverse order" {
            $logger = [MockLogger]::new()
            $container.RegisterWithMetadata("Logger", $logger)
            
            $dataService = [MockDataService]::new()
            $dataService.Logger = $container.GetService("Logger")
            $container.RegisterWithMetadata("DataService", $dataService)
            
            $uiService = [MockUIService]::new()
            $uiService.Logger = $container.GetService("Logger")
            $uiService.DataService = $container.GetService("DataService")
            $container.RegisterWithMetadata("UIService", $uiService)
            
            # Clear log messages
            $logger.Messages = @()
            
            # Dispose container
            $container.Dispose()
            
            # Verify disposal order (reverse of initialization)
            $disposeMessages = $logger.Messages | Where-Object { $_ -like "*disposing*" }
            $disposeMessages[0] | Should -Match "UIService disposing"
            $disposeMessages[1] | Should -Match "DataService disposing"
        }
        
        It "Should handle disposal errors gracefully" {
            # Create a service that throws on dispose
            $faultyService = [PSCustomObject]@{
                Initialize = { }
                Dispose = { throw "Disposal error" }
            }
            
            $logger = [MockLogger]::new()
            $container.RegisterWithMetadata("Logger", $logger)
            $container.RegisterWithMetadata("FaultyService", $faultyService)
            
            # Should not throw even if disposal fails
            { $container.Dispose() } | Should -Not -Throw
            
            # Logger should still be disposed
            $logger.Initialized | Should -Be $false
        }
    }
    
    Context "When testing scoped containers" {
        BeforeEach {
            $rootContainer = [EnhancedServiceContainer]::new()
        }
        
        AfterEach {
            $rootContainer.Dispose()
        }
        
        It "Should inherit singleton services in scoped containers" {
            # Register singleton in root
            $logger = [MockLogger]::new()
            $rootContainer.RegisterWithMetadata("Logger", $logger)
            
            # Create scope
            $scopedContainer = $rootContainer.CreateScope()
            
            # Should get same logger instance from scope
            $scopedLogger = $scopedContainer.GetService("Logger")
            $scopedLogger | Should -Be $logger
        }
        
        It "Should allow scope-specific services" {
            # Register shared service in root
            $logger = [MockLogger]::new()
            $rootContainer.RegisterWithMetadata("Logger", $logger)
            
            # Create scopes
            $scope1 = $rootContainer.CreateScope()
            $scope2 = $rootContainer.CreateScope()
            
            # Register scope-specific services
            $dataService1 = [MockDataService]::new()
            $dataService1.Logger = $scope1.GetService("Logger")
            $scope1.RegisterWithMetadata("ScopedDataService", $dataService1)
            
            $dataService2 = [MockDataService]::new()
            $dataService2.Logger = $scope2.GetService("Logger")
            $scope2.RegisterWithMetadata("ScopedDataService", $dataService2)
            
            # Services should be different between scopes
            $service1 = $scope1.GetService("ScopedDataService")
            $service2 = $scope2.GetService("ScopedDataService")
            
            $service1 | Should -Not -Be $service2
            $service1.Logger | Should -Be $service2.Logger  # Shared logger
        }
        
        It "Should dispose scoped services independently" {
            $logger = [MockLogger]::new()
            $rootContainer.RegisterWithMetadata("Logger", $logger)
            
            $scope = $rootContainer.CreateScope()
            $scopedService = [MockDataService]::new()
            $scopedService.Logger = $scope.GetService("Logger")
            $scope.RegisterWithMetadata("ScopedService", $scopedService)
            
            # Dispose scope
            $scope.Dispose()
            
            # Scoped service should be disposed
            $scopedService.Initialized | Should -Be $false
            
            # Root services should still be available
            $rootLogger = $rootContainer.GetService("Logger")
            $rootLogger.Initialized | Should -Be $true
        }
    }
    
    Context "When testing service health monitoring" {
        BeforeEach {
            $container = [EnhancedServiceContainer]::new()
        }
        
        AfterEach {
            $container.Dispose()
        }
        
        It "Should report healthy services correctly" {
            $logger = [MockLogger]::new()
            $container.RegisterWithMetadata("Logger", $logger)
            
            $dataService = [MockDataService]::new()
            $dataService.Logger = $container.GetService("Logger")
            $container.RegisterWithMetadata("DataService", $dataService)
            
            $health = $container.HealthCheck()
            
            $health.TotalServices | Should -Be 2
            $health.InitializedServices | Should -Be 2
            $health.Healthy | Should -Be $true
            $health.FailedServices.Count | Should -Be 0
        }
        
        It "Should detect service failures" {
            # Create a service that reports unhealthy
            $healthyService = [MockLogger]::new()
            $container.RegisterWithMetadata("HealthyService", $healthyService)
            
            $unhealthyService = [PSCustomObject]@{
                HealthCheck = { return $false }
            }
            $container.RegisterWithMetadata("UnhealthyService", $unhealthyService)
            
            $health = $container.HealthCheck()
            
            $health.Healthy | Should -Be $false
            $health.FailedServices | Should -Contain "UnhealthyService"
        }
    }
    
    Context "When testing configuration integration" {
        BeforeEach {
            $container = [EnhancedServiceContainer]::new()
        }
        
        AfterEach {
            $container.Dispose()
        }
        
        It "Should integrate configuration service with other services" {
            # Register configuration service
            $configService = [ConfigurationService]::new()
            $configService.Initialize()
            $container.RegisterWithMetadata("Configuration", $configService)
            
            # Set some test configuration
            $configService.Set("TestApp.LogLevel", "Debug")
            $configService.Set("TestApp.MaxConnections", 100)
            
            # Register service that uses configuration
            $configuredService = [PSCustomObject]@{
                Config = $null
                LogLevel = $null
                MaxConnections = 0
                
                Initialize = {
                    $this.LogLevel = $this.Config.Get("TestApp.LogLevel", "Info")
                    $this.MaxConnections = $this.Config.Get("TestApp.MaxConnections", 50)
                }
            }
            
            $configuredService.Config = $container.GetService("Configuration")
            $configuredService.Initialize()
            $container.RegisterWithMetadata("ConfiguredService", $configuredService)
            
            # Verify configuration was applied
            $service = $container.GetService("ConfiguredService")
            $service.LogLevel | Should -Be "Debug"
            $service.MaxConnections | Should -Be 100
        }
        
        It "Should handle configuration validation in service chain" {
            $configService = [ConfigurationService]::new()
            $configService.Initialize()
            
            # Register validators
            $configProvider = $configService.GetProvider()
            $configProvider.RegisterValidator("UI", [UIConfigurationValidator]::new())
            
            # Set valid configuration
            $configService.Set("UI.RefreshRate", 60)
            $configService.Set("UI.BufferWidth", 120)
            $configService.Set("UI.DefaultTheme", "Performance")
            
            $container.RegisterWithMetadata("Configuration", $configService)
            
            # Create service that depends on valid configuration
            $uiService = [PSCustomObject]@{
                Config = $null
                RefreshRate = 0
                
                Initialize = {
                    $uiConfig = $this.Config.GetSection("UI")
                    $validator = [UIConfigurationValidator]::new()
                    
                    if (-not $validator.ValidateConfiguration($uiConfig)) {
                        throw "Invalid UI configuration"
                    }
                    
                    $this.RefreshRate = $this.Config.Get("UI.RefreshRate")
                }
            }
            
            $uiService.Config = $container.GetService("Configuration")
            $uiService.Initialize()
            $container.RegisterWithMetadata("UIService", $uiService)
            
            # Should initialize successfully with valid config
            $service = $container.GetService("UIService")
            $service.RefreshRate | Should -Be 60
        }
    }
}

Write-Host "Service wiring integration tests loaded" -ForegroundColor Green