@{
    Name = "Quantum Nova"
    Description = "Stellar quantum interface with cosmic colors and energy patterns"
    
    Palette = @{
        Black = "#000511"
        White = "#FFFFFF"
        Primary = "#00D4FF"
        Secondary = "#FF6B35"
        Accent = "#7C3AED"
        Success = "#10B981"
        Warning = "#F59E0B"
        Error = "#EF4444"
        Info = "#3B82F6"
        Background = "#000511"
        Surface = "#0F1419"
        Border = "#00D4FF"
        TextPrimary = "#E0E6FF"
        TextSecondary = "#A0B3FF"
        TextDisabled = "#3A4B6B"
        
        # Quantum/Cosmic colors
        QuantumBlue = "#00D4FF"
        NovaOrange = "#FF6B35"
        PulsarPurple = "#7C3AED"
        StarWhite = "#FFFFFF"
        SpaceBlack = "#000511"
        NebulaBlue = "#1E3A8A"
        CosmicViolet = "#5B21B6"
        SolarFlare = "#FBBF24"
        GalaxyPink = "#EC4899"
        PlasmaTeal = "#14B8A6"
        AuroraGreen = "#059669"
        MeteorRed = "#DC2626"
        
        # Energy states
        Energy1 = "#00D4FF"    # High energy (quantum blue)
        Energy2 = "#7C3AED"    # Medium energy (pulsar purple)
        Energy3 = "#FF6B35"    # Low energy (nova orange)
        Energy4 = "#14B8A6"    # Stable energy (plasma teal)
        
        # Depth layers
        Void = "#000000"
        DeepSpace = "#000511"
        MidSpace = "#0F1419"
        NearSpace = "#1E293B"
        Atmosphere = "#334155"
    }
    
    Components = @{
        Screen = @{ 
            Background = '$Palette.DeepSpace'
            Foreground = '$Palette.TextPrimary' 
        }
        Panel = @{ 
            Background = '$Palette.MidSpace'
            Border = '$Palette.QuantumBlue'
            Title = '$Palette.StarWhite'
            Header = '$Palette.NearSpace'
        }
        Label = @{ 
            Foreground = '$Palette.TextPrimary'
            Disabled = '$Palette.TextDisabled' 
        }
        Button = @{
            Normal = @{ 
                Foreground = '$Palette.StarWhite'
                Background = '$Palette.Energy2' 
            }
            Focused = @{ 
                Foreground = '$Palette.SpaceBlack'
                Background = '$Palette.Energy1' 
            }
            Pressed = @{ 
                Foreground = '$Palette.StarWhite'
                Background = '$Palette.Energy3' 
            }
            Disabled = @{ 
                Foreground = '$Palette.TextDisabled'
                Background = '$Palette.Atmosphere' 
            }
        }
        Input = @{ 
            Background = '$Palette.DeepSpace'
            Foreground = '$Palette.QuantumBlue'
            Placeholder = '$Palette.TextSecondary'
            Border = '$Palette.Atmosphere'
            FocusedBorder = '$Palette.Energy1'
        }
        List = @{
            Background = '$Palette.Void'
            ItemNormal = '$Palette.TextPrimary'
            ItemSelected = '$Palette.SpaceBlack'
            ItemSelectedBackground = '$Palette.Energy1'
            ItemFocused = '$Palette.StarWhite'
            ItemFocusedBackground = '$Palette.Energy2'
            HeaderForeground = '$Palette.StarWhite'
            HeaderBackground = '$Palette.NebulaBlue'
            Scrollbar = '$Palette.Energy4'
        }
        Status = @{ 
            Success = '$Palette.AuroraGreen'
            Warning = '$Palette.SolarFlare'
            Error = '$Palette.MeteorRed'
            Info = '$Palette.PlasmaTeal' 
        }
        Overlay = @{ 
            Background = '$Palette.Void'
            DialogBackground = '$Palette.MidSpace' 
        }
        
        # Advanced component states
        DataGrid = @{
            HeaderBackground = '$Palette.NebulaBlue'
            HeaderForeground = '$Palette.StarWhite'
            AlternateRowBackground = '$Palette.DeepSpace'
            SelectedRowBackground = '$Palette.CosmicViolet'
            SelectedRowForeground = '$Palette.StarWhite'
        }
        CommandPalette = @{
            Background = '$Palette.MidSpace'
            Border = '$Palette.GalaxyPink'
            SearchBackground = '$Palette.DeepSpace'
            SearchForeground = '$Palette.QuantumBlue'
            HighlightBackground = '$Palette.PulsarPurple'
            HighlightForeground = '$Palette.StarWhite'
        }
        Navigation = @{
            ActiveBackground = '$Palette.Energy1'
            ActiveForeground = '$Palette.SpaceBlack'
            HoverBackground = '$Palette.Energy2'
            HoverForeground = '$Palette.StarWhite'
        }
        Progress = @{
            Background = '$Palette.NearSpace'
            Foreground = '$Palette.Energy1'
            CompleteBackground = '$Palette.AuroraGreen'
            ErrorBackground = '$Palette.MeteorRed'
        }
        Tooltip = @{
            Background = '$Palette.Atmosphere'
            Foreground = '$Palette.QuantumBlue'
            Border = '$Palette.Energy4'
        }
    }
}