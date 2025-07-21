# Flicker Analysis and Resolution Options

## Root Cause Analysis

The flicker wasn't present with just the TaskList screen because:

1. **Single Screen vs Multiple Screens**: The original TaskList was a monolithic app with one screen. Now we have:
   - ScreenManager with screen stack
   - Multiple screen transitions
   - Base Screen class with its own render logic
   - Dialog overlays

2. **Rendering Pipeline Changes**:
   - **Before**: Direct VT100 output, single render path
   - **After**: Screen → ScreenManager → Base.Render() → Content → Console

3. **Multiple Clear Operations**:
   - Base Screen class: `[void]$sb.Append("`e[H`e[2J")`
   - Individual screens: `[VT]::Clear()`
   - Layout: Had its own clear
   - Multiple clears = visible flicker

4. **Alternate Screen Buffer**:
   - Good for isolation but adds overhead
   - Switching between buffers can cause flicker if not managed properly

## Why Flicker Happens

The flicker is happening because:

1. **Every render does a full clear** (line 26 in Screen.ps1): `"`e[H`e[2J"`
2. **Clear → Draw cycle is visible** to the human eye
3. **Multiple renders per action** (Push, Pop, input handling)

## Options to Resolve

### Option 1: **Differential Rendering** (Best for eliminating flicker)
```powershell
# Keep track of what's on screen and only update changed parts
class Screen {
    [string]$LastRenderedContent
    
    [void] Render() {
        $newContent = $this.RenderContent()
        if ($newContent -eq $this.LastRenderedContent) {
            return  # Nothing changed
        }
        # Only update changed regions
    }
}
```

**Pros:**
- Zero flicker
- Most efficient
- Professional approach

**Cons:**
- Complex to implement
- Need to track screen state
- More memory usage

### Option 2: **Remove Clear, Use Overwrite** (Simplest)
```powershell
# Don't clear, just overwrite with spaces where needed
[void] Render() {
    $sb = [System.Text.StringBuilder]::new(16384)
    [void]$sb.Append("`e[?25l`e[H")  # No clear!
    [void]$sb.Append($this.RenderContent())
    [void]$sb.Append($this.RenderStatusBar())
    [Console]::Write($sb.ToString())
}
```

**Pros:**
- Immediate fix
- Simple change
- Works because screens draw full borders

**Cons:**
- Might leave artifacts if screen size changes
- Need to ensure full screen coverage

### Option 3: **Back to Direct Rendering** (Like original)
Remove the base Screen class rendering and let each screen handle its own output directly, like the original TaskList.

**Pros:**
- Proven to work (original had no flicker)
- Maximum control per screen
- Can optimize each screen individually

**Cons:**
- Loses consistency
- More code duplication
- Harder to maintain

### Option 4: **Smart Clear** (Compromise)
```powershell
class Screen {
    [bool]$NeedsClear = $true  # Only clear on first render
    
    [void] Render() {
        $sb = [System.Text.StringBuilder]::new(16384)
        [void]$sb.Append("`e[?25l")
        
        if ($this.NeedsClear) {
            [void]$sb.Append("`e[H`e[2J")
            $this.NeedsClear = $false
        } else {
            [void]$sb.Append("`e[H")  # Just home
        }
        
        [void]$sb.Append($this.RenderContent())
        [void]$sb.Append($this.RenderStatusBar())
        [Console]::Write($sb.ToString())
    }
}
```

**Pros:**
- Reduces flicker significantly
- Still clears when needed
- Easy to implement

**Cons:**
- Screen transitions might show artifacts
- Need to manage NeedsClear flag

### Option 5: **VSync-like Timing**
Only render at fixed intervals (e.g., 60fps) to make updates smoother.

**Pros:**
- Smooth, consistent updates
- Professional feel

**Cons:**
- More complex timing logic
- Still has flicker if clearing

### Option 6: **Page Flipping** (Double Buffer)
Maintain two buffers and flip between them.

**Pros:**
- No flicker at all
- Standard game programming technique

**Cons:**
- Complex for terminal apps
- PowerShell might not be fast enough

## Recommendation

I recommend **Option 2** (Remove Clear, Use Overwrite) because:
- Immediate fix for flicker
- Minimal code changes
- Screens already draw their own borders/backgrounds
- The alternate screen buffer already provides isolation

### Implementation for Option 2:

1. Change Base/Screen.ps1 Render() to remove clear
2. Ensure all screens draw complete backgrounds
3. Test with screen resizing

### Alternative Quick Fix:
If Option 2 has issues, try **Option 4** (Smart Clear) as it's a good compromise.

## The Original Success

The original TaskList worked because:
1. It rendered directly without abstraction layers
2. It only cleared when absolutely necessary
3. It used immediate mode rendering
4. No screen management overhead

We can get back to that performance while keeping the new architecture.