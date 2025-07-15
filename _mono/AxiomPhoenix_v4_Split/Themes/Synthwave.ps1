@{
    Name = "Synthwave"
    Description = "Retro 80s neon colors"
    
    Palette = @{
        Black = "#0A0A0A"
        White = "#FF00FF"
        Primary = "#FF00FF"
        Secondary = "#00FFFF"
        Accent = "#FF00FF"
        Success = "#00FF88"
        Warning = "#FFD700"
        Error = "#FF0066"
        Info = "#00D4FF"
        Background = "#0A0A0A"
        Surface = "#1A0A1A"
        Border = "#FF00FF"
        TextPrimary = "#FF00FF"
        TextSecondary = "#00FFFF"
        TextDisabled = "#663366"
        FocusedBorder = "#00FFFF"
        ButtonFocusedBg = "#FF00FF"
        ButtonFocusedFg = "#000000"
        ListSelectedBg = "#FF00FF"
        ListSelectedFg = "#000000"
    }
    
    Components = @{
        Screen = @{ Background = '$Palette.Background'; Foreground = '$Palette.TextPrimary' }
        Panel = @{ Background = '$Palette.Surface'; Border = '$Palette.Border'; Title = '$Palette.Secondary'; Foreground = '$Palette.TextPrimary' }
        Label = @{ Foreground = '$Palette.TextPrimary'; Disabled = '$Palette.TextDisabled' }
        Button = @{
            Normal = @{ Foreground = '$Palette.ButtonFocusedFg'; Background = '$Palette.Primary' }
            Focused = @{ Foreground = '$Palette.ButtonFocusedFg'; Background = '$Palette.ButtonFocusedBg' }
        }
        Input = @{ 
            Background = '$Palette.Surface'
            Foreground = '$Palette.TextPrimary'
            Border = '$Palette.Border'
            FocusedBorder = '$Palette.FocusedBorder'
        }
        List = @{
            Background = '$Palette.Background'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.ListSelectedFg'
            ItemSelectedBackground = '$Palette.ListSelectedBg'
        }
    }
}
