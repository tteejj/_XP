# BOLT-AXIOM ⚡

Ultra-fast terminal productivity suite with wireframe aesthetic and instant response times.

## Features

- **Three-pane layout** - Filter/Task/Detail view with perfect alignment
- **True color support** - 24-bit RGB for beautiful wireframe graphics
- **Ultra-fast rendering** - Single VT100 write operation
- **Keyboard-driven** - Arrow keys, Tab, hotkeys
- **Axiom data structure** - Full task management model preserved

## Running BOLT-AXIOM

From the BoltAxiom directory:
```bash
pwsh -file run.ps1
```

Or from the parent directory:
```bash
pwsh -file bolt-axiom.ps1
```

## Navigation

- **Tab** - Switch between panes
- **←→** - Move between panes
- **↑↓** - Navigate within pane
- **Space** - Toggle task status
- **p** - Change priority
- **q** - Quit

## Architecture

```
BoltAxiom/
├── Core/
│   ├── vt100.ps1      # VT100/ANSI with true color
│   └── layout.ps1     # Three-pane layout engine
├── Models/
│   └── task.ps1       # Axiom-compatible task model
├── Screens/
│   └── taskscreen.ps1 # Task management screen
└── run.ps1            # Main entry point
```

## Visual Design

- Single-line borders for speed
- Strategic color use (cyan borders, white active)
- Perfect column alignment
- Wireframe aesthetic inspired by Wizardry/WarGames

## Status Symbols

- **○** Pending
- **◐** In Progress  
- **●** Completed
- **✗** Cancelled

## Priority Indicators

- **↓** Low
- **→** Medium
- **↑** High

## Next Features

- Inline editing
- Task creation/deletion
- Search functionality
- Data persistence
- Project management
- Timesheet tracking