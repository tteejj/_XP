# ==============================================================================
# Axiom-Phoenix v4.0 - Button Component Unit Tests
# Testing button component functionality and interaction
# ==============================================================================

# Import the framework
$scriptDir = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $scriptDir "Base/ABC.002_TuiCell.ps1")
. (Join-Path $scriptDir "Base/ABC.003_TuiBuffer.ps1")
. (Join-Path $scriptDir "Base/ABC.004_UIElement.ps1")
. (Join-Path $scriptDir "Components/ACO.002_ButtonComponent.ps1")

Describe "Button Component Tests" {
    Context "When creating a button" {
        It "Should initialize with default values" {
            $button = [ButtonComponent]::new("TestButton")
            
            $button.Name | Should -Be "TestButton"
            $button.Text | Should -Be ""
            $button.IsFocusable | Should -Be $true
            $button.Width | Should -BeGreaterThan 0
            $button.Height | Should -BeGreaterThan 0
        }
        
        It "Should initialize with specified text" {
            $button = [ButtonComponent]::new("TestButton")
            $button.Text = "Click Me"
            
            $button.Text | Should -Be "Click Me"
        }
        
        It "Should have reasonable default dimensions" {
            $button = [ButtonComponent]::new("TestButton")
            $button.Text = "OK"
            
            # Button should be wide enough for text plus padding
            $button.Width | Should -BeGreaterOrEqual ($button.Text.Length + 2)
            $button.Height | Should -BeGreaterOrEqual 3
        }
    }
    
    Context "When setting button properties" {
        BeforeEach {
            $button = [ButtonComponent]::new("TestButton")
            $buffer = [TuiBuffer]::new(50, 20)
            $button.Buffer = $buffer
        }
        
        It "Should update text property" {
            $button.Text = "New Text"
            $button.Text | Should -Be "New Text"
        }
        
        It "Should handle empty text" {
            $button.Text = ""
            $button.Text | Should -Be ""
        }
        
        It "Should handle long text" {
            $longText = "This is a very long button text that might exceed normal width"
            $button.Text = $longText
            $button.Text | Should -Be $longText
        }
        
        It "Should update enabled state" {
            $button.IsEnabled = $false
            $button.IsEnabled | Should -Be $false
            
            $button.IsEnabled = $true
            $button.IsEnabled | Should -Be $true
        }
    }
    
    Context "When handling button focus" {
        BeforeEach {
            $button = [ButtonComponent]::new("TestButton")
            $button.Text = "Test Button"
            $buffer = [TuiBuffer]::new(50, 20)
            $button.Buffer = $buffer
        }
        
        It "Should be focusable by default" {
            $button.IsFocusable | Should -Be $true
        }
        
        It "Should handle focus events" {
            $button.HasFocus = $false
            $button.OnFocus()
            # Focus state should be handled appropriately
            # Specific implementation depends on the actual component
        }
        
        It "Should handle blur events" {
            $button.HasFocus = $true
            $button.OnBlur()
            # Blur state should be handled appropriately
        }
        
        It "Should not be focusable when disabled" {
            $button.IsEnabled = $false
            # Disabled buttons typically shouldn't be focusable
            # This depends on implementation
        }
    }
    
    Context "When handling button input" {
        BeforeEach {
            $button = [ButtonComponent]::new("TestButton")
            $button.Text = "Click Me"
            $button.IsEnabled = $true
            $button.HasFocus = $true
        }
        
        It "Should handle spacebar press as click" {
            $clickHandled = $false
            $button.OnClick = { $script:clickHandled = $true }
            
            $spaceKey = [System.ConsoleKeyInfo]::new(' ', [ConsoleKey]::Spacebar, $false, $false, $false)
            $result = $button.HandleInput($spaceKey)
            
            $result | Should -Be $true
            $clickHandled | Should -Be $true
        }
        
        It "Should handle Enter key as click" {
            $clickHandled = $false
            $button.OnClick = { $script:clickHandled = $true }
            
            $enterKey = [System.ConsoleKeyInfo]::new([char]13, [ConsoleKey]::Enter, $false, $false, $false)
            $result = $button.HandleInput($enterKey)
            
            $result | Should -Be $true
            $clickHandled | Should -Be $true
        }
        
        It "Should not handle clicks when disabled" {
            $button.IsEnabled = $false
            $clickHandled = $false
            $button.OnClick = { $script:clickHandled = $true }
            
            $spaceKey = [System.ConsoleKeyInfo]::new(' ', [ConsoleKey]::Spacebar, $false, $false, $false)
            $result = $button.HandleInput($spaceKey)
            
            $clickHandled | Should -Be $false
        }
        
        It "Should not handle clicks when not focused" {
            $button.HasFocus = $false
            $clickHandled = $false
            $button.OnClick = { $script:clickHandled = $true }
            
            $spaceKey = [System.ConsoleKeyInfo]::new(' ', [ConsoleKey]::Spacebar, $false, $false, $false)
            $result = $button.HandleInput($spaceKey)
            
            $clickHandled | Should -Be $false
        }
        
        It "Should ignore other keys" {
            $button.OnClick = { throw "Should not be called" }
            
            $letterKey = [System.ConsoleKeyInfo]::new('a', [ConsoleKey]::A, $false, $false, $false)
            $result = $button.HandleInput($letterKey)
            
            $result | Should -Be $false
        }
    }
    
    Context "When rendering button" {
        BeforeEach {
            $button = [ButtonComponent]::new("TestButton")
            $button.Text = "OK"
            $button.Width = 10
            $button.Height = 3
            $button.X = 5
            $button.Y = 2
            $buffer = [TuiBuffer]::new(50, 20)
            $button.Buffer = $buffer
        }
        
        It "Should render button text" {
            $button.OnRender()
            
            # Check that button text appears in buffer
            $renderedText = $buffer.GetStringAt($button.X, $button.Y + 1, $button.Text.Length)
            $renderedText | Should -Match $button.Text
        }
        
        It "Should render button border" {
            $button.OnRender()
            
            # Check for border characters (implementation specific)
            # This test depends on the actual border rendering implementation
            $topBorder = $buffer.GetCharacterAt($button.X, $button.Y)
            $topBorder | Should -Not -Be ' '  # Should have some border character
        }
        
        It "Should render differently when focused" {
            # Test unfocused state
            $button.HasFocus = $false
            $button.OnRender()
            $unfocusedContent = $buffer.GetStringAt($button.X, $button.Y, $button.Width)
            
            # Clear and test focused state
            $button.Buffer.Clear()
            $button.HasFocus = $true
            $button.OnRender()
            $focusedContent = $buffer.GetStringAt($button.X, $button.Y, $button.Width)
            
            # Focused and unfocused should render differently
            $focusedContent | Should -Not -Be $unfocusedContent
        }
        
        It "Should render differently when disabled" {
            # Test enabled state
            $button.IsEnabled = $true
            $button.OnRender()
            $enabledContent = $buffer.GetStringAt($button.X, $button.Y + 1, $button.Text.Length)
            
            # Clear and test disabled state
            $button.Buffer.Clear()
            $button.IsEnabled = $false
            $button.OnRender()
            $disabledContent = $buffer.GetStringAt($button.X, $button.Y + 1, $button.Text.Length)
            
            # Enabled and disabled should render differently (typically different colors)
            # This test might need adjustment based on implementation
        }
        
        It "Should handle empty text rendering" {
            $button.Text = ""
            $button.OnRender()
            
            # Should not crash and should still render border
            $topBorder = $buffer.GetCharacterAt($button.X, $button.Y)
            $topBorder | Should -Not -Be ' '
        }
        
        It "Should center text in button" {
            $button.Text = "Hi"
            $button.Width = 10
            $button.OnRender()
            
            # Text should be centered (exact position depends on implementation)
            $textStartX = $button.X + (($button.Width - $button.Text.Length) / 2)
            $renderedChar = $buffer.GetCharacterAt([math]::Floor($textStartX), $button.Y + 1)
            $renderedChar | Should -Be 'H'
        }
    }
    
    Context "When testing button sizing" {
        It "Should auto-size to fit text" {
            $button = [ButtonComponent]::new("TestButton")
            $button.Text = "Short"
            
            $shortWidth = $button.Width
            
            $button.Text = "Much Longer Text"
            # If auto-sizing is implemented, width should increase
            # This depends on the actual implementation
        }
        
        It "Should respect minimum size" {
            $button = [ButtonComponent]::new("TestButton")
            $button.Text = "X"
            
            # Even with short text, button should have minimum usable size
            $button.Width | Should -BeGreaterOrEqual 5
            $button.Height | Should -BeGreaterOrEqual 3
        }
        
        It "Should handle text overflow gracefully" {
            $button = [ButtonComponent]::new("TestButton")
            $button.Width = 8
            $button.Text = "Very Long Text That Exceeds Width"
            
            # Should not crash when rendering
            $buffer = [TuiBuffer]::new(50, 20)
            $button.Buffer = $buffer
            { $button.OnRender() } | Should -Not -Throw
        }
    }
    
    Context "When testing button theming" {
        BeforeEach {
            $button = [ButtonComponent]::new("TestButton")
            $button.Text = "Themed"
            $buffer = [TuiBuffer]::new(50, 20)
            $button.Buffer = $buffer
        }
        
        It "Should apply theme colors" {
            # This test depends on theme integration
            # Mock or setup theme if needed
            $button.OnRender()
            
            # Check that appropriate colors are used
            # Implementation specific
        }
        
        It "Should support custom colors" {
            # If custom color support is implemented
            $button.ForegroundColor = [ConsoleColor]::Red
            $button.BackgroundColor = [ConsoleColor]::Blue
            
            $button.OnRender()
            
            # Verify custom colors are applied
            # Implementation specific
        }
    }
    
    Context "When testing button accessibility" {
        BeforeEach {
            $button = [ButtonComponent]::new("TestButton")
            $button.Text = "Accessible Button"
        }
        
        It "Should support keyboard navigation" {
            $button.IsFocusable | Should -Be $true
        }
        
        It "Should provide accessible text" {
            $button.GetAccessibleText() | Should -Be "Accessible Button"
        }
        
        It "Should indicate button role" {
            # If role/type indication is implemented
            $button.GetRole() | Should -Be "Button"
        }
    }
    
    Context "When testing button performance" {
        It "Should render efficiently" {
            $button = [ButtonComponent]::new("PerformanceButton")
            $button.Text = "Performance Test"
            $buffer = [TuiBuffer]::new(100, 30)
            $button.Buffer = $buffer
            
            $iterations = 1000
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $button.OnRender()
            }
            
            $stopwatch.Stop()
            
            # Should render 1000 times in under 100ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 100
            
            Write-Host "Button render performance: $($stopwatch.ElapsedMilliseconds)ms for $iterations renders" -ForegroundColor Cyan
        }
        
        It "Should handle input efficiently" {
            $button = [ButtonComponent]::new("InputButton")
            $button.IsEnabled = $true
            $button.HasFocus = $true
            
            $spaceKey = [System.ConsoleKeyInfo]::new(' ', [ConsoleKey]::Spacebar, $false, $false, $false)
            $iterations = 10000
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $button.HandleInput($spaceKey)
            }
            
            $stopwatch.Stop()
            
            # Should handle 10000 inputs in under 50ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 50
            
            Write-Host "Button input performance: $($stopwatch.ElapsedMilliseconds)ms for $iterations inputs" -ForegroundColor Cyan
        }
    }
}

Write-Host "Button component unit tests loaded" -ForegroundColor Green