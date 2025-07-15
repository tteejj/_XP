# Test screen to verify framework functionality
class TestScreen : Screen {
    hidden $_panel
    hidden $_textBox
    hidden $_button
    hidden $_navService
    
    TestScreen([object]$serviceContainer) : base("TestScreen", $serviceContainer) {
        $this._navService = $serviceContainer.GetService("NavigationService")
    }
    
    [void] Initialize() {
        # Simple panel
        $this._panel = [Panel]::new("TestPanel")
        $this._panel.X = 10
        $this._panel.Y = 5
        $this._panel.Width = 40
        $this._panel.Height = 10
        $this._panel.Title = " Test "
        $this.AddChild($this._panel)
        
        # TextBox
        $this._textBox = [TextBoxComponent]::new("TestBox")
        $this._textBox.X = 2
        $this._textBox.Y = 2
        $this._textBox.Width = 30
        $this._textBox.Height = 1
        $this._textBox.IsFocusable = $true
        $this._textBox.TabIndex = 0
        $this._panel.AddChild($this._textBox)
        
        # Button  
        $this._button = [ButtonComponent]::new("TestButton")
        $this._button.Text = " Test "
        $this._button.X = 2
        $this._button.Y = 5
        $this._button.Width = 10
        $this._button.Height = 1
        $this._button.IsFocusable = $true
        $this._button.TabIndex = 1
        
        $currentScreen = $this
        $this._button.OnClick = {
            $logPath = Join-Path (Get-Location) "test-click.log"
            [System.IO.File]::AppendAllText($logPath, "Button clicked at $(Get-Date)`n")
            if ($currentScreen._navService.CanGoBack()) {
                $currentScreen._navService.GoBack()
            }
        }.GetNewClosure()
        
        $this._panel.AddChild($this._button)
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            if ($this._navService.CanGoBack()) {
                $this._navService.GoBack()
            }
            return $true
        }
        
        # Base handles Tab and routes to components
        return ([Screen]$this).HandleInput($keyInfo)
    }
}