# Axiom-Phoenix v4.0 Mono Framework - Table of Contents

This document provides a comprehensive, metadata-rich index of the framework. It is designed to be easily parsed by both developers and Large Language Models (LLMs) to understand class relationships and dependencies.

## Key Service & Data Flow Relationships

*   **Engine & Rendering:** `Start-TuiEngine` (ART.002) is the main loop. It uses `Invoke-TuiRender` (ART.003), which gets the `CurrentScreen` from `NavigationService` (ASE.004) to render content into the main `CompositorBuffer`. `Render-DifferentialBuffer` (ART.003) compares compositor states to minimize console writes.
*   **Input & Focus:** `Process-TuiInput` (ART.004) receives key presses. It prioritizes overlays (managed by `DialogManager`, ASE.009), then the focused component (managed by `FocusManager`, ASE.009), then global keybindings (`KeybindingService`, ASE.002), and finally the `CurrentScreen`.
*   **Navigation & Actions:** `KeybindingService` (ASE.002) maps keys to action names. `ActionService` (ASE.001) executes the logic for these actions. Navigation actions (e.g., `navigation.taskList`) typically use the `NavigationService` (ASE.004) to change the `CurrentScreen`.
*   **Data Persistence:** UI components (like `TaskListScreen`, ASC.002) use `DataManager` (ASE.003) to load and save `PmcTask` (AMO.003) and `PmcProject` (AMO.004) models.
*   **Styling:** All components use `Get-ThemeColor` (AFU.004) which pulls values from `ThemeManager` (ASE.005). Rendered `TuiCell` (ABC.002) objects use `TuiAnsiHelper` (ABC.001) to generate final ANSI codes.

---

## AllBaseClasses.ps1 (ABC) - Foundation

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| ABC.001 | TuiAnsiHelper Class | **Purpose:** Static class for generating ANSI escape codes from hex colors and attributes. |
| ABC.002 | TuiCell Class | **Purpose:** Represents a single character cell with full styling (FG/BG hex, attributes, Z-Index). The core unit of rendering. |
| ABC.003 | TuiBuffer Class | **Purpose:** A 2D array of `TuiCell` objects. Provides drawing primitives like `WriteString` and `BlendBuffer`. |
| ABC.004 | UIElement Class | **Inherits:** N/A. **Purpose:** The abstract base for all visual components. Manages position, size, children, visibility, and the core rendering lifecycle (`OnRender`, `HandleInput`). |
| ABC.005 | Component Class | **Inherits:** UIElement (ABC.004). **Purpose:** A generic, empty container component. |
| ABC.006 | Screen Class | **Inherits:** UIElement (ABC.004). **Purpose:** Top-level container for a view. Integrates with the service container and has lifecycle methods (`OnEnter`, `OnExit`). Managed by `NavigationService`. |
| ABC.001a | ServiceContainer Class | **Purpose:** A dependency injection (DI) container for registering and resolving application services. |

---

## AllModels.ps1 (AMO) - Data Structures

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| AMO.001 | Enums | **Purpose:** Defines application-specific enumerations like `TaskStatus` and `TaskPriority`. |
| AMO.002 | ValidationBase Class | **Purpose:** Provides static validation methods (e.g., `ValidateNotEmpty`) for use in other model classes. |
| AMO.003 | PmcTask, PmcProject, TimeEntry | **Purpose:** Core data models for the application. They are plain objects with no UI dependencies. Managed by `DataManager`. |
| AMO.004 | Exception Classes | **Purpose:** Custom, framework-specific exception types for more granular error handling. |
| AMO.005 | NavigationItem Class | **Purpose:** A model representing a single item within a `NavigationMenu`. |

---

## AllComponents.ps1 (ACO) - UI Library

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| ACO.001-010 | Core & Advanced Components | **Inherit:** UIElement (ABC.004). **Purpose:** A library of reusable UI controls (Label, Button, TextBox, Table, etc.). They handle their own rendering and input logic. |
| ACO.011 | Panel Class | **Inherits:** UIElement (ABC.004). **Purpose:** A container with borders, a title, and basic layout management for its children. |
| ACO.012 | ScrollablePanel Class | **Inherits:** Panel (ACO.011). **Purpose:** A panel that provides vertical scrolling for content that exceeds its visible height. |
| ACO.013-022 | Composite & Dialog Components | **Inherit:** UIElement or other components. **Purpose:** More complex, specialized components built by combining simpler ones (e.g., `CommandPalette`, `Dialogs`, `ListBox`, `DataGridComponent`). |

---

## AllScreens.ps1 (ASC) - Application Views

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| ASC.001-003 | Screen Implementations | **Inherit:** Screen (ABC.006). **Purpose:** Concrete application views like `DashboardScreen` and `TaskListScreen`. They compose various UI components to build a user interface. |

---

## AllFunctions.ps1 (AFU) - Global Utilities

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| AFU.001-010 | Utility Functions | **Purpose:** Global, stateless helper functions. `Write-TuiBox` draws borders, `Get-ThemeColor` accesses themes, `Write-Log` centralizes logging. |

---

## AllServices.ps1 (ASE) - Business Logic & Managers

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| ASE.001-011 | Service Classes | **Purpose:** Long-lived objects that manage a core aspect of the application (e.g., `NavigationService`, `FocusManager`, `DataManager`, `ViewDefinitionService`). They are registered with the `ServiceContainer`. |

---

## AllRuntime.ps1 (ART) - The Engine

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| ART.001 | Global State | **Purpose:** Initializes the `$global:TuiState` hashtable, the central state store for the running application. |
| ART.002 | Engine Management | **Purpose:** `Initialize-TuiEngine` and `Start-TuiEngine` functions that set up the console and run the main application loop. |
| ART.003 | Rendering System | **Purpose:** `Invoke-TuiRender` and `Render-DifferentialBuffer` handle the frame-by-frame drawing process. |
| ART.004 | Input Processing | **Purpose:** `Process-TuiInput` contains the main input handling logic, routing key presses to the correct components. |
| ART.005 | Overlay Management | **Purpose:** Deprecated functions for showing overlays. Logic now resides in `DialogManager`. |
| ART.006 | Error Handling & Startup | **Purpose:** Contains the `Invoke-PanicHandler` for unrecoverable errors and the `Start-AxiomPhoenix` entry point function. |