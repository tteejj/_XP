# What Happened and How to Fix It

## The Problem
A script was run that tried to fix color property assignments by converting direct property access to setter methods. However, the script had bugs and corrupted many files by:

1. Leaving incomplete lines with just property names like "BackgroundColor"
2. Leaving incomplete variable references like "$selectedTheme"  
3. Creating malformed method definitions
4. Breaking variable scoping

## The Solution
Use an LLM to fix each file individually by:

1. Reading `LLM_FIX_INSTRUCTIONS.md` - This contains EXPLICIT patterns and fixes
2. Reading `FILES_TO_FIX.md` - This lists all files that need fixing, in order
3. Feeding each file to the LLM one at a time
4. Saving the LLM's complete output as the fixed file

## Quick Test
After fixing just the first file (`Screens\ASC.003_ThemeScreen.ps1`), try running:
```powershell
.\Start.ps1
```

If it starts, you can continue fixing the other files while the app is running.

## Why This Approach
- Scripts can't handle the complex context-dependent fixes needed
- An LLM can understand the code's intent and fix it properly
- The instructions are explicit enough that any competent LLM should fix the files correctly
