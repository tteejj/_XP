# ==============================================================================
# Axiom-Phoenix v4.0 - Configuration Validation Tests
# Testing configuration system and validation
# ==============================================================================

# Import the framework
$scriptDir = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $scriptDir "Base/ABC.006_Configuration.ps1")

Describe "Configuration System Tests" {
    Context "When creating configuration provider" {
        It "Should initialize with default values" {
            $config = [ConfigurationProvider]::new()
            
            # Should have default application settings
            $config.GetValue("Application.Name") | Should -Be "Axiom-Phoenix"
            $config.GetValue("Application.Version") | Should -Be "4.0"
            $config.GetValue("UI.DefaultTheme") | Should -Be "Performance"
        }
        
        It "Should load from file when path provided" {
            # Create temporary config file
            $tempFile = [System.IO.Path]::GetTempFileName()
            $testConfig = @{
                Application = @{
                    Name = "Test App"
                    Environment = "Testing"
                }
                UI = @{
                    DefaultTheme = "TestTheme"
                    RefreshRate = 30
                }
            } | ConvertTo-Json -Depth 10
            
            $testConfig | Out-File -FilePath $tempFile -Encoding UTF8
            
            try {
                $config = [ConfigurationProvider]::new($tempFile)
                
                $config.GetValue("Application.Name") | Should -Be "Test App"
                $config.GetValue("Application.Environment") | Should -Be "Testing"
                $config.GetValue("UI.DefaultTheme") | Should -Be "TestTheme"
                $config.GetValue("UI.RefreshRate") | Should -Be 30
            } finally {
                Remove-Item $tempFile -ErrorAction SilentlyContinue
            }
        }
        
        It "Should handle missing config file gracefully" {
            $nonExistentFile = "C:\NonExistent\config.json"
            
            # Should not throw when file doesn't exist
            { $config = [ConfigurationProvider]::new($nonExistentFile) } | Should -Not -Throw
        }
    }
    
    Context "When getting configuration values" {
        BeforeEach {
            $config = [ConfigurationProvider]::new()
        }
        
        It "Should get values with dot notation" {
            $value = $config.GetValue("Application.Name")
            $value | Should -Be "Axiom-Phoenix"
        }
        
        It "Should return default when key not found" {
            $value = $config.GetValue("NonExistent.Key", "DefaultValue")
            $value | Should -Be "DefaultValue"
        }
        
        It "Should return null when key not found and no default" {
            $value = $config.GetValue("NonExistent.Key")
            $value | Should -BeNull
        }
        
        It "Should handle nested keys correctly" {
            $config.SetValue("Level1.Level2.Level3", "DeepValue")
            $value = $config.GetValue("Level1.Level2.Level3")
            $value | Should -Be "DeepValue"
        }
        
        It "Should check if key exists" {
            $config.HasKey("Application.Name") | Should -Be $true
            $config.HasKey("NonExistent.Key") | Should -Be $false
        }
    }
    
    Context "When setting configuration values" {
        BeforeEach {
            $config = [ConfigurationProvider]::new()
        }
        
        It "Should set simple values" {
            $config.SetValue("TestKey", "TestValue")
            $config.GetValue("TestKey") | Should -Be "TestValue"
        }
        
        It "Should set nested values" {
            $config.SetValue("Section.SubSection.Key", "NestedValue")
            $config.GetValue("Section.SubSection.Key") | Should -Be "NestedValue"
        }
        
        It "Should overwrite existing values" {
            $config.SetValue("TestKey", "FirstValue")
            $config.SetValue("TestKey", "SecondValue")
            $config.GetValue("TestKey") | Should -Be "SecondValue"
        }
        
        It "Should handle different data types" {
            $config.SetValue("StringValue", "Text")
            $config.SetValue("NumberValue", 42)
            $config.SetValue("BooleanValue", $true)
            $config.SetValue("ArrayValue", @(1, 2, 3))
            
            $config.GetValue("StringValue") | Should -Be "Text"
            $config.GetValue("NumberValue") | Should -Be 42
            $config.GetValue("BooleanValue") | Should -Be $true
            $config.GetValue("ArrayValue").Count | Should -Be 3
        }
    }
    
    Context "When getting configuration sections" {
        BeforeEach {
            $config = [ConfigurationProvider]::new()
        }
        
        It "Should get entire sections" {
            $uiSection = $config.GetSection("UI")
            
            $uiSection | Should -Not -BeNull
            $uiSection.GetType().Name | Should -Be "Hashtable"
            $uiSection.DefaultTheme | Should -Be "Performance"
        }
        
        It "Should return empty hashtable for non-existent section" {
            $section = $config.GetSection("NonExistent")
            $section | Should -Not -BeNull
            $section.GetType().Name | Should -Be "Hashtable"
            $section.Count | Should -Be 0
        }
    }
    
    Context "When merging configurations" {
        BeforeEach {
            $config = [ConfigurationProvider]::new()
        }
        
        It "Should merge configurations correctly" {
            $newConfig = @{
                Application = @{
                    Environment = "Production"
                    NewProperty = "NewValue"
                }
                NewSection = @{
                    Key1 = "Value1"
                    Key2 = "Value2"
                }
            }
            
            $config.MergeConfiguration($newConfig)
            
            # Should preserve existing values
            $config.GetValue("Application.Name") | Should -Be "Axiom-Phoenix"
            
            # Should add new values
            $config.GetValue("Application.Environment") | Should -Be "Production"
            $config.GetValue("Application.NewProperty") | Should -Be "NewValue"
            $config.GetValue("NewSection.Key1") | Should -Be "Value1"
        }
        
        It "Should override existing values during merge" {
            $config.SetValue("Test.Value", "Original")
            
            $newConfig = @{
                Test = @{
                    Value = "Updated"
                }
            }
            
            $config.MergeConfiguration($newConfig)
            $config.GetValue("Test.Value") | Should -Be "Updated"
        }
    }
    
    Context "When saving and loading configuration files" {
        BeforeEach {
            $config = [ConfigurationProvider]::new()
            $tempFile = [System.IO.Path]::GetTempFileName()
        }
        
        AfterEach {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
        
        It "Should save configuration to file" {
            $config.SetValue("Test.SavedValue", "Saved")
            $config.SaveToFile($tempFile)
            
            Test-Path $tempFile | Should -Be $true
            
            $content = Get-Content $tempFile -Raw | ConvertFrom-Json -AsHashtable
            $content.Test.SavedValue | Should -Be "Saved"
        }
        
        It "Should round-trip configuration through file" {
            $config.SetValue("RoundTrip.Value1", "Test1")
            $config.SetValue("RoundTrip.Value2", 42)
            $config.SetValue("RoundTrip.Value3", $true)
            
            $config.SaveToFile($tempFile)
            
            $newConfig = [ConfigurationProvider]::new($tempFile)
            
            $newConfig.GetValue("RoundTrip.Value1") | Should -Be "Test1"
            $newConfig.GetValue("RoundTrip.Value2") | Should -Be 42
            $newConfig.GetValue("RoundTrip.Value3") | Should -Be $true
        }
    }
}

Describe "Configuration Validation Tests" {
    Context "When validating UI configuration" {
        BeforeEach {
            $validator = [UIConfigurationValidator]::new()
        }
        
        It "Should validate correct UI configuration" {
            $validConfig = @{
                RefreshRate = 60
                BufferWidth = 120
                BufferHeight = 30
                DefaultTheme = "Performance"
                EnableAnimations = $true
            }
            
            $validator.ValidateConfiguration($validConfig) | Should -Be $true
            $errors = $validator.GetValidationErrors($validConfig)
            $errors.Count | Should -Be 0
        }
        
        It "Should detect invalid refresh rate" {
            $invalidConfig = @{
                RefreshRate = 150  # Too high
                BufferWidth = 120
                DefaultTheme = "Performance"
            }
            
            $validator.ValidateConfiguration($invalidConfig) | Should -Be $false
            $errors = $validator.GetValidationErrors($invalidConfig)
            $errors | Should -Contain "RefreshRate must be between 1 and 120"
        }
        
        It "Should detect invalid buffer dimensions" {
            $invalidConfig = @{
                RefreshRate = 60
                BufferWidth = 30  # Too small
                BufferHeight = 5  # Too small
                DefaultTheme = "Performance"
            }
            
            $validator.ValidateConfiguration($invalidConfig) | Should -Be $false
            $errors = $validator.GetValidationErrors($invalidConfig)
            $errors | Should -Contain "BufferWidth must be between 40 and 300"
            $errors | Should -Contain "BufferHeight must be between 10 and 100"
        }
        
        It "Should detect invalid theme" {
            $invalidConfig = @{
                RefreshRate = 60
                BufferWidth = 120
                DefaultTheme = "NonExistentTheme"
            }
            
            $validator.ValidateConfiguration($invalidConfig) | Should -Be $false
            $errors = $validator.GetValidationErrors($invalidConfig)
            $errors | Should -Match "DefaultTheme must be one of.*"
        }
        
        It "Should handle missing optional properties" {
            $minimalConfig = @{
                RefreshRate = 60
                BufferWidth = 80
                BufferHeight = 24
                DefaultTheme = "Performance"
            }
            
            $validator.ValidateConfiguration($minimalConfig) | Should -Be $true
        }
    }
    
    Context "When validating Performance configuration" {
        BeforeEach {
            $validator = [PerformanceConfigurationValidator]::new()
        }
        
        It "Should validate correct performance configuration" {
            $validConfig = @{
                EnableOptimizedRendering = $true
                MaxBufferPoolSize = 1000
                AnsiCacheSize = 500
                StringInterningEnabled = $true
                GCCollectionThreshold = 10000
            }
            
            $validator.ValidateConfiguration($validConfig) | Should -Be $true
            $errors = $validator.GetValidationErrors($validConfig)
            $errors.Count | Should -Be 0
        }
        
        It "Should detect invalid buffer pool size" {
            $invalidConfig = @{
                MaxBufferPoolSize = 50  # Too small
                AnsiCacheSize = 500
            }
            
            $validator.ValidateConfiguration($invalidConfig) | Should -Be $false
            $errors = $validator.GetValidationErrors($invalidConfig)
            $errors | Should -Contain "MaxBufferPoolSize must be between 100 and 10000"
        }
        
        It "Should detect invalid cache sizes" {
            $invalidConfig = @{
                MaxBufferPoolSize = 1000
                AnsiCacheSize = 10  # Too small
                GCCollectionThreshold = 500  # Too small
            }
            
            $validator.ValidateConfiguration($invalidConfig) | Should -Be $false
            $errors = $validator.GetValidationErrors($invalidConfig)
            $errors | Should -Contain "AnsiCacheSize must be between 50 and 5000"
            $errors | Should -Contain "GCCollectionThreshold must be between 1000 and 100000"
        }
    }
}

Describe "Configuration Service Tests" {
    Context "When using configuration service" {
        BeforeEach {
            $service = [ConfigurationService]::new()
        }
        
        It "Should initialize with default configuration" {
            $service.Initialize()
            
            $service.Get("Application.Name") | Should -Be "Axiom-Phoenix"
            $service.Get("UI.DefaultTheme") | Should -Be "Performance"
        }
        
        It "Should provide convenience methods" {
            $service.Initialize()
            
            # Test getter with default
            $value = $service.Get("NonExistent.Key", "DefaultValue")
            $value | Should -Be "DefaultValue"
            
            # Test setter
            $service.Set("Test.Key", "TestValue")
            $service.Get("Test.Key") | Should -Be "TestValue"
            
            # Test section getter
            $uiSection = $service.GetSection("UI")
            $uiSection.DefaultTheme | Should -Be "Performance"
        }
        
        It "Should register and use validators" {
            $service.Initialize()
            
            # Set invalid UI configuration
            $service.Set("UI.RefreshRate", 200)  # Invalid
            
            # Validation should catch this
            $provider = $service.GetProvider()
            $validator = [UIConfigurationValidator]::new()
            $provider.RegisterValidator("UI", $validator)
            
            { $provider.ValidateSection("UI") } | Should -Throw "*RefreshRate*"
        }
        
        It "Should handle disposal correctly" {
            $service.Initialize()
            $service.Set("Test.Value", "ToSave")
            
            # Should save configuration on dispose
            { $service.Dispose() } | Should -Not -Throw
        }
    }
    
    Context "When testing environment-specific configuration" {
        It "Should load environment variables" {
            $service = [ConfigurationService]::new()
            
            # Set test environment variable
            $env:AXIOM_TEST_VALUE = "EnvironmentValue"
            
            try {
                $service.Initialize()
                $provider = $service.GetProvider()
                $provider.LoadEnvironmentVariables()
                
                # Should load environment variable
                $value = $service.Get("TEST.VALUE")
                $value | Should -Be "EnvironmentValue"
            } finally {
                Remove-Item env:AXIOM_TEST_VALUE -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "Configuration Helper Tests" {
    Context "When using configuration helpers" {
        It "Should initialize configuration correctly" {
            $configService = Initialize-Configuration -ConfigDirectory "./test-config" -Environment "Testing"
            
            $configService | Should -Not -BeNull
            $configService.Get("Application.Environment") | Should -Be "Testing"
            
            $configService.Dispose()
        }
        
        It "Should handle global configuration functions" {
            # Mock global TuiState for testing
            $global:TuiState = @{
                Services = @{
                    Configuration = [PSCustomObject]@{
                        Get = { param($key, $default) return "MockValue" }
                        Set = { param($key, $value) }
                    }
                }
            }
            
            try {
                $value = Get-ConfigValue "Test.Key" "Default"
                $value | Should -Be "MockValue"
                
                # Should not throw
                { Set-ConfigValue "Test.Key" "NewValue" } | Should -Not -Throw
            } finally {
                Remove-Variable -Name TuiState -Scope Global -ErrorAction SilentlyContinue
            }
        }
    }
}

Write-Host "Configuration validation tests loaded" -ForegroundColor Green