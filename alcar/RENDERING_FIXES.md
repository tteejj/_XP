# Rendering Fixes for BOLT-AXIOM - Round 2

## Issues Addressed

1. **Screen Flicker**
   - Implemented proper double buffering using StringBuilder
   - Added alternate screen buffer support (`?1049h`/`?1049l`)
   - Removed all redundant `[VT]::Clear()` calls from individual screens
   - Atomic write operations for entire frames
   - Fixed screen transition flicker

2. **Menu Alignment Issues**
   - Fixed box drawing for selected menu items
   - Properly contained description text within selection boxes
   - Adjusted spacing between menu items (4 lines per item)
   - Centered menu items correctly

3. **Performance Optimizations**
   - Pre-allocated StringBuilder buffers (16KB)
   - Removed redundant clear operations from all screens
   - Simplified render loop - render only on input
   - Single write operations per frame
   - Better error handling for Console operations

## Key Changes

### Base/Screen.ps1
- Optimized `Render()` method with larger buffer allocation
- Consolidated ANSI sequences for atomic writes
- Fixed Dialog rendering to prevent parent screen flicker

### Core/ScreenManager.ps1
- Simplified render loop - render only on input changes
- Removed periodic refresh to eliminate flicker
- Added render call in Push() for immediate screen display
- Better error handling for Console operations
- Proper alternate screen buffer management

### Screens/MainMenuScreen.ps1
- Removed `[VT]::Clear()` call 
- Fixed menu item boxes to contain both title and description
- Proper padding and alignment calculations
- Clean box drawing with active borders

### Screens/SettingsScreen.ps1 & DashboardScreen.ps1
- Removed `[VT]::Clear()` calls
- Let base Screen class handle clearing

### Core/layout2.ps1
- Removed redundant clear operation
- Optimized StringBuilder usage

## Testing

Run the test scripts to verify fixes:
```bash
./test-rendering-fix.ps1     # Interactive test
./test-menu-alignment.ps1    # Alignment verification
./bolt.ps1                   # Full application
```

## Results

- No visible flicker during navigation
- Properly aligned menu boxes
- Smooth screen transitions
- Responsive input handling
- Clean visual presentation