# action-service Module

## Overview
The `action-service` module provides a central registry for managing and executing all application-wide actions or commands. It is a core service in the PMC Terminal application, enabling a decoupled architecture where components can invoke standardized actions without direct dependencies on the components that implement them.

## Features
- **Centralized Action Registry** - A single source of truth for all application commands.
- **Robust Validation** - Strict parameter validation for all public methods to ensure data integrity.
- **Safe Registration** - Prevents accidental overwriting of existing actions by default, requiring an explicit `-Force` switch.
- **Standardized Execution** - Consistent and reliable parameter passing to action script blocks.
- **Comprehensive Logging** - Detailed verbose and informational logging for easy debugging and tracing.
- **Lifecycle Management** - Includes a `Cleanup` method to clear the registry and manage resources.

## Core Class & Function

### ActionService (Class)
The main service class that manages the action registry.

#### Key Properties
- **ActionRegistry** - A hashtable storing all registered actions by name.
- **EventSubscriptions** - A private hashtable for tracking internal event subscriptions for automatic cleanup.

#### Core Methods
```powershell
# Register a new action or overwrite an existing one
$actionService.RegisterAction($name, $description, $scriptBlock, $category, $Force)

# Remove an action from the registry
$actionService.UnregisterAction($name)

# Execute an action by name, with optional parameters
$actionService.ExecuteAction($name, $parametersHashtable)

# Retrieve a single action's definition
$action = $actionService.GetAction($name)

# Retrieve all registered actions
$allActions = $actionService.GetAllActions()

# Clean up the service and clear the registry
$actionService.Cleanup()
```

### Initialize-ActionService (Function)
A factory function to create a new instance of the `ActionService`.

```powershell
# Create a new, initialized Action Service instance
$actionService = Initialize-ActionService
```

## Usage Examples

### Initializing the Service
In your application's startup script, create an instance of the service. This is typically done once and the instance is passed to other components via dependency injection.

```powershell
# Assumes this module is imported
$Global:ActionService = Initialize-ActionService
```

### Registering an Action
Components or modules can register their actions with the central service.

```powershell
# Define the action's logic in a script block
$saveActionLogic = {
    param($ActionParameters)

    Write-Log -Level Info -Message "Saving file: $($ActionParameters.FilePath)"
    # ... logic to save the file ...
    Show-Notification -Message "File saved successfully!"
}

# Register the action
$Global:ActionService.RegisterAction(
    -name "file.save",
    -description "Saves the currently active file",
    -scriptBlock $saveActionLogic,
    -category "File"
)

# Registering an action that already exists will fail unless -Force is used
$Global:ActionService.RegisterAction(
    -name "file.save",
    -description "Saves the file with a new implementation",
    -scriptBlock $newSaveLogic,
    -category "File",
    -Force
)
```

### Executing an Action
Any component can execute an action by its name, passing required parameters.

```powershell
# A UI component (e.g., a button's OnClick handler) executes the action
$button.OnClick = {
    $currentFilePath = Get-ActiveDocumentPath
    
    $params = @{
        FilePath = $currentFilePath
        Timestamp = (Get-Date)
    }

    # Execute the action by its registered name
    $Global:ActionService.ExecuteAction("file.save", $params)
}
```

### Writing Action Script Blocks
The `ExecuteAction` method passes all parameters within a single hashtable to a named parameter `$ActionParameters` inside the script block. This creates a predictable and consistent contract.

```powershell
# Correct way to define an action's script block
$myAction = {
    param(
        # This parameter name is standardized by ActionService
        [hashtable]$ActionParameters
    )

    $user = $ActionParameters.User
    $id = $ActionParameters.Id

    Write-Host "Processing action for user '$user' with ID '$id'."
}

# Register and execute
$ActionService.RegisterAction("user.process", "Processes a user action", $myAction)
$ActionService.ExecuteAction("user.process", @{ User = 'jdoe'; Id = 123 })
```

## Best Practices

1.  **Consistent Naming:** Use a `.`-separated convention for action names (e.g., `component.verb` like `file.open`, `task.create`).
2.  **Stateless Actions:** Keep action script blocks as stateless as possible. Pass all required context via the `$ActionParameters` hashtable.
3.  **Use Events for Side Effects:** Instead of directly manipulating UI, have actions publish events (e.g., `Publish-Event -EventName 'Data.Refreshed'`). UI components should subscribe to these events and update themselves accordingly. This maintains loose coupling.
4.  **Centralized Registration:** Register actions during application or module initialization to ensure they are available when needed.
5.  **Judicious Use of `-Force`:** Only use the `-Force` switch on `RegisterAction` when you are intentionally overriding a default or existing action. The default safe behavior prevents bugs.