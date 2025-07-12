# ==============================================================================
# Green Theme - Classic terminal green aesthetic
# Nostalgic green-on-black terminal styling
# ==============================================================================

@{
    Name = "Green"
    Description = "Classic terminal green aesthetic with nostalgic monochrome styling"
    Version = "1.0"
    Author = "Axiom-Phoenix"
    
    Palette = @{
        # Base colors - Classic green terminal
        Black = "#000000"           # Pure black background
        White = "#ffffff"           # Pure white (rarely used)
        Primary = "#00ff00"         # Bright terminal green
        Secondary = "#008000"       # Darker green
        Accent = "#ffff00"          # Bright yellow accent
        Success = "#00ff00"         # Same as primary green
        Warning = "#ffff00"         # Bright yellow warning
        Error = "#ff0000"           # Bright red error
        Info = "#00ffff"            # Cyan for info
        Subtle = "#008000"          # Darker green for subtle text
        
        # Structural colors
        Background = "#000000"      # Pure black background
        Surface = "#001100"         # Very dark green surface
        Border = "#00ff00"          # Bright green borders
        TextPrimary = "#00ff00"     # Bright green text
        TextSecondary = "#008000"   # Darker green secondary text
        TextDisabled = "#004400"    # Very dark green for disabled
    }
    
    Components = @{
        # Screen/Window - Classic black base
        Screen = @{
            Background = '$Palette.Background'
            Foreground = '$Palette.TextPrimary'
        }
        
        # Panel - Green borders on black
        Panel = @{
            Background = '$Palette.Background'
            Border = '$Palette.Border'
            Title = '$Palette.Primary'
            Header = '$Palette.Surface'
        }
        
        # Labels and Text - Green monochrome
        Label = @{
            Foreground = '$Palette.TextPrimary'
            Disabled = '$Palette.TextDisabled'
        }
        
        # Buttons - High contrast green
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
                Background = '$Palette.Surface'
            }
        }
        
        # Input fields - Dark green with bright accents
        Input = @{
            Background = '$Palette.Surface'
            Foreground = '$Palette.TextPrimary'
            Placeholder = '$Palette.TextSecondary'
            Border = '$Palette.Border'
            FocusedBorder = '$Palette.Primary'
        }
        
        # Lists and Tables - Classic green selections
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.Black'
            ItemSelectedBackground = '$Palette.Primary'
            ItemFocused = '$Palette.Black'
            ItemFocusedBackground = '$Palette.Accent'
            HeaderForeground = '$Palette.Primary'
            HeaderBackground = '$Palette.Surface'
            Scrollbar = '$Palette.Secondary'
        }
        
        # Status - Terminal color alerts
        Status = @{
            Success = '$Palette.Success'
            Warning = '$Palette.Warning'
            Error = '$Palette.Error'
            Info = '$Palette.Info'
        }
        
        # Overlay/Dialog - Dark green overlays
        Overlay = @{
            Background = '$Palette.Black'
            DialogBackground = '$Palette.Surface'
        }
    }
}
