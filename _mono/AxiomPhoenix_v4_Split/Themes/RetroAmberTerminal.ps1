@{
    Name = "Retro Amber Terminal"
    Description = "Warm amber monochrome terminal like old Unix workstations"
    
    Palette = @{
        Black = "#0F0A00"
        White = "#FFAA00"
        Primary = "#FFAA00"
        Secondary = "#CC8800"
        Accent = "#FFCC44"
        Success = "#FFDD00"
        Warning = "#FFFF00"
        Error = "#FF4400"
        Info = "#FFCC88"
        Background = "#000000"
        Surface = "#0F0A00"
        Border = "#FFAA00"
        TextPrimary = "#FFAA00"
        TextSecondary = "#CC8800"
        TextDisabled = "#442200"
        
        # Additional amber tones
        Bright = "#FFDD77"
        Dim = "#663300"
        Warm = "#FF9900"
        Glow = "#FFCC00"
    }
    
    Components = @{
        Screen = @{ 
            Background = '$Palette.Background'
            Foreground = '$Palette.TextPrimary' 
        }
        Panel = @{ 
            Background = '$Palette.Surface'
            Border = '$Palette.Border'
            Title = '$Palette.Bright'
            Header = '$Palette.Dim'
        }
        Label = @{ 
            Foreground = '$Palette.TextPrimary'
            Disabled = '$Palette.TextDisabled' 
        }
        Button = @{
            Normal = @{ 
                Foreground = '$Palette.Black'
                Background = '$Palette.Primary' 
            }
            Focused = @{ 
                Foreground = '$Palette.Black'
                Background = '$Palette.Bright' 
            }
            Pressed = @{ 
                Foreground = '$Palette.Black'
                Background = '$Palette.Warm' 
            }
            Disabled = @{ 
                Foreground = '$Palette.TextDisabled'
                Background = '$Palette.Dim' 
            }
        }
        Input = @{ 
            Background = '$Palette.Surface'
            Foreground = '$Palette.TextPrimary'
            Placeholder = '$Palette.TextSecondary'
            Border = '$Palette.Dim'
            FocusedBorder = '$Palette.Glow'
        }
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.Black'
            ItemSelectedBackground = '$Palette.Primary'
            ItemFocused = '$Palette.Black'
            ItemFocusedBackground = '$Palette.Bright'
            HeaderForeground = '$Palette.Bright'
            HeaderBackground = '$Palette.Dim'
            Scrollbar = '$Palette.Secondary'
        }
        Status = @{ 
            Success = '$Palette.Success'
            Warning = '$Palette.Warning'
            Error = '$Palette.Error'
            Info = '$Palette.Info' 
        }
        Overlay = @{ 
            Background = '$Palette.Black'
            DialogBackground = '$Palette.Surface' 
        }
    }
}