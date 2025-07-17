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
        Panel = @{ Background = '$Palette.Surface'; Border = '$Palette.Border'; FocusedBorder = '$Palette.FocusedBorder'; Title = '$Palette.Secondary'; Foreground = '$Palette.TextPrimary' }
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
    
    # Semantic styling for dynamic data-driven themes
    Semantic = @{
        Task = @{
            Status = @{
                Pending = @{ Foreground = '$Palette.Warning'; Background = '$Palette.Surface' }
                InProgress = @{ Foreground = '$Palette.Info'; Background = '$Palette.Surface' }
                Completed = @{ Foreground = '$Palette.Success'; Background = '$Palette.Surface' }
                Cancelled = @{ Foreground = '$Palette.Error'; Background = '$Palette.Surface' }
            }
            Priority = @{
                High = @{ Foreground = '$Palette.Error'; Background = '$Palette.Surface' }
                Medium = @{ Foreground = '$Palette.Warning'; Background = '$Palette.Surface' }
                Low = @{ Foreground = '$Palette.TextDisabled'; Background = '$Palette.Surface' }
            }
            Title = @{
                Normal = @{ Foreground = '$Palette.TextPrimary'; Background = '$Palette.Surface' }
                Overdue = @{ Foreground = '$Palette.Error'; Background = '$Palette.Surface' }
            }
            Progress = @{
                Complete = @{ Foreground = '$Palette.Success'; Background = '$Palette.Surface' }
                High = @{ Foreground = '$Palette.Info'; Background = '$Palette.Surface' }
                Medium = @{ Foreground = '$Palette.Warning'; Background = '$Palette.Surface' }
                Low = @{ Foreground = '$Palette.Error'; Background = '$Palette.Surface' }
            }
        }
        Project = @{
            Key = @{
                Normal = @{ Foreground = '$Palette.Secondary'; Background = '$Palette.Surface' }
            }
            Name = @{
                Normal = @{ Foreground = '$Palette.TextPrimary'; Background = '$Palette.Surface' }
                Overdue = @{ Foreground = '$Palette.Error'; Background = '$Palette.Surface' }
                Inactive = @{ Foreground = '$Palette.TextDisabled'; Background = '$Palette.Surface' }
            }
            Status = @{
                Active = @{ Foreground = '$Palette.Success'; Background = '$Palette.Surface' }
                Inactive = @{ Foreground = '$Palette.TextDisabled'; Background = '$Palette.Surface' }
            }
            Owner = @{
                Assigned = @{ Foreground = '$Palette.TextPrimary'; Background = '$Palette.Surface' }
                Unassigned = @{ Foreground = '$Palette.TextDisabled'; Background = '$Palette.Surface' }
            }
        }
        DataGrid = @{
            Cell = @{
                Normal = @{ Foreground = '$Palette.TextPrimary'; Background = '$Palette.Surface' }
            }
        }
    }
}
