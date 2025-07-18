# ==============================================================================
# Axiom-Phoenix v4.0 - TuiBuffer Unit Tests
# Buffer management and rendering testing
# ==============================================================================

# Import the framework
$scriptDir = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $scriptDir "Base/ABC.002_TuiCell.ps1")
. (Join-Path $scriptDir "Base/ABC.003_TuiBuffer.ps1")

Describe "TuiBuffer Tests" {
    Context "When creating a new buffer" {
        It "Should initialize with specified dimensions" {
            $buffer = [TuiBuffer]::new(80, 24)
            
            $buffer.Width | Should -Be 80
            $buffer.Height | Should -Be 24
            $buffer.Buffer | Should -Not -BeNull
            $buffer.Buffer.Count | Should -Be 24
            $buffer.Buffer[0].Count | Should -Be 80
        }
        
        It "Should initialize all cells as empty" {
            $buffer = [TuiBuffer]::new(10, 5)
            
            for ($y = 0; $y -lt 5; $y++) {
                for ($x = 0; $x -lt 10; $x++) {
                    $cell = $buffer.Buffer[$y][$x]
                    $cell.Character | Should -Be ' '
                    $cell.ForegroundColor | Should -Be ([ConsoleColor]::White)
                    $cell.BackgroundColor | Should -Be ([ConsoleColor]::Black)
                    $cell.IsDirty | Should -Be $false
                }
            }
        }
        
        It "Should handle minimum dimensions" {
            $buffer = [TuiBuffer]::new(1, 1)
            
            $buffer.Width | Should -Be 1
            $buffer.Height | Should -Be 1
            $buffer.Buffer[0][0] | Should -Not -BeNull
        }
    }
    
    Context "When writing to buffer" {
        BeforeEach {
            $buffer = [TuiBuffer]::new(20, 10)
        }
        
        It "Should write single character correctly" {
            $buffer.WriteCharacter(5, 3, 'A')
            
            $cell = $buffer.Buffer[3][5]
            $cell.Character | Should -Be 'A'
            $cell.IsDirty | Should -Be $true
        }
        
        It "Should write string correctly" {
            $buffer.WriteString(2, 1, "Hello")
            
            $buffer.Buffer[1][2].Character | Should -Be 'H'
            $buffer.Buffer[1][3].Character | Should -Be 'e'
            $buffer.Buffer[1][4].Character | Should -Be 'l'
            $buffer.Buffer[1][5].Character | Should -Be 'l'
            $buffer.Buffer[1][6].Character | Should -Be 'o'
        }
        
        It "Should write string with colors" {
            $buffer.WriteString(0, 0, "Test", [ConsoleColor]::Red, [ConsoleColor]::Blue)
            
            for ($i = 0; $i -lt 4; $i++) {
                $cell = $buffer.Buffer[0][$i]
                $cell.ForegroundColor | Should -Be ([ConsoleColor]::Red)
                $cell.BackgroundColor | Should -Be ([ConsoleColor]::Blue)
                $cell.IsDirty | Should -Be $true
            }
        }
        
        It "Should handle string overflow gracefully" {
            $longString = "This is a very long string that exceeds buffer width"
            $buffer.WriteString(15, 0, $longString)
            
            # Should only write up to buffer boundary
            $buffer.Buffer[0][19].Character | Should -Not -Be ' '
            # Should not crash or write beyond buffer
        }
        
        It "Should handle negative coordinates" {
            { $buffer.WriteCharacter(-1, 0, 'X') } | Should -Not -Throw
            { $buffer.WriteCharacter(0, -1, 'X') } | Should -Not -Throw
            
            # Buffer should remain unchanged
            $buffer.Buffer[0][0].Character | Should -Be ' '
        }
        
        It "Should handle coordinates beyond buffer" {
            { $buffer.WriteCharacter(25, 0, 'X') } | Should -Not -Throw
            { $buffer.WriteCharacter(0, 15, 'X') } | Should -Not -Throw
            
            # Buffer should remain unchanged at valid positions
            $buffer.Buffer[0][0].Character | Should -Be ' '
        }
    }
    
    Context "When reading from buffer" {
        BeforeEach {
            $buffer = [TuiBuffer]::new(20, 10)
            $buffer.WriteString(5, 2, "Hello World")
        }
        
        It "Should read single character correctly" {
            $char = $buffer.GetCharacterAt(5, 2)
            $char | Should -Be 'H'
            
            $char = $buffer.GetCharacterAt(10, 2)
            $char | Should -Be ' '  # Space between Hello and World
        }
        
        It "Should read string correctly" {
            $text = $buffer.GetStringAt(5, 2, 5)  # "Hello"
            $text | Should -Be "Hello"
            
            $text = $buffer.GetStringAt(11, 2, 5)  # "World"
            $text | Should -Be "World"
        }
        
        It "Should handle reading beyond buffer bounds" {
            $char = $buffer.GetCharacterAt(25, 2)
            $char | Should -Be $null
            
            $text = $buffer.GetStringAt(18, 2, 10)  # Extends beyond width
            $text.Length | Should -BeLessOrEqual 2
        }
    }
    
    Context "When resizing buffer" {
        It "Should expand buffer correctly" {
            $buffer = [TuiBuffer]::new(10, 5)
            $buffer.WriteString(0, 0, "Test")
            
            $buffer.Resize(15, 8)
            
            $buffer.Width | Should -Be 15
            $buffer.Height | Should -Be 8
            $buffer.Buffer.Count | Should -Be 8
            $buffer.Buffer[0].Count | Should -Be 15
            
            # Original content should be preserved
            $buffer.GetStringAt(0, 0, 4) | Should -Be "Test"
        }
        
        It "Should shrink buffer correctly" {
            $buffer = [TuiBuffer]::new(20, 10)
            $buffer.WriteString(0, 0, "Top Left")
            $buffer.WriteString(15, 8, "Bottom Right")
            
            $buffer.Resize(10, 5)
            
            $buffer.Width | Should -Be 10
            $buffer.Height | Should -Be 5
            
            # Content within new bounds should be preserved
            $buffer.GetStringAt(0, 0, 8) | Should -Be "Top Left"
            # Content outside new bounds should be lost
        }
        
        It "Should handle resize to same dimensions" {
            $buffer = [TuiBuffer]::new(10, 5)
            $buffer.WriteString(0, 0, "Test")
            
            $buffer.Resize(10, 5)
            
            $buffer.Width | Should -Be 10
            $buffer.Height | Should -Be 5
            $buffer.GetStringAt(0, 0, 4) | Should -Be "Test"
        }
    }
    
    Context "When clearing buffer" {
        It "Should clear entire buffer" {
            $buffer = [TuiBuffer]::new(10, 5)
            $buffer.WriteString(0, 0, "Test Content")
            $buffer.WriteString(0, 2, "More Content")
            
            $buffer.Clear()
            
            for ($y = 0; $y -lt $buffer.Height; $y++) {
                for ($x = 0; $x -lt $buffer.Width; $x++) {
                    $cell = $buffer.Buffer[$y][$x]
                    $cell.Character | Should -Be ' '
                    $cell.ForegroundColor | Should -Be ([ConsoleColor]::White)
                    $cell.BackgroundColor | Should -Be ([ConsoleColor]::Black)
                    $cell.IsDirty | Should -Be $false
                }
            }
        }
        
        It "Should clear specific region" {
            $buffer = [TuiBuffer]::new(10, 5)
            $buffer.WriteString(0, 0, "1234567890")
            $buffer.WriteString(0, 1, "ABCDEFGHIJ")
            
            $buffer.ClearRegion(2, 0, 5, 2)
            
            # Area outside clear region should be preserved
            $buffer.GetCharacterAt(0, 0) | Should -Be '1'
            $buffer.GetCharacterAt(1, 0) | Should -Be '2'
            $buffer.GetCharacterAt(7, 0) | Should -Be '8'
            
            # Area inside clear region should be empty
            for ($x = 2; $x -lt 7; $x++) {
                for ($y = 0; $y -lt 2; $y++) {
                    $buffer.GetCharacterAt($x, $y) | Should -Be ' '
                }
            }
        }
    }
    
    Context "When copying buffers" {
        It "Should copy from another buffer" {
            $source = [TuiBuffer]::new(10, 5)
            $source.WriteString(0, 0, "Source")
            $source.WriteString(0, 1, "Buffer")
            
            $target = [TuiBuffer]::new(10, 5)
            $target.CopyFrom($source)
            
            $target.GetStringAt(0, 0, 6) | Should -Be "Source"
            $target.GetStringAt(0, 1, 6) | Should -Be "Buffer"
        }
        
        It "Should copy region from another buffer" {
            $source = [TuiBuffer]::new(10, 5)
            $source.WriteString(0, 0, "1234567890")
            $source.WriteString(0, 1, "ABCDEFGHIJ")
            
            $target = [TuiBuffer]::new(10, 5)
            $target.CopyFrom($source, 2, 0, 5, 2, 1, 1)
            
            # Should copy characters 2-6 from source to position 1,1 in target
            $target.GetStringAt(1, 1, 5) | Should -Be "34567"
            $target.GetStringAt(1, 2, 5) | Should -Be "CDEFG"
        }
    }
    
    Context "When handling dirty state" {
        It "Should track dirty cells" {
            $buffer = [TuiBuffer]::new(10, 5)
            
            $buffer.HasDirtyCells() | Should -Be $false
            
            $buffer.WriteCharacter(3, 2, 'X')
            
            $buffer.HasDirtyCells() | Should -Be $true
            $buffer.Buffer[2][3].IsDirty | Should -Be $true
        }
        
        It "Should clear dirty flags" {
            $buffer = [TuiBuffer]::new(10, 5)
            $buffer.WriteString(0, 0, "Test")
            
            $buffer.HasDirtyCells() | Should -Be $true
            
            $buffer.ClearDirtyFlags()
            
            $buffer.HasDirtyCells() | Should -Be $false
            for ($x = 0; $x -lt 4; $x++) {
                $buffer.Buffer[0][$x].IsDirty | Should -Be $false
            }
        }
        
        It "Should get dirty regions" {
            $buffer = [TuiBuffer]::new(20, 10)
            $buffer.WriteString(5, 2, "Hello")
            $buffer.WriteString(10, 5, "World")
            
            $dirtyRegions = $buffer.GetDirtyRegions()
            
            $dirtyRegions.Count | Should -BeGreaterThan 0
            # Should contain regions covering the written text
        }
    }
}

Write-Host "TuiBuffer unit tests loaded" -ForegroundColor Green