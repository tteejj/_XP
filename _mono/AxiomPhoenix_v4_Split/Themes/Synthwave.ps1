# ==============================================================================
# Synthwave Theme - Original neon cyberpunk aesthetic
# The classic Axiom-Phoenix theme with electric colors
# ==============================================================================

@{
    Name = "Synthwave"
    Description = "Original neon cyberpunk aesthetic with hot pink and electric blue"
    Version = "1.0"
    Author = "Axiom-Phoenix"
    
    Palette = @{
        # Base colors - Original synthwave palette
        Black = "#0a0e27"           # Deep space black
        White = "#ffffff"           # Pure white
        Primary = "#f92aad"         # Hot pink primary
        Secondary = "#5a189a"       # Deep purple secondary
        Accent = "#ffcc00"          # Electric yellow accent
        Success = "#3bf4fb"         # Cyan success
        Warning = "#ffbe0b"         # Amber warning
        Error = "#ff006e"           # Magenta error
        Info = "#8338ec"            # Purple info
        Subtle = "#72f1b8"          # Mint green subtle
        
        # Structural colors
        Background = "#0a0e27"      # Deep space background
        Surface = "#1a1e3a"         # Slightly lighter surface
        Border = "#2a2e4a"          # Medium border
        TextPrimary = "#f92aad"     # Hot pink text
        TextSecondary = "#72f1b8"   # Mint secondary text
        TextDisabled = "#555555"    # Gray disabled text
    }
    
    Components = @{
        # Screen/Window - Deep space base
        Screen = @{
            Background = '$Palette.Background'
            Foreground = '$Palette.TextPrimary'
        }
        
        # Panel - Hot pink borders and electric accents
        Panel = @{
            Background = '$Palette.Background'
            Border = '$Palette.Border'
            Title = '$Palette.Accent'
            Header = '$Palette.Surface'
        }
        
        # Labels and Text - Hot pink hierarchy
        Label = @{
            Foreground = '$Palette.TextPrimary'
            Disabled = '$Palette.TextDisabled'
        }
        
        # Buttons - High contrast synthwave
        Button = @{
            Normal = @{
                Foreground = '$Palette.Black'
                Background = '$Palette.Primary'
            }
            Focused = @{
                Foreground = '$Palette.Black'
                Background = '$Palette.Accent'
            }
            Pressed = @{
                Foreground = '$Palette.Black'
                Background = '$Palette.Secondary'
            }
            Disabled = @{
                Foreground = '$Palette.TextDisabled'
                Background = '$Palette.Border'
            }
        }
        
        # Input fields - Dark with neon accents
        Input = @{
            Background = '$Palette.Surface'
            Foreground = '$Palette.TextPrimary'
            Placeholder = '$Palette.TextSecondary'
            Border = '$Palette.Border'
            FocusedBorder = '$Palette.Accent'
        }
        
        # Lists and Tables - Electric selections
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.Black'
            ItemSelectedBackground = '$Palette.Primary'
            ItemFocused = '$Palette.Black'
            ItemFocusedBackground = '$Palette.Accent'
            HeaderForeground = '$Palette.Accent'
            HeaderBackground = '$Palette.Surface'
            Scrollbar = '$Palette.Subtle'
        }
        
        # Status - Bright synthwave alerts
        Status = @{
            Success = '$Palette.Success'
            Warning = '$Palette.Warning'
            Error = '$Palette.Error'
            Info = '$Palette.Info'
        }
        
        # Overlay/Dialog - Deep space overlays
        Overlay = @{
            Background = '$Palette.Black'
            DialogBackground = '$Palette.Surface'
        }
    }
}
