@{
    Name = "Performance"
    Description = "Speed-optimized theme with minimal color variations for maximum rendering performance"
    
    # PERFORMANCE: Use minimal color palette with pre-computed values
    # These colors are chosen for:
    # 1. Minimal string processing overhead
    # 2. High contrast for readability
    # 3. Reduced memory footprint
    # 4. Fast terminal rendering
    Palette = @{
        # Core colors - using standard web colors for fastest processing
        Black = "#000000"
        White = "#FFFFFF"
        Gray = "#808080"
        DarkGray = "#404040"
        LightGray = "#C0C0C0"
        
        # Primary colors - minimal set for speed
        Primary = "#0080FF"      # Fast blue
        Secondary = "#00FF00"    # Fast green
        Accent = "#FFFF00"       # Fast yellow
        
        # Status colors - using standard RGB values
        Success = "#00FF00"      # Green
        Warning = "#FFFF00"      # Yellow
        Error = "#FF0000"        # Red
        Info = "#0080FF"         # Blue
        
        # Background hierarchy - minimal variations
        Background = "#000000"   # Pure black - fastest
        Surface = "#1C1C1C"      # Dark gray
        Border = "#404040"       # Medium gray
        
        # Text colors - high contrast for speed
        TextPrimary = "#FFFFFF"      # Pure white
        TextSecondary = "#C0C0C0"    # Light gray
        TextDisabled = "#808080"     # Medium gray
        
        # Pre-computed focus colors
        FocusedBorder = "#0080FF"    # Blue
        ButtonFocusedBg = "#0080FF"  # Blue
        ButtonFocusedFg = "#FFFFFF"  # White
        ListSelectedBg = "#0080FF"   # Blue
        ListSelectedFg = "#FFFFFF"   # White
    }
    
    # PERFORMANCE: Minimal component definitions using direct palette references
    # This eliminates string processing during theme resolution
    Components = @{
        # Screen - minimal overhead
        Screen = @{ 
            Background = '$Palette.Background'
            Foreground = '$Palette.TextPrimary' 
        }
        
        # Panel - reuse colors for speed
        Panel = @{ 
            Background = '$Palette.Surface'
            Border = '$Palette.Border'
            FocusedBorder = '$Palette.FocusedBorder'
            Title = '$Palette.Primary'
            Header = '$Palette.Surface'
            Foreground = '$Palette.TextPrimary'
        }
        
        # Label - minimal color set
        Label = @{ 
            Foreground = '$Palette.TextPrimary'
            Disabled = '$Palette.TextDisabled'
        }
        
        # Button - fast color switching
        Button = @{
            Normal = @{ 
                Foreground = '$Palette.TextPrimary'
                Background = '$Palette.DarkGray'
                Border = '$Palette.Border'
            }
            Focused = @{ 
                Foreground = '$Palette.ButtonFocusedFg'
                Background = '$Palette.ButtonFocusedBg'
                Border = '$Palette.FocusedBorder'
            }
            Pressed = @{ 
                Foreground = '$Palette.Black'
                Background = '$Palette.Secondary'
                Border = '$Palette.FocusedBorder'
            }
            Disabled = @{ 
                Foreground = '$Palette.TextDisabled'
                Background = '$Palette.Background'
                Border = '$Palette.Border'
            }
        }
        
        # Input - minimal color variations
        Input = @{ 
            Background = '$Palette.Surface'
            Foreground = '$Palette.TextPrimary'
            Border = '$Palette.Border'
            FocusedBorder = '$Palette.FocusedBorder'
            Placeholder = '$Palette.TextSecondary'
        }
        
        # List - performance-optimized selection
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.ListSelectedFg'
            ItemSelectedBackground = '$Palette.ListSelectedBg'
            ItemFocused = '$Palette.ListSelectedFg'
            ItemFocusedBackground = '$Palette.FocusedBorder'
            HeaderForeground = '$Palette.Primary'
            HeaderBackground = '$Palette.Surface'
            Scrollbar = '$Palette.Border'
        }
        
        # Status - direct color mapping
        Status = @{ 
            Success = '$Palette.Success'
            Warning = '$Palette.Warning'
            Error = '$Palette.Error'
            Info = '$Palette.Info'
        }
        
        # Overlay - minimal processing
        Overlay = @{ 
            Background = '$Palette.Black'
            DialogBackground = '$Palette.Surface'
        }
    }
    
    # PERFORMANCE: Minimal semantic styling - only essential color variations
    # This reduces theme resolution overhead for data-driven components
    Semantic = @{
        Task = @{
            Status = @{
                Pending = @{ Foreground = '$Palette.Warning'; Background = '$Palette.Surface' }
                InProgress = @{ Foreground = '$Palette.Info'; Background = '$Palette.Surface' }
                Completed = @{ Foreground = '$Palette.Success'; Background = '$Palette.Surface' }
                Cancelled = @{ Foreground = '$Palette.Error'; Background = '$Palette.Surface' }
            }
            Priority = @{
                High = @{ Foreground = '$Palette.Error'; Background = '$Palette.Surface' }
                Medium = @{ Foreground = '$Palette.Warning'; Background = '$Palette.Surface' }
                Low = @{ Foreground = '$Palette.TextSecondary'; Background = '$Palette.Surface' }
            }
            Title = @{
                Normal = @{ Foreground = '$Palette.TextPrimary'; Background = '$Palette.Surface' }
                Overdue = @{ Foreground = '$Palette.Error'; Background = '$Palette.Surface' }
            }
        }
        Project = @{
            Key = @{
                Normal = @{ Foreground = '$Palette.Primary'; Background = '$Palette.Surface' }
            }
            Name = @{
                Normal = @{ Foreground = '$Palette.TextPrimary'; Background = '$Palette.Surface' }
                Overdue = @{ Foreground = '$Palette.Error'; Background = '$Palette.Surface' }
                Inactive = @{ Foreground = '$Palette.TextDisabled'; Background = '$Palette.Surface' }
            }
            Status = @{
                Active = @{ Foreground = '$Palette.Success'; Background = '$Palette.Surface' }
                Inactive = @{ Foreground = '$Palette.TextDisabled'; Background = '$Palette.Surface' }
            }
        }
        DataGrid = @{
            Cell = @{
                Normal = @{ Foreground = '$Palette.TextPrimary'; Background = '$Palette.Surface' }
            }
        }
    }
    
    # PERFORMANCE: Theme metadata for optimization hints
    Performance = @{
        # Hint to cache manager about color frequency
        MostUsedColors = @(
            '$Palette.TextPrimary'
            '$Palette.Background'
            '$Palette.Surface'
            '$Palette.Border'
            '$Palette.FocusedBorder'
        )
        
        # Optimization flags
        FastRendering = $true
        MinimalColorSet = $true
        PrecomputedValues = $true
        
        # Performance characteristics
        ColorCount = 15
        ComponentVariations = 'Minimal'
        SemanticComplexity = 'Low'
    }
}