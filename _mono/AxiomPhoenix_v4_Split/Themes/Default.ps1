@{
    Name = "Default"
    Description = "Classic terminal colors with blue accents"
    
    Palette = @{
        Black = "#000000"
        White = "#C0C0C0"
        Primary = "#0000FF"
        Secondary = "#000080"
        Accent = "#00FFFF"
        Success = "#00FF00"
        Warning = "#FFFF00"
        Error = "#FF0000"
        Info = "#00FFFF"
        Background = "#000000"
        Surface = "#001100"
        Border = "#808080"
        TextPrimary = "#C0C0C0"
        TextSecondary = "#808080"
        TextDisabled = "#404040"
        FocusedBorder = "#00FFFF"
        ButtonFocusedBg = "#0000FF"
        ButtonFocusedFg = "#FFFFFF"
        ListSelectedBg = "#000080"
        ListSelectedFg = "#FFFFFF"
    }
    
    Components = @{
        Screen = @{ Background = '$Palette.Background'; Foreground = '$Palette.TextPrimary' }
        Panel = @{ Background = '$Palette.Background'; Border = '$Palette.Border'; Title = '$Palette.Accent' }
        Label = @{ Foreground = '$Palette.TextPrimary'; Disabled = '$Palette.TextDisabled' }
        Button = @{
            Normal = @{ Foreground = '$Palette.Black'; Background = '$Palette.Primary' }
            Focused = @{ Foreground = '$Palette.ButtonFocusedFg'; Background = '$Palette.ButtonFocusedBg'; Border = '$Palette.Success' }
            Border = '$Palette.Border'
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
