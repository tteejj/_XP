# Axiom-Phoenix v4.0 - Completion Roadmap
## Detailed Implementation Plan for Remaining Optimizations

*Generated: 2025-07-16*  
*Current Progress: 85% Complete*

## Quick Reference: What's Left

### Phase 4: Event-Driven Architecture (HIGHEST PRIORITY)
- **Time Estimate**: 12 hours
- **Impact**: High - Automatic screen updates, decoupled architecture
- **Status**: 60% complete, infrastructure ready

### Phase 5: Performance Optimizations (MEDIUM PRIORITY)
- **Time Estimate**: 7 hours
- **Impact**: Medium - 20-30% performance improvement
- **Status**: 75% ready, straightforward implementation

### Phase 6: Advanced Rendering (OPTIONAL)
- **Time Estimate**: 16-24 hours
- **Impact**: High - 50-100% rendering performance improvement
- **Status**: Design complete, ready for implementation

---

## Phase 4: Complete Event-Driven Architecture

### Task 4.1: Complete DataManager Event Publishing (4 hours)

**Current State**: Events partially published, needs completion

**Files to Modify**:
- `Services/ASE.005_DataManager.ps1`

**Implementation**:
```powershell
# Add missing event publications
class DataManager {
    [PmcTask] AddTask([PmcTask]$task) {
        # Existing logic...
        if ($this.EventManager) {
            $this.EventManager.Publish("Tasks.Changed", @{
                Action = "Created"
                Task = $task
                TaskId = $task.Id
            })
        }
    }
    
    [bool] DeleteTask([string]$taskId) {
        # Existing logic...
        if ($this.EventManager) {
            $this.EventManager.Publish("Tasks.Changed", @{
                Action = "Deleted"
                TaskId = $taskId
            })
        }
    }
    
    # Similar for Projects and TimeEntries
}
```

**Validation**: Check that all CRUD operations publish appropriate events

### Task 4.2: Update TaskListScreen for Events (2 hours)

**Current State**: Screen manually refreshes, needs automatic updates

**Files to Modify**:
- `Screens/ASC.002_TaskListScreen.ps1`

**Implementation**:
```powershell
class TaskListScreen : Screen {
    hidden [string]$_taskChangeSubscriptionId = $null
    
    [void] OnEnter() {
        # Subscribe to task changes
        $eventManager = $this.ServiceContainer.GetService("EventManager")
        if ($eventManager) {
            $screenRef = $this
            $taskHandler = {
                param($eventData)
                $screenRef.RefreshTaskList()
            }.GetNewClosure()
            
            $this._taskChangeSubscriptionId = $eventManager.Subscribe("Tasks.Changed", $taskHandler)
        }
        
        ([Screen]$this).OnEnter()
    }
    
    [void] OnExit() {
        if ($this._taskChangeSubscriptionId) {
            $eventManager = $this.ServiceContainer.GetService("EventManager")
            $eventManager.Unsubscribe("Tasks.Changed", $this._taskChangeSubscriptionId)
        }
        ([Screen]$this).OnExit()
    }
}
```

### Task 4.3: Update ProjectsListScreen for Events (2 hours)

**Current State**: Screen manually refreshes, needs automatic updates

**Files to Modify**:
- `Screens/ASC.008_ProjectsListScreen.ps1`

**Implementation**: Similar to TaskListScreen but for "Projects.Changed" events

### Task 4.4: Complete ViewDefinition Integration (4 hours)

**Current State**: ViewDefinitionService exists, DataGridComponent supports it, but screens need updating

**Files to Modify**:
- `Screens/ASC.002_TaskListScreen.ps1`
- `Screens/ASC.008_ProjectsListScreen.ps1`

**Implementation**:
```powershell
# Replace ListBox with DataGridComponent + ViewDefinition
class TaskListScreen : Screen {
    hidden [DataGridComponent]$_taskGrid
    
    [void] Initialize() {
        # Create DataGridComponent instead of ListBox
        $this._taskGrid = [DataGridComponent]::new("TaskGrid")
        $this._taskGrid.ShowHeaders = $true
        
        # Get ViewDefinition from service
        $viewService = $this.ServiceContainer.GetService("ViewDefinitionService")
        $taskViewDef = $viewService.GetViewDefinition('task.summary')
        $this._taskGrid.SetViewDefinition($taskViewDef)
        
        # Add to panel
        $this._listPanel.AddChild($this._taskGrid)
    }
    
    [void] RefreshTaskList() {
        # Pass raw task objects - ViewDefinition handles formatting
        $this._taskGrid.SetItems($this._filteredTasks)
    }
}
```

---

## Phase 5: Performance Optimizations

### Task 5.1: Panel Layout Calculation Caching (3 hours)

**Current State**: Panel layout recalculated every render

**Files to Modify**:
- `Components/ACO.011_Panel.ps1`

**Implementation**:
```powershell
class Panel : UIElement {
    # Layout caching properties
    hidden [bool]$_layoutCacheValid = $false
    hidden [hashtable]$_layoutCache = @{}
    hidden [int]$_lastLayoutChildCount = 0
    
    [void] ApplyLayout() {
        if ($this.LayoutType -eq "Manual") { return }
        
        # Check if cache is valid
        $visibleChildren = @($this.Children.Where({ $_.Visible }))
        if ($this._layoutCacheValid -and $this._lastLayoutChildCount -eq $visibleChildren.Count) {
            # Use cached positions
            foreach ($childId in $this._layoutCache.Keys) {
                $child = $this.GetChild($childId)
                if ($child) {
                    $cachedPos = $this._layoutCache[$childId]
                    $child.Move($cachedPos.X, $cachedPos.Y)
                    $child.Resize($cachedPos.Width, $cachedPos.Height)
                }
            }
            return
        }
        
        # Calculate new layout and cache results
        $this._layoutCache = @{}
        
        # Existing layout logic with caching
        switch ($this.LayoutType) {
            "Vertical" {
                $currentY = $this.ContentY
                foreach ($child in $visibleChildren) {
                    $child.Move($this.ContentX, $currentY)
                    $child.Resize($this.ContentWidth, $child.Height)
                    
                    # Cache position
                    $this._layoutCache[$child.Name] = @{
                        X = $this.ContentX
                        Y = $currentY
                        Width = $this.ContentWidth
                        Height = $child.Height
                    }
                    
                    $currentY += $child.Height + $this.Spacing
                }
            }
            # Similar for Horizontal and Grid layouts
        }
        
        # Mark cache as valid
        $this._layoutCacheValid = $true
        $this._lastLayoutChildCount = $visibleChildren.Count
    }
    
    [void] InvalidateLayoutCache() {
        $this._layoutCacheValid = $false
    }
    
    [void] AddChild([UIElement]$child) {
        ([UIElement]$this).AddChild($child)
        $this.InvalidateLayoutCache()
    }
    
    [void] RemoveChild([UIElement]$child) {
        ([UIElement]$this).RemoveChild($child)
        $this.InvalidateLayoutCache()
    }
}
```

### Task 5.2: Theme Color Caching (2 hours)

**Current State**: Theme colors queried repeatedly in render loops

**Files to Modify**:
- `Base/ABC.004_UIElement.ps1`

**Implementation**:
```powershell
class UIElement {
    hidden [hashtable]$_themeColorCache = @{}
    hidden [string]$_lastThemeName = ""
    
    [string] GetThemeColor([string]$key, [string]$default) {
        $currentTheme = $global:TuiState.CurrentTheme
        
        # Invalidate cache if theme changed
        if ($this._lastThemeName -ne $currentTheme) {
            $this._themeColorCache = @{}
            $this._lastThemeName = $currentTheme
        }
        
        # Check cache
        if ($this._themeColorCache.ContainsKey($key)) {
            return $this._themeColorCache[$key]
        }
        
        # Get color and cache it
        $color = Get-ThemeColor $key $default
        $this._themeColorCache[$key] = $color
        return $color
    }
}
```

### Task 5.3: String Formatting Cache (2 hours)

**Current State**: Already implemented in DataGridComponent, needs extension

**Files to Modify**:
- `Components/ACO.010_Table.ps1`
- `Components/ACO.014_ListBox.ps1`

**Implementation**:
```powershell
class Table : UIElement {
    hidden [string[]]$_displayStringCache = @()
    hidden [bool]$_cacheValid = $false
    
    [void] SetItems([object[]]$items) {
        $this.Items = $items
        $this._cacheValid = $false  # Invalidate cache
    }
    
    hidden [void] _EnsureDisplayCache() {
        if ($this._cacheValid) { return }
        
        $this._displayStringCache = @()
        foreach ($item in $this.Items) {
            # Pre-format display string
            $displayString = $this._FormatItem($item)
            $this._displayStringCache += $displayString
        }
        
        $this._cacheValid = $true
    }
    
    [void] OnRender() {
        $this._EnsureDisplayCache()
        
        # Use cached display strings instead of formatting on every render
        for ($i = 0; $i -lt $this._displayStringCache.Count; $i++) {
            $displayString = $this._displayStringCache[$i]
            # Render cached string
        }
    }
}
```

---

## Phase 6: Advanced Rendering (OPTIONAL)

### Option A: Z-Index Layer Rendering (16 hours)

**Current State**: Single buffer with Z-index sorting

**Files to Modify**:
- `Runtime/ART.003_RenderingSystem.ps1`
- `Base/ABC.004_UIElement.ps1`

**Implementation**:
```powershell
# Initialize layer system
function Initialize-LayerSystem {
    $global:TuiState.CompositorLayers = @{
        0 = [TuiBuffer]::new($global:TuiState.ScreenWidth, $global:TuiState.ScreenHeight)  # Background
        1 = [TuiBuffer]::new($global:TuiState.ScreenWidth, $global:TuiState.ScreenHeight)  # Content
        2 = [TuiBuffer]::new($global:TuiState.ScreenWidth, $global:TuiState.ScreenHeight)  # Overlay
    }
}

# Modified rendering pipeline
function Invoke-TuiRender {
    # Clear all layers
    foreach ($layer in $global:TuiState.CompositorLayers.Values) {
        $layer.Clear()
    }
    
    # Render components to appropriate layers
    $navService = $global:TuiState.Services.NavigationService
    $windows = $navService.GetWindows()
    
    foreach ($window in $windows) {
        $window.RenderToLayer($global:TuiState.CompositorLayers)
    }
    
    # Composite layers
    $global:TuiState.CompositorBuffer.Clear()
    foreach ($layerIndex in $global:TuiState.CompositorLayers.Keys | Sort-Object) {
        $layer = $global:TuiState.CompositorLayers[$layerIndex]
        $global:TuiState.CompositorBuffer.BlendBuffer($layer, 0, 0)
    }
    
    # Differential rendering
    Render-DifferentialBuffer
}

# Enhanced UIElement
class UIElement {
    [void] RenderToLayer([hashtable]$layers) {
        $targetLayer = $layers[$this.ZIndex]
        if ($targetLayer) {
            # Render to specific layer buffer
            $this.RenderToBuffer($targetLayer)
        }
    }
}
```

### Option B: Direct-to-ANSI Rendering (24 hours)

**Current State**: Buffer-based rendering with cell comparison

**Files to Modify**:
- `Runtime/ART.003_RenderingSystem.ps1`
- `Base/ABC.004_UIElement.ps1`
- Multiple component files

**Implementation**:
```powershell
# Enhanced UIElement with ANSI caching
class UIElement {
    hidden [string]$_cachedAnsiString = ""
    hidden [bool]$_ansiCacheValid = $false
    
    [string] GetAnsiString() {
        if (!$this._ansiCacheValid) {
            $this._cachedAnsiString = $this._GenerateAnsiString()
            $this._ansiCacheValid = true
        }
        return $this._cachedAnsiString
    }
    
    hidden [string] _GenerateAnsiString() {
        # Generate ANSI sequence for this component
        $ansi = "`e[$($this.Y + 1);$($this.X + 1)H"  # Position cursor
        $ansi += $this._GetComponentAnsiContent()
        return $ansi
    }
    
    [void] RequestRedraw() {
        $this._ansiCacheValid = $false
        $this._needsRedraw = $true
    }
}

# Modified rendering pipeline
function Invoke-TuiRender {
    $ansiBuilder = [System.Text.StringBuilder]::new(32768)
    
    # Clear screen
    $ansiBuilder.Append("`e[2J`e[H")
    
    # Collect ANSI strings from all components
    $navService = $global:TuiState.Services.NavigationService
    $windows = $navService.GetWindows()
    
    foreach ($window in $windows) {
        $ansiStrings = $window.GetAnsiStrings()
        foreach ($ansiString in $ansiStrings) {
            $ansiBuilder.Append($ansiString)
        }
    }
    
    # Single console write
    [Console]::Write($ansiBuilder.ToString())
}
```

---

## Implementation Priority Matrix

### High Priority (Complete First)
1. **Task 4.1**: Complete DataManager event publishing
2. **Task 4.2**: Update TaskListScreen for events
3. **Task 4.3**: Update ProjectsListScreen for events
4. **Task 4.4**: Complete ViewDefinition integration

### Medium Priority (Performance Gains)
5. **Task 5.1**: Panel layout calculation caching
6. **Task 5.2**: Theme color caching
7. **Task 5.3**: String formatting cache

### Low Priority (Optional Performance)
8. **Task 6.A**: Z-Index layer rendering (easier)
9. **Task 6.B**: Direct-to-ANSI rendering (maximum performance)

---

## Validation & Testing Plan

### Phase 4 Validation
- [ ] All CRUD operations publish events
- [ ] All screens automatically refresh on data changes
- [ ] No manual refresh calls needed
- [ ] Event subscriptions properly cleaned up

### Phase 5 Validation
- [ ] Layout calculations cached and reused
- [ ] Theme colors cached and reused
- [ ] String formatting cached and reused
- [ ] Performance improvement measurable

### Phase 6 Validation
- [ ] Advanced rendering system functional
- [ ] No visual regressions
- [ ] Significant performance improvement
- [ ] Memory usage within acceptable limits

---

## Expected Timeline

### Aggressive Schedule (Full-time focus)
- **Phase 4**: 1.5 days
- **Phase 5**: 1 day
- **Phase 6**: 2-3 days
- **Total**: 4.5-5.5 days

### Moderate Schedule (Part-time focus)
- **Phase 4**: 1 week
- **Phase 5**: 3 days
- **Phase 6**: 1 week
- **Total**: 2-2.5 weeks

### Conservative Schedule (Occasional work)
- **Phase 4**: 2 weeks
- **Phase 5**: 1 week
- **Phase 6**: 2 weeks
- **Total**: 5 weeks

---

## Success Metrics

### Phase 4 Success
- ✅ Zero manual refresh calls in application code
- ✅ All screens automatically update on data changes
- ✅ Event system handles all data synchronization
- ✅ Decoupled architecture achieved

### Phase 5 Success
- ✅ 20-30% performance improvement measured
- ✅ Reduced memory usage
- ✅ Smoother user experience
- ✅ No performance regressions

### Phase 6 Success
- ✅ 50-100% rendering performance improvement
- ✅ Support for more complex visual effects
- ✅ Best-in-class TUI performance
- ✅ Scalable to large, complex applications

---

## Conclusion

The roadmap provides a clear path to completing the Axiom-Phoenix framework optimization work. The framework is already production-ready, and these optimizations will elevate it to best-in-class performance and architecture.

**Recommendation**: Focus on Phase 4 first for maximum architectural benefit, then Phase 5 for performance, and Phase 6 only if maximum performance is required for specific use cases.