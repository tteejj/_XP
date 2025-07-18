# ==============================================================================
# Axiom-Phoenix v4.0 - Configuration System
# Centralized application settings with validation and environment support
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.IO

#region Configuration Interfaces

# IConfiguration interface
# Configuration access interface
#   GetValue(key) -> object
#   GetValue(key, defaultValue) -> object  
#   SetValue(key, value) -> void
#   HasKey(key) -> bool
#   GetSection(sectionName) -> hashtable

# IConfigurationValidator interface  
# Configuration validation interface
#   ValidateConfiguration(config) -> bool
#   GetValidationErrors(config) -> string[]

#endregion

#region Configuration Provider

class ConfigurationProvider {
    hidden [hashtable] $_config = @{}
    hidden [hashtable] $_validators = @{}
    hidden [string] $_configPath = ""
    hidden [bool] $_autoSave = $false
    
    ConfigurationProvider() {
        $this.LoadDefaults()
    }
    
    ConfigurationProvider([string]$configPath) {
        $this._configPath = $configPath
        $this.LoadDefaults()
        $this.LoadFromFile($configPath)
    }
    
    # Load default configuration
    [void] LoadDefaults() {
        $this._config = @{
            Application = @{
                Name = "Axiom-Phoenix"
                Version = "4.0"
                Environment = "Development"
                LogLevel = "Info"
                DebugMode = $false
            }
            UI = @{
                DefaultTheme = "Performance"
                RefreshRate = 60
                BufferWidth = 120
                BufferHeight = 30
                EnableAnimations = $true
                CursorBlinkRate = 500
            }
            Performance = @{
                EnableOptimizedRendering = $true
                MaxBufferPoolSize = 1000
                AnsiCacheSize = 500
                StringInterningEnabled = $true
                GCCollectionThreshold = 10000
            }
            Input = @{
                KeyRepeatDelay = 250
                KeyRepeatRate = 30
                MouseEnabled = $true
                TouchEnabled = $false
            }
            Storage = @{
                DataPath = "./data"
                BackupPath = "./backups"
                MaxBackups = 10
                AutoBackup = $true
                BackupInterval = 3600
            }
            Logging = @{
                LogPath = "./logs"
                MaxLogFiles = 7
                LogRotationSize = "10MB"
                EnableConsoleLogging = $true
                EnableFileLogging = $true
            }
            Security = @{
                EnableEncryption = $false
                SessionTimeout = 3600
                MaxFailedAttempts = 3
                LockoutDuration = 300
            }
        }
    }
    
    # Configuration access methods
    [object] GetValue([string]$key) {
        return $this.GetValue($key, $null)
    }
    
    [object] GetValue([string]$key, [object]$defaultValue) {
        $keys = $key.Split('.')
        $current = $this._config
        
        foreach ($k in $keys) {
            if ($current -is [hashtable] -and $current.ContainsKey($k)) {
                $current = $current[$k]
            } else {
                return $defaultValue
            }
        }
        
        return $current
    }
    
    [void] SetValue([string]$key, [object]$value) {
        $keys = $key.Split('.')
        $current = $this._config
        
        # Navigate to parent container
        for ($i = 0; $i -lt $keys.Length - 1; $i++) {
            $k = $keys[$i]
            if (-not $current.ContainsKey($k)) {
                $current[$k] = @{}
            }
            $current = $current[$k]
        }
        
        # Set the final value
        $current[$keys[-1]] = $value
        
        # Validate if validator exists
        $this.ValidateSection($keys[0])
        
        # Auto-save if enabled
        if ($this._autoSave -and $this._configPath) {
            $this.SaveToFile($this._configPath)
        }
    }
    
    [bool] HasKey([string]$key) {
        return $null -ne $this.GetValue($key)
    }
    
    [hashtable] GetSection([string]$sectionName) {
        if ($this._config.ContainsKey($sectionName)) {
            return $this._config[$sectionName]
        }
        return @{}
    }
    
    # File operations
    [void] LoadFromFile([string]$filePath) {
        if (Test-Path $filePath) {
            try {
                $content = Get-Content $filePath -Raw | ConvertFrom-Json -AsHashtable
                $this.MergeConfiguration($content)
                Write-Log -Level Info -Message "Configuration loaded from: $filePath"
            } catch {
                Write-Log -Level Error -Message "Failed to load configuration from $filePath : $($_.Exception.Message)"
                throw
            }
        }
    }
    
    [void] SaveToFile([string]$filePath) {
        try {
            $configJson = $this._config | ConvertTo-Json -Depth 10
            $configJson | Out-File -FilePath $filePath -Encoding UTF8
            Write-Log -Level Info -Message "Configuration saved to: $filePath"
        } catch {
            Write-Log -Level Error -Message "Failed to save configuration to $filePath : $($_.Exception.Message)"
            throw
        }
    }
    
    # Configuration merging
    [void] MergeConfiguration([hashtable]$newConfig) {
        foreach ($key in $newConfig.Keys) {
            if ($this._config.ContainsKey($key) -and $this._config[$key] -is [hashtable] -and $newConfig[$key] -is [hashtable]) {
                $this.MergeSection($this._config[$key], $newConfig[$key])
            } else {
                $this._config[$key] = $newConfig[$key]
            }
        }
    }
    
    hidden [void] MergeSection([hashtable]$existing, [hashtable]$new) {
        foreach ($key in $new.Keys) {
            if ($existing.ContainsKey($key) -and $existing[$key] -is [hashtable] -and $new[$key] -is [hashtable]) {
                $this.MergeSection($existing[$key], $new[$key])
            } else {
                $existing[$key] = $new[$key]
            }
        }
    }
    
    # Environment-specific configuration
    [void] LoadEnvironmentConfiguration() {
        $env = $this.GetValue("Application.Environment", "Development")
        $envConfigPath = "./config/config.$($env.ToLower()).json"
        
        if (Test-Path $envConfigPath) {
            $this.LoadFromFile($envConfigPath)
        }
        
        # Load environment variables
        $this.LoadEnvironmentVariables()
    }
    
    [void] LoadEnvironmentVariables() {
        # Load environment variables with AXIOM_ prefix
        foreach ($var in Get-ChildItem env:AXIOM_*) {
            $key = $var.Name -replace '^AXIOM_', '' -replace '_', '.'
            $this.SetValue($key, $var.Value)
        }
    }
    
    # Validation
    [void] RegisterValidator([string]$section, [object]$validator) {
        $this._validators[$section] = $validator
    }
    
    [void] ValidateSection([string]$section) {
        if ($this._validators.ContainsKey($section)) {
            $validator = $this._validators[$section]
            $sectionConfig = $this.GetSection($section)
            
            if (-not $validator.ValidateConfiguration($sectionConfig)) {
                $errors = $validator.GetValidationErrors($sectionConfig)
                throw "Configuration validation failed for section '$section': $($errors -join ', ')"
            }
        }
    }
    
    [bool] ValidateAll() {
        foreach ($section in $this._validators.Keys) {
            try {
                $this.ValidateSection($section)
            } catch {
                Write-Log -Level Error -Message "Validation failed for section '$section': $($_.Exception.Message)"
                return $false
            }
        }
        return $true
    }
    
    # Auto-save configuration
    [void] EnableAutoSave([bool]$enabled) {
        $this._autoSave = $enabled
    }
    
    # Configuration reporting
    [hashtable] GetConfigurationReport() {
        return @{
            ConfigPath = $this._configPath
            AutoSave = $this._autoSave
            Sections = $this._config.Keys
            Validators = $this._validators.Keys
            Environment = $this.GetValue("Application.Environment")
            LoadedAt = [DateTime]::Now
        }
    }
}

#endregion

#region Configuration Validators

class UIConfigurationValidator {
    [bool] ValidateConfiguration([hashtable]$config) {
        $errors = $this.GetValidationErrors($config)
        return $errors.Count -eq 0
    }
    
    [string[]] GetValidationErrors([hashtable]$config) {
        $errors = @()
        
        # Validate refresh rate
        if ($config.ContainsKey('RefreshRate')) {
            $rate = $config.RefreshRate
            if ($rate -lt 1 -or $rate -gt 120) {
                $errors += "RefreshRate must be between 1 and 120"
            }
        }
        
        # Validate buffer dimensions
        if ($config.ContainsKey('BufferWidth')) {
            $width = $config.BufferWidth
            if ($width -lt 40 -or $width -gt 300) {
                $errors += "BufferWidth must be between 40 and 300"
            }
        }
        
        if ($config.ContainsKey('BufferHeight')) {
            $height = $config.BufferHeight
            if ($height -lt 10 -or $height -gt 100) {
                $errors += "BufferHeight must be between 10 and 100"
            }
        }
        
        # Validate theme
        if ($config.ContainsKey('DefaultTheme')) {
            $validThemes = @('Performance', 'Synthwave', 'Classic', 'Dark', 'Light')
            if ($config.DefaultTheme -notin $validThemes) {
                $errors += "DefaultTheme must be one of: $($validThemes -join ', ')"
            }
        }
        
        return $errors
    }
}

class PerformanceConfigurationValidator {
    [bool] ValidateConfiguration([hashtable]$config) {
        $errors = $this.GetValidationErrors($config)
        return $errors.Count -eq 0
    }
    
    [string[]] GetValidationErrors([hashtable]$config) {
        $errors = @()
        
        # Validate buffer pool size
        if ($config.ContainsKey('MaxBufferPoolSize')) {
            $size = $config.MaxBufferPoolSize
            if ($size -lt 100 -or $size -gt 10000) {
                $errors += "MaxBufferPoolSize must be between 100 and 10000"
            }
        }
        
        # Validate cache sizes
        if ($config.ContainsKey('AnsiCacheSize')) {
            $size = $config.AnsiCacheSize
            if ($size -lt 50 -or $size -gt 5000) {
                $errors += "AnsiCacheSize must be between 50 and 5000"
            }
        }
        
        # Validate GC threshold
        if ($config.ContainsKey('GCCollectionThreshold')) {
            $threshold = $config.GCCollectionThreshold
            if ($threshold -lt 1000 -or $threshold -gt 100000) {
                $errors += "GCCollectionThreshold must be between 1000 and 100000"
            }
        }
        
        return $errors
    }
}

#endregion

#region Configuration Service

class ConfigurationService {
    hidden [ConfigurationProvider] $_provider
    hidden [string] $_configDirectory = "./config"
    hidden [string] $_configFile = "config.json"
    
    ConfigurationService() {
        # Initialize with default configuration
    }
    
    [void] Initialize() {
        # Ensure config directory exists
        if (-not (Test-Path $this._configDirectory)) {
            New-Item -ItemType Directory -Path $this._configDirectory -Force | Out-Null
        }
        
        $configPath = Join-Path $this._configDirectory $this._configFile
        $this._provider = [ConfigurationProvider]::new($configPath)
        
        # Register validators
        $this._provider.RegisterValidator("UI", [UIConfigurationValidator]::new())
        $this._provider.RegisterValidator("Performance", [PerformanceConfigurationValidator]::new())
        
        # Load environment-specific configuration
        $this._provider.LoadEnvironmentConfiguration()
        
        # Validate configuration
        if (-not $this._provider.ValidateAll()) {
            Write-Log -Level Warning -Message "Configuration validation failed - using defaults where invalid"
        }
        
        Write-Log -Level Info -Message "Configuration service initialized"
    }
    
    [ConfigurationProvider] GetProvider() {
        return $this._provider
    }
    
    # Convenience methods
    [object] Get([string]$key) {
        return $this._provider.GetValue($key)
    }
    
    [object] Get([string]$key, [object]$defaultValue) {
        return $this._provider.GetValue($key, $defaultValue)
    }
    
    [void] Set([string]$key, [object]$value) {
        $this._provider.SetValue($key, $value)
    }
    
    [hashtable] GetSection([string]$section) {
        return $this._provider.GetSection($section)
    }
    
    [void] SaveConfiguration() {
        $configPath = Join-Path $this._configDirectory $this._configFile
        $this._provider.SaveToFile($configPath)
    }
    
    [void] Dispose() {
        if ($this._provider) {
            $this.SaveConfiguration()
        }
    }
}

#endregion

#region Configuration Helpers

# Create global configuration instance
function Initialize-Configuration {
    param(
        [string]$ConfigDirectory = "./config",
        [string]$Environment = "Development"
    )
    
    $configService = [ConfigurationService]::new()
    $configService._configDirectory = $ConfigDirectory
    $configService.Initialize()
    
    # Set environment
    $configService.Set("Application.Environment", $Environment)
    
    return $configService
}

# Get configuration value with dotted notation
function Get-ConfigValue {
    param(
        [string]$Key,
        [object]$DefaultValue = $null
    )
    
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.Configuration) {
        return $global:TuiState.Services.Configuration.Get($Key, $DefaultValue)
    }
    
    return $DefaultValue
}

# Set configuration value
function Set-ConfigValue {
    param(
        [string]$Key,
        [object]$Value
    )
    
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.Configuration) {
        $global:TuiState.Services.Configuration.Set($Key, $Value)
    }
}

#endregion

Write-Host "Configuration System loaded" -ForegroundColor Green