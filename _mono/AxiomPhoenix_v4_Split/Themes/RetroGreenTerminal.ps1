@{
    Name = "Retro Green Terminal"
    Description = "Classic 80s green phosphor CRT terminal"
    
    Palette = @{
        Black = "#001100"
        White = "#00FF41"
        Primary = "#00FF41"
        Secondary = "#00CC33"
        Accent = "#33FF66"
        Success = "#00FF41"
        Warning = "#CCFF00"
        Error = "#FF3300"
        Info = "#00CCAA"
        Background = "#000000"
        Surface = "#001100"
        Border = "#00FF41"
        TextPrimary = "#00FF41"
        TextSecondary = "#00CC33"
        TextDisabled = "#003311"
        
        # Additional retro colors
        Bright = "#66FF99"
        Dim = "#004422"
        Glow = "#00FF41"
        Shadow = "#002200"
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
            Header = '$Palette.Shadow'
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
                Background = '$Palette.Secondary' 
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
            FocusedBorder = '$Palette.Primary'
        }
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.Black'
            ItemSelectedBackground = '$Palette.Primary'
            ItemFocused = '$Palette.Black'
            ItemFocusedBackground = '$Palette.Bright'
            HeaderForeground = '$Palette.Bright'
            HeaderBackground = '$Palette.Shadow'
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