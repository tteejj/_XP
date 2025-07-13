@{
    Name = "Green Console"
    Description = "Classic green phosphor terminal look"
    
    Palette = @{
        Black = "#000000"
        White = "#00FF00"
        Primary = "#00FF00"
        Secondary = "#008000"
        Accent = "#00FF00"
        Success = "#00FF00"
        Warning = "#FFFF00"
        Error = "#FF0000"
        Info = "#00FF00"
        Background = "#000000"
        Surface = "#001100"
        Border = "#008000"
        TextPrimary = "#00FF00"
        TextSecondary = "#008000"
        TextDisabled = "#004400"
        FocusedBorder = "#00FF00"
        ButtonFocusedBg = "#00FF00"
        ButtonFocusedFg = "#000000"
        ListSelectedBg = "#00FF00"
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
