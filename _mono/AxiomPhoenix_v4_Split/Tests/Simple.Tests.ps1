# ==============================================================================
# Simple Test to Validate Framework Loading
# ==============================================================================

# Import the framework using same pattern as working TuiCell test
$testRoot = $PSScriptRoot
if (-not $testRoot) { 
    $testRoot = Split-Path $MyInvocation.MyCommand.Path 
}
$frameworkRoot = Split-Path $testRoot -Parent

. (Join-Path $frameworkRoot "Base/ABC.001_TuiAnsiHelper.ps1")
. (Join-Path $frameworkRoot "Base/ABC.002_TuiCell.ps1")
. (Join-Path $frameworkRoot "Base/ABC.003_TuiBuffer.ps1")

Describe "Simple Framework Loading Tests" {
    Context "When testing basic class creation" {
        It "Should create TuiCell" {
            $cell = [TuiCell]::new()
            $cell | Should -Not -BeNull
            $cell.Char | Should -Be ' '
        }
        
        It "Should create TuiBuffer" {
            $buffer = [TuiBuffer]::new(10, 5)
            $buffer | Should -Not -BeNull
            $buffer.Width | Should -Be 10
            $buffer.Height | Should -Be 5
        }
        
        It "Should interact between classes" {
            $buffer = [TuiBuffer]::new(5, 3)
            $cell = [TuiCell]::new([char]'X')
            
            $buffer.SetCell(1, 1, $cell)
            $retrievedCell = $buffer.GetCell(1, 1)
            
            $retrievedCell.Char | Should -Be 'X'
        }
    }
}

Write-Host "Simple framework tests loaded" -ForegroundColor Green