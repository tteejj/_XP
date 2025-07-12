# ==============================================================================
# Cyberpunk Theme - Neon-soaked future aesthetic
# Showcases advanced palette-based theming with vibrant neon colors
# ==============================================================================

@{
    Name = "Cyberpunk"
    Description = "Neon-soaked cyberpunk aesthetic with electric blues and hot pinks"
    Version = "1.0"
    Author = "Axiom-Phoenix"
    
    Palette = @{
        # Base neon colors - Electric and vibrant
        Black = "#0d0208"           # Deep black with hint of red
        White = "#e8f4f8"           # Cool white with blue tint
        Primary = "#ff006e"         # Hot magenta/pink - main accent
        Secondary = "#3a0ca3"       # Deep electric purple
        Accent = "#00d4ff"          # Electric cyan - secondary accent
        Success = "#06ffa5"         # Neon green
        Warning = "#ffbe0b"         # Electric yellow
        Error = "#ff4081"           # Bright error pink
        Info = "#00d4ff"            # Electric cyan for info
        Subtle = "#b388ff"          # Muted purple for subtle text
        
        # Neon palette extensions
        Background = "#0d0208"      # Deep dark base
        Surface = "#1a0e1a"         # Dark purple surface
        Border = "#ff006e"          # Hot pink borders
        TextPrimary = "#e8f4f8"     # Cool white text
        TextSecondary = "#b388ff"   # Purple secondary text
        TextDisabled = "#4a148c"    # Very dark purple for disabled
        
        # Special cyberpunk colors
        NeonBlue = "#00d4ff"
        NeonPink = "#ff006e"
        NeonGreen = "#06ffa5"
        NeonPurple = "#b388ff"
        DeepPurple = "#3a0ca3"
        DarkSurface = "#1a0e1a"
    }
    
    Components = @{
        # Screen/Window - Dark base with neon accents
        Screen = @{
            Background = '$Palette.Background'
            Foreground = '$Palette.TextPrimary'
        }
        
        # Panel - Neon-bordered containers
        Panel = @{
            Background = '$Palette.Background'
            Border = '$Palette.NeonPink'
            Title = '$Palette.NeonBlue'
            Header = '$Palette.DarkSurface'
        }
        
        # Labels and Text - High contrast neon
        Label = @{
            Foreground = '$Palette.TextPrimary'
            Disabled = '$Palette.TextDisabled'
        }
        
        # Buttons - Glowing neon effect
        Button = @{
            Normal = @{
                Foreground = '$Palette.Black'
                Background = '$Palette.NeonBlue'
            }
            Focused = @{
                Foreground = '$Palette.Black'
                Background = '$Palette.NeonPink'
            }
            Pressed = @{
                Foreground = '$Palette.White'
                Background = '$Palette.DeepPurple'
            }
            Disabled = @{
                Foreground = '$Palette.TextDisabled'
                Background = '$Palette.DarkSurface'
            }
        }
        
        # Input fields - Dark with neon focus
        Input = @{
            Background = '$Palette.DarkSurface'
            Foreground = '$Palette.TextPrimary'
            Placeholder = '$Palette.TextSecondary'
            Border = '$Palette.DeepPurple'
            FocusedBorder = '$Palette.NeonBlue'
        }
        
        # Lists and Tables - Neon selection
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.Black'
            ItemSelectedBackground = '$Palette.NeonPink'
            ItemFocused = '$Palette.Black'
            ItemFocusedBackground = '$Palette.NeonBlue'
            HeaderForeground = '$Palette.NeonGreen'
            HeaderBackground = '$Palette.DarkSurface'
            Scrollbar = '$Palette.NeonPurple'
        }
        
        # Status - Bright neon alerts
        Status = @{
            Success = '$Palette.NeonGreen'
            Warning = '$Palette.Warning'
            Error = '$Palette.Error'
            Info = '$Palette.NeonBlue'
        }
        
        # Overlay/Dialog - Dark with neon borders
        Overlay = @{
            Background = '$Palette.Black'
            DialogBackground = '$Palette.DarkSurface'
        }
    }
}
