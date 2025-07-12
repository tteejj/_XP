# ==============================================================================
# Modern Dark Theme - Professional dark interface
# Subtle grays and blues for a modern development environment feel
# ==============================================================================

@{
    Name = "Modern Dark"
    Description = "Professional dark theme with subtle blues and grays"
    Version = "1.0"
    Author = "Axiom-Phoenix"
    
    Palette = @{
        # Modern dark palette - Professional and clean
        Black = "#1e1e1e"           # VS Code dark background
        White = "#d4d4d4"           # Light gray text
        Primary = "#007acc"         # VS Code blue
        Secondary = "#4a5568"       # Medium gray
        Accent = "#f56500"          # Orange accent
        Success = "#22c55e"         # Modern green
        Warning = "#f59e0b"         # Modern amber
        Error = "#ef4444"           # Modern red
        Info = "#3b82f6"            # Modern blue
        Subtle = "#9ca3af"          # Light gray for subtle text
        
        # Modern gray scale
        Background = "#1e1e1e"      # Dark background
        Surface = "#2d2d30"         # Slightly lighter surface
        Border = "#404040"          # Medium gray borders
        TextPrimary = "#d4d4d4"     # Light gray text
        TextSecondary = "#9ca3af"   # Medium gray text
        TextDisabled = "#6b7280"    # Disabled gray
        
        # Special modern colors
        BluePrimary = "#007acc"
        BlueSecondary = "#0e7490"
        GrayLight = "#d4d4d4"
        GrayMedium = "#9ca3af"
        GrayDark = "#4a5568"
        SurfaceHover = "#3a3a3a"
    }
    
    Components = @{
        # Screen/Window - Clean dark base
        Screen = @{
            Background = '$Palette.Background'
            Foreground = '$Palette.TextPrimary'
        }
        
        # Panel - Subtle borders and surfaces
        Panel = @{
            Background = '$Palette.Background'
            Border = '$Palette.Border'
            Title = '$Palette.BluePrimary'
            Header = '$Palette.Surface'
        }
        
        # Labels and Text - Clean hierarchy
        Label = @{
            Foreground = '$Palette.TextPrimary'
            Disabled = '$Palette.TextDisabled'
        }
        
        # Additional standardized paths
        TextBox = @{
            Background = '$Palette.Surface'
            Foreground = '$Palette.TextPrimary'
            Border = '$Palette.Border'
            FocusedBorder = '$Palette.BluePrimary'
        }
        
        # Buttons - Modern flat design
        Button = @{
            Normal = @{
                Foreground = '$Palette.White'
                Background = '$Palette.BluePrimary'
            }
            Focused = @{
                Foreground = '$Palette.White'
                Background = '$Palette.BlueSecondary'
            }
            Pressed = @{
                Foreground = '$Palette.TextPrimary'
                Background = '$Palette.GrayDark'
            }
            Disabled = @{
                Foreground = '$Palette.TextDisabled'
                Background = '$Palette.Surface'
            }
        }
        
        # Input fields - Clean modern inputs
        Input = @{
            Background = '$Palette.Surface'
            Foreground = '$Palette.TextPrimary'
            Placeholder = '$Palette.TextSecondary'
            Border = '$Palette.Border'
            FocusedBorder = '$Palette.BluePrimary'
        }
        
        # Lists and Tables - Subtle selections
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.White'
            ItemSelectedBackground = '$Palette.BluePrimary'
            ItemFocused = '$Palette.TextPrimary'
            ItemFocusedBackground = '$Palette.SurfaceHover'
            HeaderForeground = '$Palette.GrayMedium'
            HeaderBackground = '$Palette.Surface'
            Scrollbar = '$Palette.Border'
        }
        
        # Status - Modern semantic colors
        Status = @{
            Success = '$Palette.Success'
            Warning = '$Palette.Warning'
            Error = '$Palette.Error'
            Info = '$Palette.Info'
        }
        
        # Overlay/Dialog - Subtle overlays
        Overlay = @{
            Background = '$Palette.Black'
            DialogBackground = '$Palette.Surface'
        }
    }
}
