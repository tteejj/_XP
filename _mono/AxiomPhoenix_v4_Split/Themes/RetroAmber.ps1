# ==============================================================================
# Retro Amber Theme - Classic terminal nostalgia
# Warm amber colors on dark background like vintage terminals
# ==============================================================================

@{
    Name = "Retro Amber"
    Description = "Classic amber terminal aesthetic with warm golden tones"
    Version = "1.0"
    Author = "Axiom-Phoenix"
    
    Palette = @{
        # Classic amber terminal colors
        Black = "#1a0f00"           # Deep brown-black
        White = "#ffb000"           # Bright amber
        Primary = "#ffb000"         # Main amber
        Secondary = "#cc8800"       # Darker amber
        Accent = "#ffcc33"          # Bright yellow-amber
        Success = "#99dd00"         # Amber-green
        Warning = "#ffaa00"         # Orange-amber warning
        Error = "#ff4400"           # Red-amber error
        Info = "#66cc99"            # Muted green-amber
        Subtle = "#995500"          # Dark amber for subtle text
        
        # Amber palette extensions
        Background = "#1a0f00"      # Deep brown-black
        Surface = "#2d1b00"         # Slightly lighter brown
        Border = "#cc8800"          # Medium amber borders
        TextPrimary = "#ffb000"     # Main amber text
        TextSecondary = "#995500"   # Darker amber text
        TextDisabled = "#4d2600"    # Very dark amber for disabled
        
        # Special amber shades
        LightAmber = "#ffcc33"
        MediumAmber = "#ffb000"
        DarkAmber = "#cc8800"
        VeryDarkAmber = "#995500"
        DeepBrown = "#2d1b00"
        AmberGlow = "#ffdd66"
    }
    
    Components = @{
        # Screen/Window - Dark brown base
        Screen = @{
            Background = '$Palette.Background'
            Foreground = '$Palette.TextPrimary'
        }
        
        # Panel - Amber-bordered containers
        Panel = @{
            Background = '$Palette.Background'
            Border = '$Palette.DarkAmber'
            Title = '$Palette.LightAmber'
            Header = '$Palette.DeepBrown'
        }
        
        # Labels and Text - Warm amber
        Label = @{
            Foreground = '$Palette.TextPrimary'
            Disabled = '$Palette.TextDisabled'
        }
        
        # Buttons - Classic amber styling
        Button = @{
            Normal = @{
                Foreground = '$Palette.Background'
                Background = '$Palette.MediumAmber'
            }
            Focused = @{
                Foreground = '$Palette.Background'
                Background = '$Palette.LightAmber'
            }
            Pressed = @{
                Foreground = '$Palette.LightAmber'
                Background = '$Palette.DarkAmber'
            }
            Disabled = @{
                Foreground = '$Palette.TextDisabled'
                Background = '$Palette.DeepBrown'
            }
        }
        
        # Input fields - Amber on dark
        Input = @{
            Background = '$Palette.DeepBrown'
            Foreground = '$Palette.TextPrimary'
            Placeholder = '$Palette.TextSecondary'
            Border = '$Palette.VeryDarkAmber'
            FocusedBorder = '$Palette.LightAmber'
        }
        
        # Lists and Tables - Amber selections
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.Background'
            ItemSelectedBackground = '$Palette.MediumAmber'
            ItemFocused = '$Palette.Background'
            ItemFocusedBackground = '$Palette.LightAmber'
            HeaderForeground = '$Palette.AmberGlow'
            HeaderBackground = '$Palette.DeepBrown'
            Scrollbar = '$Palette.DarkAmber'
        }
        
        # Status - Amber-tinted alerts
        Status = @{
            Success = '$Palette.Success'
            Warning = '$Palette.Warning'
            Error = '$Palette.Error'
            Info = '$Palette.Info'
        }
        
        # Overlay/Dialog - Dark amber overlay
        Overlay = @{
            Background = '$Palette.Background'
            DialogBackground = '$Palette.DeepBrown'
        }
    }
}
