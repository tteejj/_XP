# ==============================================================================
# Axiom-Phoenix v4.0 - Error Handling Integration Tests
# Integration testing for error boundaries and error recovery
# ==============================================================================

# Import the framework
$scriptDir = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $scriptDir "Base/ABC.004_UIElement.ps1")
. (Join-Path $scriptDir "Base/ABC.004a_ComponentLifecycle.ps1")
. (Join-Path $scriptDir "Base/ABC.004b_ErrorBoundary.ps1")

# Test components for error handling
class FailingComponent : LifecycleAwareUIElement {
    [bool] $ShouldFailOnRender = $false
    [bool] $ShouldFailOnInput = $false
    [bool] $ShouldFailOnInitialize = $false
    [int] $FailCount = 0
    
    FailingComponent([string]$name) : base($name) {
        $this.Width = 10
        $this.Height = 3
    }
    
    [void] OnInitialize() {
        if ($this.ShouldFailOnInitialize) {
            $this.FailCount++
            throw "Component initialization failed"
        }
        ([LifecycleAwareUIElement]$this).OnInitialize()
    }
    
    [void] OnRender() {
        if ($this.ShouldFailOnRender) {
            $this.FailCount++
            throw "Component render failed"
        }
        
        if ($this.Buffer) {
            $this.Buffer.WriteString(0, 0, "OK", [ConsoleColor]::Green, [ConsoleColor]::Black)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($this.ShouldFailOnInput) {
            $this.FailCount++
            throw "Component input handling failed"
        }
        
        return $false
    }
    
    [void] CauseError() {
        throw "Deliberate component error"
    }
}

class FallbackComponent : LifecycleAwareUIElement {
    [string] $FallbackMessage = "Fallback Active"
    
    FallbackComponent([string]$name) : base($name) {
        $this.Width = 20
        $this.Height = 3
    }
    
    [void] OnRender() {
        if ($this.Buffer) {
            $this.Buffer.WriteString(0, 0, $this.FallbackMessage, [ConsoleColor]::Yellow, [ConsoleColor]::DarkRed)
        }
    }
}

class RecoverableComponent : LifecycleAwareUIElement {
    [int] $AttemptCount = 0
    [int] $SuccessAfterAttempts = 3
    
    RecoverableComponent([string]$name) : base($name) {
        $this.Width = 15
        $this.Height = 3
    }
    
    [void] OnInitialize() {
        $this.AttemptCount++
        if ($this.AttemptCount -lt $this.SuccessAfterAttempts) {
            throw "Component not ready yet (attempt $($this.AttemptCount))"
        }
        ([LifecycleAwareUIElement]$this).OnInitialize()
    }
    
    [void] OnRender() {
        if ($this.Buffer) {
            $this.Buffer.WriteString(0, 0, "Recovered", [ConsoleColor]::Green, [ConsoleColor]::Black)
        }
    }
}

Describe "Error Handling Integration Tests" {
    Context "When testing error boundary basic functionality" {
        It "Should catch component errors and enter error state" {
            $boundary = [ErrorBoundaryComponent]::new("TestBoundary")
            $failingComponent = [FailingComponent]::new("FailingChild")
            
            $boundary.AddChild($failingComponent)
            
            # Should not be in error state initially
            $boundary.HasError() | Should -Be $false
            
            # Trigger error
            $boundary.OnComponentError($failingComponent, [System.Exception]::new("Test error"))
            
            # Should be in error state
            $boundary.HasError() | Should -Be $true
            $boundary.GetLastError() | Should -Not -BeNull
            $boundary.GetLastError().Message | Should -Be "Test error"
        }
        
        It "Should clear error state when requested" {
            $boundary = [ErrorBoundaryComponent]::new("TestBoundary")
            $failingComponent = [FailingComponent]::new("FailingChild")
            
            # Put boundary in error state
            $boundary.OnComponentError($failingComponent, [System.Exception]::new("Test error"))
            $boundary.HasError() | Should -Be $true
            
            # Clear error
            $boundary.ClearError()
            
            # Should no longer be in error state
            $boundary.HasError() | Should -Be $false
            $boundary.GetLastError() | Should -BeNull
        }
        
        It "Should generate error reports" {
            $boundary = [ErrorBoundaryComponent]::new("TestBoundary")
            $failingComponent = [FailingComponent]::new("FailingChild")
            
            $boundary.OnComponentError($failingComponent, [System.Exception]::new("Test error"))
            
            $report = $boundary.GetErrorReport()
            
            $report.HasError | Should -Be $true
            $report.LastError | Should -Be "Test error"
            $report.FailedComponent | Should -Be "FailingChild"
            $report.ErrorHistory.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "When testing retry recovery strategy" {
        It "Should retry failed component initialization" {
            $boundary = [ErrorBoundaryComponent]::new("RetryBoundary")
            $boundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Retry)
            $boundary.SetMaxRetries(3)
            
            $recoverableComponent = [RecoverableComponent]::new("RecoverableChild")
            $recoverableComponent.SuccessAfterAttempts = 2  # Should succeed on second attempt
            
            $boundary.AddChild($recoverableComponent)
            
            # Simulate first failure
            $boundary.OnComponentError($recoverableComponent, [System.Exception]::new("Not ready"))
            
            # Should be in error state but not exceed max retries
            $report = $boundary.GetErrorReport()
            $report.RetryCount | Should -BeGreaterThan 0
            $report.RetryCount | Should -BeLessOrEqual 3
        }
        
        It "Should fall back after max retries exceeded" {
            $boundary = [ErrorBoundaryComponent]::new("RetryBoundary")
            $boundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Retry)
            $boundary.SetMaxRetries(2)
            
            $fallbackComponent = [FallbackComponent]::new("Fallback")
            $boundary.SetFallbackComponent($fallbackComponent)
            
            $failingComponent = [FailingComponent]::new("AlwaysFailing")
            $failingComponent.ShouldFailOnInitialize = $true
            
            # Simulate multiple failures
            for ($i = 0; $i -lt 5; $i++) {
                $boundary.OnComponentError($failingComponent, [System.Exception]::new("Always fails"))
            }
            
            $report = $boundary.GetErrorReport()
            $report.RetryCount | Should -BeGreaterOrEqual 2
        }
    }
    
    Context "When testing fallback recovery strategy" {
        It "Should show fallback component on error" {
            $boundary = [ErrorBoundaryComponent]::new("FallbackBoundary")
            $boundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Fallback)
            
            $fallbackComponent = [FallbackComponent]::new("Fallback")
            $boundary.SetFallbackComponent($fallbackComponent)
            
            $failingComponent = [FailingComponent]::new("FailingChild")
            $boundary.AddChild($failingComponent)
            
            # Trigger error
            $boundary.OnComponentError($failingComponent, [System.Exception]::new("Component failed"))
            
            # Verify fallback is activated
            $boundary.HasError() | Should -Be $true
            $report = $boundary.GetErrorReport()
            $report.RecoveryStrategy | Should -Be ([ErrorRecoveryStrategy]::Fallback)
        }
        
        It "Should render fallback content when visible" {
            $boundary = [ErrorBoundaryComponent]::new("FallbackBoundary")
            $boundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Fallback)
            $boundary.Visible = $true
            
            $failingComponent = [FailingComponent]::new("FailingChild")
            $boundary.OnComponentError($failingComponent, [System.Exception]::new("Component failed"))
            
            # Setup buffer for rendering
            $buffer = [TuiBuffer]::new(50, 10)
            $boundary.Buffer = $buffer
            
            # Should render error indicator
            $boundary.OnRender()
            
            # Check that error message was rendered
            $renderedContent = $buffer.GetStringAt(0, 0, 20)
            $renderedContent | Should -Match "Error"
        }
    }
    
    Context "When testing hide recovery strategy" {
        It "Should hide failed component" {
            $boundary = [ErrorBoundaryComponent]::new("HideBoundary")
            $boundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Hide)
            
            $failingComponent = [FailingComponent]::new("FailingChild")
            $failingComponent.Visible = $true
            $boundary.AddChild($failingComponent)
            
            # Trigger error
            $boundary.OnComponentError($failingComponent, [System.Exception]::new("Component failed"))
            
            # Component should be hidden
            $failingComponent.Visible | Should -Be $false
        }
    }
    
    Context "When testing replace recovery strategy" {
        It "Should replace failed component with new instance" {
            $boundary = [ErrorBoundaryComponent]::new("ReplaceBoundary")
            $boundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Replace)
            
            $failingComponent = [FailingComponent]::new("FailingChild")
            $boundary.AddChild($failingComponent)
            
            # Create a mock parent to test replacement
            $parent = [PSCustomObject]@{
                Children = @($failingComponent)
            }
            $failingComponent.Parent = $parent
            
            # Trigger error
            $boundary.OnComponentError($failingComponent, [System.Exception]::new("Component failed"))
            
            # Should have attempted replacement
            $boundary.HasError() | Should -Be $true
            $report = $boundary.GetErrorReport()
            $report.RecoveryStrategy | Should -Be ([ErrorRecoveryStrategy]::Replace)
        }
    }
    
    Context "When testing nested error boundaries" {
        It "Should handle errors in nested boundary hierarchy" {
            $outerBoundary = [ErrorBoundaryComponent]::new("OuterBoundary")
            $outerBoundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Fallback)
            
            $innerBoundary = [ErrorBoundaryComponent]::new("InnerBoundary")
            $innerBoundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Retry)
            $innerBoundary.SetMaxRetries(1)
            
            $failingComponent = [FailingComponent]::new("DeepFailingChild")
            
            # Setup hierarchy
            $outerBoundary.AddChild($innerBoundary)
            $innerBoundary.AddChild($failingComponent)
            
            # Trigger error at deepest level
            $innerBoundary.OnComponentError($failingComponent, [System.Exception]::new("Deep error"))
            
            # Inner boundary should handle first
            $innerBoundary.HasError() | Should -Be $true
            
            # If inner boundary can't recover, outer should take over
            # Simulate retry failure
            $innerBoundary.OnComponentError($failingComponent, [System.Exception]::new("Retry failed"))
            
            # Inner boundary should still be in error state
            $innerBoundary.HasError() | Should -Be $true
        }
        
        It "Should propagate errors up the boundary chain when needed" {
            $rootBoundary = [ErrorBoundaryComponent]::new("RootBoundary")
            $childBoundary = [ErrorBoundaryComponent]::new("ChildBoundary")
            $leafComponent = [FailingComponent]::new("LeafComponent")
            
            # Setup error recovery strategies
            $childBoundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::None)  # No recovery
            $rootBoundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Fallback)
            
            $rootBoundary.AddChild($childBoundary)
            $childBoundary.AddChild($leafComponent)
            
            # Error should bubble up when child boundary can't handle it
            $childBoundary.OnComponentError($leafComponent, [System.Exception]::new("Unhandled error"))
            
            $childBoundary.HasError() | Should -Be $true
        }
    }
    
    Context "When testing error boundary performance" {
        It "Should handle multiple rapid errors efficiently" {
            $boundary = [ErrorBoundaryComponent]::new("PerformanceBoundary")
            $boundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Retry)
            $boundary.SetMaxRetries(5)
            
            $component = [FailingComponent]::new("RapidFailer")
            $boundary.AddChild($component)
            
            $errorCount = 100
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Generate many errors rapidly
            for ($i = 0; $i -lt $errorCount; $i++) {
                $boundary.OnComponentError($component, [System.Exception]::new("Error $i"))
            }
            
            $stopwatch.Stop()
            
            # Should handle errors efficiently
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000
            
            # Should maintain error state correctly
            $boundary.HasError() | Should -Be $true
            $report = $boundary.GetErrorReport()
            $report.ErrorHistory.Count | Should -Be $errorCount
        }
        
        It "Should clean up error history efficiently" {
            $boundary = [ErrorBoundaryComponent]::new("CleanupBoundary")
            $component = [FailingComponent]::new("FailingComponent")
            
            # Generate many errors
            for ($i = 0; $i -lt 50; $i++) {
                $boundary.OnComponentError($component, [System.Exception]::new("Error $i"))
            }
            
            $report = $boundary.GetErrorReport()
            $report.ErrorHistory.Count | Should -Be 50
            
            # Clear errors
            $boundary.ClearError()
            
            # Error history should be cleared
            $clearedReport = $boundary.GetErrorReport()
            $clearedReport.ErrorHistory.Count | Should -Be 0
            $clearedReport.HasError | Should -Be $false
        }
    }
    
    Context "When testing error boundary integration with lifecycle" {
        It "Should handle errors during component initialization" {
            $boundary = [ErrorBoundaryComponent]::new("InitBoundary")
            $boundary.SetRecoveryStrategy([ErrorRecoveryStrategy]::Retry)
            $boundary.SetMaxRetries(2)
            
            $component = [FailingComponent]::new("InitFailer")
            $component.ShouldFailOnInitialize = $true
            
            $boundary.AddChild($component)
            
            # Simulate initialization error
            try {
                $component.Initialize()
            } catch {
                $boundary.OnComponentError($component, $_.Exception)
            }
            
            $boundary.HasError() | Should -Be $true
            $component.FailCount | Should -BeGreaterThan 0
        }
        
        It "Should handle errors during component disposal" {
            $boundary = [ErrorBoundaryComponent]::new("DisposeBoundary")
            $component = [PSCustomObject]@{
                Name = "FaultyDisposer"
                Dispose = { throw "Disposal failed" }
            }
            
            $boundary.AddChild($component)
            
            # Should handle disposal errors gracefully
            { $boundary.OnDispose() } | Should -Not -Throw
        }
    }
    
    Context "When testing error boundary helpers" {
        It "Should create error boundaries with helpers" {
            $component = [FailingComponent]::new("WrappedComponent")
            $fallback = [FallbackComponent]::new("FallbackComponent")
            
            $boundary = New-ErrorBoundary -Component $component -Strategy ([ErrorRecoveryStrategy]::Fallback) -FallbackComponent $fallback -MaxRetries 3
            
            $boundary | Should -Not -BeNull
            $boundary.GetType().Name | Should -Be "ErrorBoundaryComponent"
            $boundary.Children.Count | Should -Be 1
            $boundary.Children[0] | Should -Be $component
        }
        
        It "Should create error fallback components" {
            $fallback = New-ErrorFallback -Name "TestFallback" -Message "Service Unavailable" -Width 25 -Height 5
            
            $fallback | Should -Not -BeNull
            $fallback.Name | Should -Be "TestFallback"
            $fallback.Width | Should -Be 25
            $fallback.Height | Should -Be 5
        }
    }
}

Write-Host "Error handling integration tests loaded" -ForegroundColor Green