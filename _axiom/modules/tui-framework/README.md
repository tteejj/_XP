Of course. Here is the new `README.md` for the `tui-framework` module, reflecting its new service-oriented architecture and modern asynchronous capabilities.

# tui-framework Module

## Overview
The `tui-framework` module provides a set of essential helper utilities designed to bridge the gap between UI components and the core TUI engine. It is delivered as a single, injectable service, `TuiFrameworkService`, that offers lightweight asynchronous task management and state-checking capabilities, aligning with the modern, class-based Axiom-Phoenix architecture.

## Features
- **Service-Oriented Design**: All framework utilities are encapsulated within the `TuiFrameworkService` class, designed to be registered with and retrieved from a dependency injection container.
- **Lightweight Asynchronous Tasks**: Utilizes the `ThreadJob` module (`Start-ThreadJob`) for high-performance, in-process asynchronous operations, ideal for non-blocking I/O tasks like network requests or file access.
- **Centralized & Thread-Safe Job Management**: Tracks all started async jobs in a thread-safe collection, allowing for robust management and cleanup.
- **Modern, Class-Based Interaction**: Replaces obsolete helper functions with direct, service-based method calls, promoting a cleaner and more maintainable codebase.

## Core Components

### TuiFrameworkService (Class)
This is the central service that provides all framework utilities. An instance of this class is created by `Initialize-TuiFrameworkService` and should be managed by your service container.

#### Key Methods
```powershell
# Start a lightweight, non-blocking asynchronous job
$job = $tuiFrameworkService.StartAsync($scriptBlock, $argumentListHashtable)

# Check for and retrieve results from completed jobs
$results = $tuiFrameworkService.GetAsyncResults()

# Stop all currently tracked async jobs (used during application shutdown)
$tuiFrameworkService.StopAllAsyncJobs()

# Get the global TUI state object for debugging
$state = $tuiFrameworkService.GetState()

# Check if the TUI engine is currently running
$isRunning = $tuiFrameworkService.IsRunning()
```

### Initialize-TuiFrameworkService (Function)
A factory function that creates a new instance of the `TuiFrameworkService`. This is the only function exported by the module.
```powershell
# In your service container setup:
$container.RegisterFactory("TuiFramework", { Initialize-TuiFrameworkService })
```

## Integration & Usage Example

The `TuiFrameworkService` is designed to be injected into other components, such as screens, that require its functionality.

**1. Register the Service (in `run.ps1` or startup script)**
```powershell
# Assumes $container is your service container instance
$container.RegisterFactory("TuiFramework", { param($c) Initialize-TuiFrameworkService })
```

**2. Use the Service in a Component**
A screen can receive the service from the container and use it to perform background tasks.
```powershell
class DataScreen : Screen {
    [TuiFrameworkService]$TuiFramework
    [Label]$StatusLabel

    DataScreen([object]$serviceContainer) : base("DataScreen", $serviceContainer) {}

    [void] Initialize() {
        # Get the framework service from the container
        $this.TuiFramework = $this.ServiceContainer.GetService("TuiFramework")

        $this.StatusLabel = [Label]::new("Status", "Press F5 to fetch data...")
        $this.AddChild($this.StatusLabel)
    }

    [void] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq 'F5') {
            $this.FetchDataAsync()
        }
    }

    [void] FetchDataAsync() {
        $this.StatusLabel.SetText("Fetching data from API...")
        $this.RequestRedraw()

        # Start the async operation without blocking the UI
        $scriptBlock = {
            param($url)
            # This runs in a background thread
            return Invoke-RestMethod -Uri $url
        }
        $this.TuiFramework.StartAsync($scriptBlock, @{ url = "https://api.example.com/data" }) | Out-Null
    }

    [void] OnUpdate() {
        # This method would be called each frame by the TUI engine
        # Check for results from any completed async jobs
        $results = $this.TuiFramework.GetAsyncResults()
        foreach ($result in $results) {
            if ($result.State -eq 'Completed') {
                $this.StatusLabel.SetText("Data received! Found $($result.Output.Count) items.")
                $this.RequestRedraw()
            } elseif ($result.State -eq 'Failed') {
                $this.StatusLabel.SetText("Error: Failed to fetch data.")
                $this.RequestRedraw()
            }
        }
    }
}
```

## Removed Functions (Migration Guide)

This version of the framework represents a significant architectural shift. The following functions from previous versions have been removed and replaced.

### `Invoke-TuiMethod` (Removed)
This function is obsolete in a class-based architecture.

-   **Old Way:** `Invoke-TuiMethod -Component $myComponent -MethodName "MyMethod"`
-   **New Way:** `$myComponent.MyMethod()`

Directly calling methods on class objects is cleaner, more performant, and provides superior static analysis and IntelliSense support.

### Standalone Async & State Functions (Replaced)
Functions like `Invoke-TuiAsync`, `Get-TuiAsyncResults`, `Stop-AllTuiAsyncJobs`, `Get-TuiState`, and `Test-TuiState` are no longer exported as standalone functions. Their logic has been improved and encapsulated as methods within the `TuiFrameworkService` class to promote a more organized, service-based architecture.

## Dependencies
This module requires the `ThreadJob` module for its asynchronous features.
```powershell
# To install the dependency:
Install-Module -Name ThreadJob -Scope CurrentUser
```