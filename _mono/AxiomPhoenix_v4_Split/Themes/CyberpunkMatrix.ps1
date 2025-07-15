@{
    Name = "Cyberpunk Matrix"
    Description = "Dark cyberpunk with matrix green, electric blue, and danger red"
    
    Palette = @{
        Black = "#0D0F0D"
        White = "#E0FFE0"
        Primary = "#00FF41"
        Secondary = "#00CCFF"
        Accent = "#FF0080"
        Success = "#00FF41"
        Warning = "#FFAA00"
        Error = "#FF0040"
        Info = "#00AAFF"
        Background = "#000000"
        Surface = "#0A0A0A"
        Border = "#00FF41"
        TextPrimary = "#00FF41"
        TextSecondary = "#00CCFF"
        TextDisabled = "#003311"
        
        # Cyberpunk specific colors
        Neon = "#00FFFF"
        Electric = "#0080FF"
        Danger = "#FF0040"
        Violet = "#8000FF"
        Chrome = "#C0C0C0"
        Shadow = "#000A00"
        DataStream = "#00AA22"
        Warning2 = "#FF8000"
    }
    
    Components = @{
        Screen = @{ 
            Background = '$Palette.Background'
            Foreground = '$Palette.TextPrimary' 
        }
        Panel = @{ 
            Background = '$Palette.Surface'
            Border = '$Palette.Primary'
            Title = '$Palette.Neon'
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
                Background = '$Palette.Neon' 
            }
            Pressed = @{ 
                Foreground = '$Palette.White'
                Background = '$Palette.Danger' 
            }
            Disabled = @{ 
                Foreground = '$Palette.TextDisabled'
                Background = '$Palette.Shadow' 
            }
        }
        Input = @{ 
            Background = '$Palette.Shadow'
            Foreground = '$Palette.DataStream'
            Placeholder = '$Palette.TextSecondary'
            Border = '$Palette.DataStream'
            FocusedBorder = '$Palette.Neon'
        }
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.DataStream'
            ItemSelected = '$Palette.Black'
            ItemSelectedBackground = '$Palette.Primary'
            ItemFocused = '$Palette.Black'
            ItemFocusedBackground = '$Palette.Electric'
            HeaderForeground = '$Palette.Neon'
            HeaderBackground = '$Palette.Shadow'
            Scrollbar = '$Palette.Violet'
        }
        Status = @{ 
            Success = '$Palette.Success'
            Warning = '$Palette.Warning2'
            Error = '$Palette.Danger'
            Info = '$Palette.Electric' 
        }
        Overlay = @{ 
            Background = '$Palette.Black'
            DialogBackground = '$Palette.Surface' 
        }
    }
}