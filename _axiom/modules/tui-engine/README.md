# TUI Engine Module

## Overview

The TUI Engine module is the core orchestrator of the PMC Terminal TUI application. It manages the main application loop, screen rendering, input processing, and component lifecycle. This module provides the foundation for all TUI operations and ensures smooth, efficient rendering with proper resource management.

## Features

- **Lifecycle Management**: Complete component lifecycle with Initialize, Cleanup, and Resize hooks
- **High-Performance Rendering**: Compositor-based rendering with differential updates
- **Input Processing**: Asynchronous input handling with concurrent queuing
- **Screen Management**: Stack-based screen navigation with proper state management
- **Overlay Support**: Modal dialog and popup support with overlay management
- **Resize Handling**: Automatic terminal resize detection and propagation
- **Error Recovery**: Comprehensive error handling with panic recovery
- **Resource Management**: Automatic cleanup of all resources on shutdown
- **Focus Management**: Global focus management with keyboard navigation

## Core Components

### TUI State Management

The engine maintains a global TUI state that includes:

- **Running State**: Application lifecycle state
- **Buffers**: Compositor buffers for efficient rendering
- **Screen Stack**: Navigation stack for screen management
- **Overlay Stack**: Modal overlays and dialogs
- **Input Queue**: Asynchronous input processing queue
- **Focus State**: Current focused component tracking

### Rendering System

The rendering system uses a compositor-based approach:

- **Differential Updates**: Only changed cells are updated
- **Buffer Management**: Double-buffered rendering for smooth updates
- **Clipping**: Automatic clipping to prevent drawing outside bounds
- **Layering**: Proper layering of screens and overlays

### Input Processing

Advanced input handling features:

- **Asynchronous Processing**: Non-blocking input with concurrent queues
- **Event Routing**: Proper routing of input events to focused components
- **Cancellation Support**: Graceful cancellation of input operations
- **Thread Safety**: Safe concurrent access to input state

## Usage Examples

### Basic Engine Initialization

```powershell
# Initialize the TUI engine
Initialize-TuiEngine -Width 120 -Height 40

# Create and show initial screen
$mainScreen = [MainScreen]::new()
Start-TuiLoop -InitialScreen $mainScreen
```

### Screen Management

```powershell
# Push a new screen onto the stack
Push-Screen -Screen $newScreen

# Pop the current screen
$popped = Pop-Screen

# Show a modal overlay
Show-TuiOverlay -Element $dialog
```

### Cleanup and Shutdown

```powershell
# Cleanup is automatic on application exit
# Manual cleanup if needed
Cleanup-TuiEngine
```

## Dependencies

- `tui-primitives`: For core TUI rendering functions
- `panic-handler`: For error recovery and panic handling
- `logger`: For comprehensive logging and debugging
- `event-system`: For event publishing and subscription

## Architecture

The TUI Engine follows a layered architecture:

### Core Layer
- **TUI State**: Global state management
- **Buffer Management**: Rendering buffer operations
- **Input Threading**: Asynchronous input processing

### Rendering Layer
- **Compositor**: High-performance rendering engine
- **Screen Management**: Screen stack and navigation
- **Overlay System**: Modal dialog and popup support

### Event Layer
- **Lifecycle Events**: Component initialization and cleanup
- **Input Events**: Keyboard and system event processing
- **Resize Events**: Terminal resize detection and handling

## Performance Optimization

The engine includes several performance optimizations:

### Rendering Optimizations
- **Differential Updates**: Only changed cells are redrawn
- **Viewport Culling**: Off-screen content is not processed
- **Buffer Reuse**: Efficient buffer memory management
- **Batch Operations**: Multiple updates batched together

### Input Optimizations
- **Async Processing**: Non-blocking input handling
- **Event Batching**: Multiple input events processed together
- **Priority Handling**: Focus-aware event routing

### Memory Management
- **Resource Cleanup**: Automatic cleanup of all resources
- **Buffer Pooling**: Efficient buffer memory reuse
- **Garbage Collection**: Minimized GC pressure

## Lifecycle Management

The engine manages the complete component lifecycle:

### Initialize Phase
- **Screen Initialization**: OnInitialize() called on screen creation
- **Component Setup**: Child components initialized recursively
- **Event Subscription**: Event handlers registered
- **Resource Allocation**: Memory and resources allocated

### Active Phase
- **Rendering**: OnRender() called for visual updates
- **Input Handling**: HandleInput() called for user interaction
- **Event Processing**: Published events handled
- **State Updates**: Component state synchronized

### Cleanup Phase
- **Event Unsubscription**: All event handlers removed
- **Resource Release**: Memory and resources freed
- **Component Disposal**: Child components cleaned up recursively
- **State Cleanup**: All state properly reset

## Error Handling

Comprehensive error handling throughout the engine:

### Panic Recovery
- **Graceful Degradation**: Application continues on non-fatal errors
- **Error Logging**: All errors logged with context
- **User Notification**: Critical errors shown to user
- **State Recovery**: Automatic state restoration when possible

### Resource Protection
- **Safe Cleanup**: Resources always cleaned up on errors
- **Thread Safety**: Concurrent operations protected
- **State Validation**: State consistency maintained
- **Memory Safety**: No memory leaks or corruption

## Thread Safety

The engine ensures thread safety across all operations:

### Input Processing
- **Concurrent Queues**: Thread-safe input queuing
- **Atomic Operations**: Safe state updates
- **Synchronization**: Proper thread synchronization
- **Cancellation**: Safe operation cancellation

### Rendering
- **Buffer Protection**: Safe buffer access
- **State Consistency**: Consistent rendering state
- **Update Coordination**: Coordinated screen updates

## Configuration

Engine configuration options:

### Display Settings
- **Buffer Size**: Customizable buffer dimensions
- **Frame Rate**: Configurable target frame rate
- **Refresh Mode**: Different refresh strategies

### Input Settings
- **Queue Size**: Input queue capacity
- **Timeout Values**: Input timeout configuration
- **Key Mapping**: Custom key bindings

### Performance Settings
- **Render Optimization**: Various performance modes
- **Memory Limits**: Memory usage constraints
- **Thread Count**: Threading configuration

## Version History

- **v1.0**: Basic rendering and input handling
- **v2.0**: Screen management and navigation
- **v3.0**: Overlay system and modal dialogs
- **v4.0**: Performance optimizations and error handling
- **v5.0**: Complete lifecycle management and resource cleanup
- **v5.3**: Enhanced resize handling and state management
