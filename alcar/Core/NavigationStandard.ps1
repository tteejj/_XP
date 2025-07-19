# Navigation Standard - Consistent arrow key behavior across alcar

enum NavigationMode {
    SinglePane     # Single list/content area
    MultiPane      # Multiple panes with Tab switching
    FormEditing    # Form with editable fields
    TextEditing    # Text editor mode
}

class NavigationStandard {
    static [hashtable] GetStandardBindings([NavigationMode]$mode, [Screen]$screen) {
        $bindings = @{}
        
        switch ($mode) {
            ([NavigationMode]::SinglePane) {
                # Single pane navigation (lists, menus)
                $bindings[[ConsoleKey]::UpArrow] = { $screen.MoveUp() }
                $bindings[[ConsoleKey]::DownArrow] = { $screen.MoveDown() }
                $bindings[[ConsoleKey]::LeftArrow] = { $screen.GoBack() }  # Exit/Back
                $bindings[[ConsoleKey]::RightArrow] = { $screen.SelectItem() }  # Enter/Select
                $bindings[[ConsoleKey]::Enter] = { $screen.SelectItem() }
                $bindings[[ConsoleKey]::Escape] = { $screen.GoBack() }
                $bindings[[ConsoleKey]::Backspace] = { $screen.GoBack() }
            }
            
            ([NavigationMode]::MultiPane) {
                # Multi-pane navigation (use Tab for pane switching)
                $bindings[[ConsoleKey]::UpArrow] = { $screen.MoveUp() }
                $bindings[[ConsoleKey]::DownArrow] = { $screen.MoveDown() }
                $bindings[[ConsoleKey]::Tab] = { $screen.NextPane() }
                $bindings[[ConsoleKey]::Enter] = { $screen.SelectItem() }
                $bindings[[ConsoleKey]::Escape] = { $screen.GoBack() }
                
                # Left/Right behavior depends on context
                $bindings[[ConsoleKey]::LeftArrow] = { 
                    if ($screen.CanMoveToPreviousPane()) {
                        $screen.PreviousPane()
                    } else {
                        $screen.GoBack()
                    }
                }
                $bindings[[ConsoleKey]::RightArrow] = { 
                    if ($screen.CanMoveToNextPane()) {
                        $screen.NextPane()
                    } else {
                        $screen.SelectItem()
                    }
                }
            }
            
            ([NavigationMode]::FormEditing) {
                # Form editing (settings, dialogs)
                $bindings[[ConsoleKey]::UpArrow] = { $screen.PreviousField() }
                $bindings[[ConsoleKey]::DownArrow] = { $screen.NextField() }
                $bindings[[ConsoleKey]::Tab] = { $screen.NextField() }
                $bindings[[ConsoleKey]::Enter] = { $screen.EditField() }
                $bindings[[ConsoleKey]::Spacebar] = { $screen.ToggleField() }
                $bindings[[ConsoleKey]::Escape] = { $screen.Cancel() }
                
                # Left/Right for value changes
                $bindings[[ConsoleKey]::LeftArrow] = { $screen.DecrementValue() }
                $bindings[[ConsoleKey]::RightArrow] = { $screen.IncrementValue() }
            }
            
            ([NavigationMode]::TextEditing) {
                # Text editing mode
                $bindings[[ConsoleKey]::UpArrow] = { $screen.MoveCursorUp() }
                $bindings[[ConsoleKey]::DownArrow] = { $screen.MoveCursorDown() }
                $bindings[[ConsoleKey]::LeftArrow] = { $screen.MoveCursorLeft() }
                $bindings[[ConsoleKey]::RightArrow] = { $screen.MoveCursorRight() }
                $bindings[[ConsoleKey]::Home] = { $screen.MoveCursorHome() }
                $bindings[[ConsoleKey]::End] = { $screen.MoveCursorEnd() }
                $bindings[[ConsoleKey]::Escape] = { $screen.ExitEditMode() }
            }
        }
        
        # Common bindings for all modes
        $bindings[[ConsoleKey]::PageUp] = { $screen.PageUp() }
        $bindings[[ConsoleKey]::PageDown] = { $screen.PageDown() }
        $bindings[[ConsoleKey]::Home] = { $screen.GoToTop() }
        $bindings[[ConsoleKey]::End] = { $screen.GoToBottom() }
        
        return $bindings
    }
    
    # Helper to apply standard navigation to a screen
    static [void] ApplyTo([Screen]$screen, [NavigationMode]$mode) {
        $bindings = [NavigationStandard]::GetStandardBindings($mode, $screen)
        
        foreach ($key in $bindings.Keys) {
            $screen.KeyBindings[$key] = $bindings[$key]
        }
    }
}

# Base class extensions for standard navigation methods
class NavigationScreen : Screen {
    [NavigationMode]$NavigationMode = [NavigationMode]::SinglePane
    [int]$CurrentPane = 0
    [int]$PaneCount = 1
    
    NavigationScreen() {
        # Apply standard navigation on construction
        [NavigationStandard]::ApplyTo($this, $this.NavigationMode)
    }
    
    # Default implementations (override as needed)
    [void] MoveUp() {
        # Override in derived classes
    }
    
    [void] MoveDown() {
        # Override in derived classes
    }
    
    [void] SelectItem() {
        # Override in derived classes
    }
    
    [void] GoBack() {
        $this.Active = $false
    }
    
    [void] NextPane() {
        if ($this.PaneCount -gt 1) {
            $this.CurrentPane = ($this.CurrentPane + 1) % $this.PaneCount
            $this.RequestRender()
        }
    }
    
    [void] PreviousPane() {
        if ($this.PaneCount -gt 1) {
            $this.CurrentPane = ($this.CurrentPane - 1)
            if ($this.CurrentPane -lt 0) {
                $this.CurrentPane = $this.PaneCount - 1
            }
            $this.RequestRender()
        }
    }
    
    [bool] CanMoveToNextPane() {
        return $this.PaneCount -gt 1 -and $this.CurrentPane -lt ($this.PaneCount - 1)
    }
    
    [bool] CanMoveToPreviousPane() {
        return $this.PaneCount -gt 1 -and $this.CurrentPane -gt 0
    }
    
    [void] PageUp() {
        # Override in derived classes
    }
    
    [void] PageDown() {
        # Override in derived classes
    }
    
    [void] GoToTop() {
        # Override in derived classes
    }
    
    [void] GoToBottom() {
        # Override in derived classes
    }
}

# Form navigation extensions
class FormScreen : NavigationScreen {
    [int]$CurrentField = 0
    [int]$FieldCount = 0
    
    FormScreen() {
        $this.NavigationMode = [NavigationMode]::FormEditing
        [NavigationStandard]::ApplyTo($this, $this.NavigationMode)
    }
    
    [void] NextField() {
        if ($this.CurrentField -lt $this.FieldCount - 1) {
            $this.CurrentField++
            $this.RequestRender()
        }
    }
    
    [void] PreviousField() {
        if ($this.CurrentField -gt 0) {
            $this.CurrentField--
            $this.RequestRender()
        }
    }
    
    [void] EditField() {
        # Override to implement field editing
    }
    
    [void] ToggleField() {
        # Override to implement toggle behavior
    }
    
    [void] IncrementValue() {
        # Override to implement value increment
    }
    
    [void] DecrementValue() {
        # Override to implement value decrement
    }
    
    [void] Cancel() {
        $this.GoBack()
    }
}