# ==============================================================================
# High Contrast Theme - Maximum accessibility
# High contrast colors for improved visibility and accessibility
# ==============================================================================

@{
    Name = "High Contrast"
    Description = "Maximum contrast theme for accessibility and visibility"
    Version = "1.0"
    Author = "Axiom-Phoenix"
    
    Palette = @{
        # High contrast palette - Maximum readability
        Black = "#000000"           # Pure black
        White = "#ffffff"           # Pure white
        Primary = "#ffffff"         # White primary
        Secondary = "#c0c0c0"       # Light gray
        Accent = "#ffff00"          # Bright yellow accent
        Success = "#00ff00"         # Bright green
        Warning = "#ffff00"         # Bright yellow
        Error = "#ff0000"           # Bright red
        Info = "#00ffff"            # Bright cyan
        Subtle = "#c0c0c0"          # Light gray for subtle text
        
        # High contrast grayscale
        Background = "#000000"      # Pure black background
        Surface = "#1a1a1a"         # Very dark gray surface
        Border = "#ffffff"          # White borders for maximum contrast
        TextPrimary = "#ffffff"     # Pure white text
        TextSecondary = "#c0c0c0"   # Light gray text
        TextDisabled = "#808080"    # Medium gray for disabled
        
        # Special high contrast colors
        BrightWhite = "#ffffff"
        BrightYellow = "#ffff00"
        BrightGreen = "#00ff00"
        BrightRed = "#ff0000"
        BrightCyan = "#00ffff"
        BrightMagenta = "#ff00ff"
        MediumGray = "#808080"
        LightGray = "#c0c0c0"
    }
    
    Components = @{
        # Screen/Window - Maximum contrast base
        Screen = @{
            Background = '$Palette.Background'
            Foreground = '$Palette.TextPrimary'
        }
        
        # Panel - High contrast borders
        Panel = @{
            Background = '$Palette.Background'
            Border = '$Palette.BrightWhite'
            Title = '$Palette.BrightYellow'
            Header = '$Palette.Surface'
        }
        
        # Labels and Text - Maximum readability
        Label = @{
            Foreground = '$Palette.TextPrimary'
            Disabled = '$Palette.TextDisabled'
        }
        
        # Buttons - High contrast states
        Button = @{
            Normal = @{
                Foreground = '$Palette.Black'
                Background = '$Palette.BrightWhite'
            }
            Focused = @{
                Foreground = '$Palette.Black'
                Background = '$Palette.BrightYellow'
            }
            Pressed = @{
                Foreground = '$Palette.White'
                Background = '$Palette.MediumGray'
            }
            Disabled = @{
                Foreground = '$Palette.TextDisabled'
                Background = '$Palette.Surface'
            }
        }
        
        # Input fields - Maximum contrast
        Input = @{
            Background = '$Palette.Surface'
            Foreground = '$Palette.TextPrimary'
            Placeholder = '$Palette.TextSecondary'
            Border = '$Palette.LightGray'
            FocusedBorder = '$Palette.BrightYellow'
        }
        
        # Lists and Tables - High contrast selections
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.Black'
            ItemSelectedBackground = '$Palette.BrightWhite'
            ItemFocused = '$Palette.Black'
            ItemFocusedBackground = '$Palette.BrightYellow'
            HeaderForeground = '$Palette.BrightCyan'
            HeaderBackground = '$Palette.Surface'
            Scrollbar = '$Palette.LightGray'
        }
        
        # Status - Bright accessible colors
        Status = @{
            Success = '$Palette.BrightGreen'
            Warning = '$Palette.BrightYellow'
            Error = '$Palette.BrightRed'
            Info = '$Palette.BrightCyan'
        }
        
        # Overlay/Dialog - High contrast overlays
        Overlay = @{
            Background = '$Palette.Black'
            DialogBackground = '$Palette.Surface'
        }
    }
}
