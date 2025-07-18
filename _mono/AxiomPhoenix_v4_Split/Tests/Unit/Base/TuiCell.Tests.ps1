# ==============================================================================
# Axiom-Phoenix v4.0 - TuiCell Unit Tests
# Core cell component testing for terminal rendering
# ==============================================================================

# Import the framework dependencies in correct order
$scriptDir = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $scriptDir "Base/ABC.001_TuiAnsiHelper.ps1")
. (Join-Path $scriptDir "Base/ABC.002_TuiCell.ps1")

Describe "TuiCell Tests" {
    Context "When creating a new TuiCell" {
        It "Should initialize with default values" {
            $cell = [TuiCell]::new()
            $cell.Char | Should -Be ' '
            $cell.ForegroundColor | Should -Be "#FFFFFF"
            $cell.BackgroundColor | Should -Be "#000000"
            $cell.Bold | Should -Be $false
            $cell.Italic | Should -Be $false
            $cell.Underline | Should -Be $false
            $cell.Strikethrough | Should -Be $false
            $cell.ZIndex | Should -Be 0
        }
        
        It "Should initialize with specified character" {
            $cell = [TuiCell]::new([char]'X')
            $cell.Char | Should -Be 'X'
            $cell.ForegroundColor | Should -Be "#FFFFFF"
            $cell.BackgroundColor | Should -Be "#000000"
        }
        
        It "Should initialize with character and colors" {
            $cell = [TuiCell]::new('A', "#FF0000", "#0000FF")
            $cell.Char | Should -Be 'A'
            $cell.ForegroundColor | Should -Be "#FF0000"
            $cell.BackgroundColor | Should -Be "#0000FF"
        }
    }
    
    Context "When setting cell properties" {
        BeforeEach {
            $cell = [TuiCell]::new()
        }
        
        It "Should allow direct property changes" {
            $cell.Char = 'Z'
            $cell.Char | Should -Be 'Z'
        }
        
        It "Should allow foreground color changes" {
            $cell.ForegroundColor = "#00FF00"
            $cell.ForegroundColor | Should -Be "#00FF00"
        }
        
        It "Should allow background color changes" {
            $cell.BackgroundColor = "#FFFF00"
            $cell.BackgroundColor | Should -Be "#FFFF00"
        }
        
        It "Should allow style property changes" {
            $cell.Bold = $true
            $cell.Italic = $true
            $cell.Underline = $true
            $cell.Strikethrough = $true
            
            $cell.Bold | Should -Be $true
            $cell.Italic | Should -Be $true
            $cell.Underline | Should -Be $true
            $cell.Strikethrough | Should -Be $true
        }
    }
    
    Context "When copying cells" {
        It "Should copy all properties correctly" {
            $source = [TuiCell]::new('M', "#00FFFF", "#000080")
            $source.Bold = $true
            $source.Italic = $true
            $source.ZIndex = 5
            
            $target = [TuiCell]::new($source)
            
            $target.Char | Should -Be 'M'
            $target.ForegroundColor | Should -Be "#00FFFF"
            $target.BackgroundColor | Should -Be "#000080"
            $target.Bold | Should -Be $true
            $target.Italic | Should -Be $true
            $target.ZIndex | Should -Be 5
        }
        
        It "Should handle copy constructor with null gracefully" {
            # This should not throw when creating from non-null
            $original = [TuiCell]::new('A', "#FF0000", "#0000FF")
            $copy = [TuiCell]::new($original)
            
            $copy.Char | Should -Be 'A'
            $copy.ForegroundColor | Should -Be "#FF0000"
            $copy.BackgroundColor | Should -Be "#0000FF"
        }
    }
    
    Context "When using cell methods" {
        It "Should create styled variants with WithStyle" {
            $cell = [TuiCell]::new('X', "#FF0000", "#0000FF")
            
            $styled = $cell.WithStyle("#00FF00", "#FFFF00")
            
            $styled.Char | Should -Be 'X'
            $styled.ForegroundColor | Should -Be "#00FF00"
            $styled.BackgroundColor | Should -Be "#FFFF00"
            
            # Original should be unchanged
            $cell.ForegroundColor | Should -Be "#FF0000"
            $cell.BackgroundColor | Should -Be "#0000FF"
        }
        
        It "Should create character variants with WithChar" {
            $cell = [TuiCell]::new('X', "#FF0000", "#0000FF")
            
            $charVariant = $cell.WithChar('Y')
            
            $charVariant.Char | Should -Be 'Y'
            $charVariant.ForegroundColor | Should -Be "#FF0000"
            $charVariant.BackgroundColor | Should -Be "#0000FF"
            
            # Original should be unchanged
            $cell.Char | Should -Be 'X'
        }
    }
    
    Context "When comparing cells" {
        It "Should detect identical cells" {
            $cell1 = [TuiCell]::new('A', "#FF0000", "#0000FF")
            $cell2 = [TuiCell]::new('A', "#FF0000", "#0000FF")
            
            $cell1.DiffersFrom($cell2) | Should -Be $false
        }
        
        It "Should detect different characters" {
            $cell1 = [TuiCell]::new('A', "#FF0000", "#0000FF")
            $cell2 = [TuiCell]::new('B', "#FF0000", "#0000FF")
            
            $cell1.DiffersFrom($cell2) | Should -Be $true
        }
        
        It "Should detect different foreground colors" {
            $cell1 = [TuiCell]::new('A', "#FF0000", "#0000FF")
            $cell2 = [TuiCell]::new('A', "#00FF00", "#0000FF")
            
            $cell1.DiffersFrom($cell2) | Should -Be $true
        }
        
        It "Should detect different background colors" {
            $cell1 = [TuiCell]::new('A', "#FF0000", "#0000FF")
            $cell2 = [TuiCell]::new('A', "#FF0000", "#FFFF00")
            
            $cell1.DiffersFrom($cell2) | Should -Be $true
        }
        
        It "Should detect different style properties" {
            $cell1 = [TuiCell]::new('A', "#FF0000", "#0000FF")
            $cell2 = [TuiCell]::new('A', "#FF0000", "#0000FF")
            $cell2.Bold = $true
            
            $cell1.DiffersFrom($cell2) | Should -Be $true
        }
        
        It "Should handle null comparison" {
            $cell = [TuiCell]::new('A', "#FF0000", "#0000FF")
            
            $cell.DiffersFrom($null) | Should -Be $true
        }
    }
    
    Context "When getting string representation" {
        It "Should return detailed info for ToString" {
            $cell = [TuiCell]::new('Q', "#FF0000", "#0000FF")
            $cell.Bold = $true
            $result = $cell.ToString()
            
            $result | Should -Match "TuiCell\(Char='Q'"
            $result | Should -Match "FG='#FF0000'"
            $result | Should -Match "BG='#0000FF'"
            $result | Should -Match "Bold=True"
        }
        
        It "Should generate ANSI sequences" {
            $cell = [TuiCell]::new('X', "#FF0000", "#0000FF")
            $ansiString = $cell.ToAnsiString()
            
            # Should contain the character
            $ansiString | Should -Match "X$"
            # Should contain ANSI escape sequences
            $ansiString | Should -Match "\x1b\["
        }
        
        It "Should create legacy format" {
            $cell = [TuiCell]::new('T', "#FF0000", "#0000FF")
            $legacy = $cell.ToLegacyFormat()
            
            $legacy.Char | Should -Be 'T'
            $legacy.FG | Should -Be "#FF0000"
            $legacy.BG | Should -Be "#0000FF"
        }
    }
    
    Context "When blending cells" {
        It "Should blend cells with different Z-indexes" {
            $bottomCell = [TuiCell]::new('A', "#FF0000", "#000000")
            $bottomCell.ZIndex = 1
            
            $topCell = [TuiCell]::new('B', "#00FF00", "#FFFFFF")
            $topCell.ZIndex = 2
            
            $result = $bottomCell.BlendWith($topCell)
            
            # Higher Z-index wins
            $result.Char | Should -Be 'B'
            $result.ForegroundColor | Should -Be "#00FF00"
            $result.ZIndex | Should -Be 2
        }
        
        It "Should use mutable blending for performance" {
            $cell = [TuiCell]::new('A', "#FF0000", "#000000")
            $cell.ZIndex = 1
            
            $otherCell = [TuiCell]::new('B', "#00FF00", "#FFFFFF")
            $otherCell.ZIndex = 2
            
            $cell.BlendWithMutable($otherCell)
            
            # Cell should be modified in place
            $cell.Char | Should -Be 'B'
            $cell.ForegroundColor | Should -Be "#00FF00"
            $cell.ZIndex | Should -Be 2
        }
        
        It "Should handle null blending gracefully" {
            $cell = [TuiCell]::new('A', "#FF0000", "#000000")
            
            $result = $cell.BlendWith($null)
            $result.Char | Should -Be 'A'
            
            # Mutable version should not throw
            { $cell.BlendWithMutable($null) } | Should -Not -Throw
        }
    }
}

Write-Host "TuiCell unit tests loaded" -ForegroundColor Green