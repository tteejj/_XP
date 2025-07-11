# Text Editor Features Summary

The Axiom-Phoenix Text Editor is a **full-featured multiline text editor** with the following capabilities:

## Navigation
- **Arrow Keys**: Move cursor up, down, left, right
- **Ctrl+Arrow**: Move by word
- **Home/End**: Move to line start/end
- **Ctrl+Home/End**: Move to document start/end
- **Page Up/Page Down**: Scroll by page

## Editing
- **Type**: Insert text at cursor position
- **Backspace**: Delete character before cursor
- **Delete**: Delete character at cursor
- **Enter**: Insert new line with auto-indentation
- **Tab**: Insert spaces (4 spaces by default)

## Selection & Clipboard
- **Shift+Navigation**: Select text
- **Ctrl+A**: Select all
- **Ctrl+C**: Copy selection
- **Ctrl+X**: Cut selection
- **Ctrl+V**: Paste

## Search & Replace
- **Ctrl+F**: Find
- **Ctrl+H**: Find and Replace
- **F3**: Find next
- **Shift+F3**: Find previous
- **Enter**: Next match (in search mode)
- **Esc**: Exit search mode

## Undo/Redo
- **Ctrl+Z**: Undo
- **Ctrl+Y**: Redo

## File Operations
- **Ctrl+S**: Save (placeholder - no filesystem access in demo)
- **Ctrl+Q**: Exit editor
- **Escape**: Exit editor

## Technical Features
- Gap buffer implementation for efficient insertions
- Line indexing for fast navigation
- Viewport-based rendering (only renders visible lines)
- Differential rendering for performance
- Syntax-aware auto-indentation
- Incremental search with highlighting
- Unlimited undo/redo

## Demo Content
The editor loads with sample text demonstrating its features. You can freely edit, navigate, and experiment with all the features listed above.

The editor is optimized for performance and can handle large documents efficiently thanks to its gap buffer architecture and viewport rendering system.
