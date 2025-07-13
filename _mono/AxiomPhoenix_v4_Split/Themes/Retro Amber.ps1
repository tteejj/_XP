@{
    Name = "Retro Amber"
    Description = "Classic amber terminal aesthetic"
    
    Palette = @{
        Black = "#000000"
        White = "#FFBF00"
        Primary = "#FFBF00"
        Secondary = "#CC9900"
        Accent = "#FFFF00"
        Success = "#00FF00"
        Warning = "#FFFF00"
        Error = "#FF0000"
        Info = "#FFBF00"
        Background = "#000000"
        Surface = "#1A1300"
        Border = "#CC9900"
        TextPrimary = "#FFBF00"
        TextSecondary = "#CC9900"
        TextDisabled = "#665500"
        FocusedBorder = "#FFFF00"
        ButtonFocusedBg = "#FFBF00"
        ButtonFocusedFg = "#000000"
        ListSelectedBg = "#FFBF00"
        ListSelectedFg = "#000000"
    }
    
    Components = @{
        Screen = @{ Background = '$Palette.Background'; Foreground = '$Palette.TextPrimary' }
        Panel = @{ Background = '$Palette.Background'; Border = '$Palette.Border'; Title = '$Palette.Primary' }
        Label = @{ Foreground = '$Palette.TextPrimary'; Disabled = '$Palette.TextDisabled' }
        Button = @{
            Normal = @{ Foreground = '$Palette.ButtonFocusedFg'; Background = '$Palette.Primary' }
            Focused = @{ Foreground = '$Palette.ButtonFocusedFg'; Background = '$Palette.ButtonFocusedBg' }
        }
        Input = @{ 
            Background = '$Palette.Background'
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
