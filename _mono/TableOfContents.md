# Axiom-Phoenix v4.0 Mono Framework - Table of Contents

This document provides a comprehensive index of all sections in the mono framework files. Each section has a unique page ID that can be searched to quickly locate content.

## Search Instructions

To find a specific section, search for the page marker in the format:
- **Beginning**: `<!-- PAGE: [ID] - [SECTION_NAME] -->`
- **End**: `<!-- END_PAGE: [ID] -->`

Example: Search for `PAGE: ABC.001` to find the TuiAnsiHelper class.

## File Structure Overview

| File | Prefix | Description |
|------|--------|-------------|
| AllBaseClasses.ps1 | ABC | Foundation classes with no external dependencies |
| AllModels.ps1 | AMO | Data models, enums, and validation classes |
| AllComponents.ps1 | ACO | UI components extending UIElement |
| AllScreens.ps1 | ASC | Application screens and views |
| AllFunctions.ps1 | AFU | Standalone utility functions |
| AllServices.ps1 | ASE | Business services and managers |
| AllRuntime.ps1 | ART | Engine, runtime, and main loop |
| Start.ps1 | STA | Application entry point |

---

## AllBaseClasses.ps1 (ABC)

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| ABC.001 | TuiAnsiHelper Class | ANSI escape code generation with truecolor support |
| ABC.002 | TuiCell Class | Single character cell with styling information |
| ABC.003 | TuiBuffer Class | 2D array of TuiCells for rendering |
| ABC.004 | UIElement Class | Base class for all UI components |
| ABC.005 | Component Class | Generic container component |
| ABC.006 | Screen Class | Top-level container for application views |
| ABC.007 | ServiceContainer Class | Dependency injection container |

---

## AllModels.ps1 (AMO)

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| AMO.001 | Enums | TaskStatus, TaskPriority, BillingType enumerations |
| AMO.002 | ValidationBase Class | Base validation methods |
| AMO.003 | PmcTask Class | Core task entity with lifecycle methods |
| AMO.004 | PmcProject Class | Project container entity |
| AMO.005 | TimeEntry Class | Time tracking entity for billable work |

---

## AllComponents.ps1 (ACO)

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| ACO.001 | LabelComponent Class | Static text display component |
| ACO.002 | ButtonComponent Class | Interactive button with click events |
| ACO.003 | TextBoxComponent Class | Advanced text input with scrolling |
| ACO.004 | CheckBoxComponent Class | Boolean checkbox input |
| ACO.005 | RadioButtonComponent Class | Exclusive selection within groups |
| ACO.006 | MultilineTextBoxComponent Class | Full text editor with scrolling |
| ACO.007 | NumericInputComponent Class | Numeric input with spinners and validation |
| ACO.008 | DateInputComponent Class | Date picker with calendar interface |
| ACO.009 | ComboBoxComponent Class | Dropdown with search and overlay rendering |
| ACO.010 | Table Class | High-performance data grid with virtual scrolling |
| ACO.011 | Panel Class | Container with layout management |
| ACO.012 | ScrollablePanel Class | Panel with scrolling capabilities |
| ACO.013 | GroupPanel Class | Themed panel for grouping |
| ACO.014 | ListBox Class | Scrollable item list with selection |
| ACO.015 | TextBox Class | Enhanced wrapper around TextBoxComponent |
| ACO.016 | CommandPalette Class | Searchable command interface |
| ACO.017 | Dialog Class | Base dialog class |
| ACO.018 | AlertDialog Class | Simple alert dialog |
| ACO.019 | ConfirmDialog Class | Yes/No confirmation dialog |
| ACO.020 | InputDialog Class | Text input dialog |
| ACO.021 | NavigationMenu Class | Local menu component |

---

## AllScreens.ps1 (ASC)

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| ASC.001 | DashboardScreen Class | Main application dashboard |
| ASC.002 | TaskListScreen Class | Task management interface |
| ASC.003 | Screen Utilities | Helper functions for screens |

---

## AllFunctions.ps1 (AFU)

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| AFU.001 | TUI Drawing Functions | Write-TuiText, Write-TuiBox |
| AFU.002 | Border Functions | Get-TuiBorderChars |
| AFU.003 | Factory Functions | Component creation functions |
| AFU.004 | Theme Functions | Get-ThemeColor utilities |
| AFU.005 | Focus Management | Focus handling functions |
| AFU.006 | Logging Functions | Write-Log utilities |
| AFU.007 | Event Functions | Event subscription/publishing |
| AFU.008 | Error Handling | Error management utilities |
| AFU.009 | Input Processing | Input handling functions |
| AFU.010 | Utility Functions | Miscellaneous helper functions |

---

## AllServices.ps1 (ASE)

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| ASE.001 | ActionService Class | Central command registry |
| ASE.002 | KeybindingService Class | Global keyboard management |
| ASE.003 | DataManager Class | Data persistence and management |
| ASE.004 | NavigationService Class | Screen navigation management |
| ASE.005 | ThemeManager Class | Visual theming system |
| ASE.006 | Logger Class | Application logging |
| ASE.007 | EventManager Class | Pub/sub event system |
| ASE.008 | TuiFrameworkService Class | Framework service management |
| ASE.009 | Additional Service Classes | FocusManager and DialogManager |

---

## AllRuntime.ps1 (ART)

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| ART.001 | Global State | TuiState hashtable initialization |
| ART.002 | Engine Management | Initialize/Start/Stop TUI engine |
| ART.003 | Rendering System | Frame rendering and differential updates |
| ART.004 | Input Processing | Keyboard input handling |
| ART.005 | Screen Management | Screen stack operations |
| ART.006 | Error Handling | Panic handler and crash management |

---

## Start.ps1 (STA)

| Page ID | Section Name | Description |
|---------|--------------|-------------|
| STA.001 | File Loading | Module/file loading in dependency order |
| STA.002 | Service Initialization | ServiceContainer setup and registration |
| STA.003 | Application Startup | Main application entry point |

---

## Maintenance Instructions

When modifying any of the framework files:

1. **Adding new classes/functions**: Add appropriate page markers around new sections
2. **Removing sections**: Remove corresponding page markers and update this table
3. **Reorganizing code**: Ensure page markers remain accurate and update this table
4. **Major refactoring**: Review and update the entire table of contents

### Page Marker Format

```html
<!-- PAGE: [PREFIX].[3-DIGIT-NUMBER] - [SECTION_NAME] -->
[Section content here]
<!-- END_PAGE: [PREFIX].[3-DIGIT-NUMBER] -->
```

### Update Process

1. Modify the relevant framework file(s)
2. Update page markers as needed
3. Update this TableOfContents.md file to reflect changes
4. Ensure page IDs remain unique and sequential

---

*Last Updated: December 2024*
*Framework Version: Axiom-Phoenix v4.0 Mono*

## Current Implementation Status

✅ **Completed Files with Page Markers:**
- AllBaseClasses.ps1 (ABC.001-ABC.007) - **COMPLETE**
- AllModels.ps1 (AMO.001-AMO.005) - **COMPLETE**
- AllComponents.ps1 (ACO.001-ACO.021) - **COMPLETE**
- AllScreens.ps1 (ASC.001-ASC.003) - **COMPLETE**
- AllFunctions.ps1 (AFU.001-AFU.010) - **COMPLETE**
- AllServices.ps1 (ASE.001-ASE.009) - **COMPLETE**
- AllRuntime.ps1 (ART.001-ART.006) - **COMPLETE**
- Start.ps1 (STA.001-STA.003) - **COMPLETE**

📋 **All Files Complete:**
- **8 of 8 framework files** have complete page marker implementation
- **Total sections indexed: 64** across all files
