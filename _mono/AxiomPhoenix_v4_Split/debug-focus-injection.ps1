#!/usr/bin/env pwsh

# This script will inject debug code into NewTaskScreen to capture what's happening in the real app

Write-Host "=== INJECTING FOCUS DEBUG CODE ===" -ForegroundColor Green

# Read the current NewTaskScreen
$screenContent = Get-Content "Screens/ASC.004_NewTaskScreen.ps1" -Raw

# Create a version with extensive debug logging
$debugVersion = $screenContent

# Add debug logging to OnEnter method 
$debugVersion = $debugVersion -replace '(\[void\] OnEnter\(\) \{)', @'
    [void] OnEnter() {
        Write-Host "DEBUG: NewTaskScreen.OnEnter() called" -ForegroundColor Red
        Write-Host "DEBUG: Container type: $($this.ServiceContainer.GetType().Name)" -ForegroundColor Red
        Write-Host "DEBUG: NavService: $($this._navService -ne $null)" -ForegroundColor Red  
        Write-Host "DEBUG: DataManager: $($this._dataManager -ne $null)" -ForegroundColor Red
'@

# Add debug logging to HandleInput method
$debugVersion = $debugVersion -replace '(\[bool\] HandleInput\(\[System\.ConsoleKeyInfo\]\$keyInfo\) \{)', @'
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        Write-Host "DEBUG: NewTaskScreen.HandleInput() called with key: $($keyInfo.Key)" -ForegroundColor Red
        $focused = $this.GetFocusedChild()
        $focusedName = if ($focused) { $focused.Name } else { "none" }
        Write-Host "DEBUG: Current focus: $focusedName" -ForegroundColor Red
'@

# Add debug logging to _SaveTask method
$debugVersion = $debugVersion -replace '(hidden \[void\] _SaveTask\(\) \{)', @'
    hidden [void] _SaveTask() {
        Write-Host "DEBUG: _SaveTask() called!" -ForegroundColor Red
        Write-Host "DEBUG: Title text: '$($this._titleBox.Text)'" -ForegroundColor Red
        Write-Host "DEBUG: NavigationService available: $($this._navService -ne $null)" -ForegroundColor Red
        Write-Host "DEBUG: DataManager available: $($this._dataManager -ne $null)" -ForegroundColor Red
'@

# Add debug to button OnClick setup
$debugVersion = $debugVersion -replace '(\$this\._saveButton\.OnClick = \{)', @'
        $this._saveButton.OnClick = {
            Write-Host "DEBUG: SaveButton OnClick closure executed!" -ForegroundColor Red
'@

# Write the debug version
$debugVersion | Out-File "Screens/ASC.004_NewTaskScreen_DEBUG.ps1" -Encoding UTF8

Write-Host "Created debug version: Screens/ASC.004_NewTaskScreen_DEBUG.ps1" -ForegroundColor Yellow

# Now create a test script that uses the actual Start.ps1 process
Write-Host "Creating test to use REAL running app..." -ForegroundColor Yellow

$testScript = @'
#!/usr/bin/env pwsh

# Replace the NewTaskScreen with debug version temporarily
Copy-Item "Screens/ASC.004_NewTaskScreen.ps1" "Screens/ASC.004_NewTaskScreen_BACKUP.ps1"
Copy-Item "Screens/ASC.004_NewTaskScreen_DEBUG.ps1" "Screens/ASC.004_NewTaskScreen.ps1"

Write-Host "Starting app with debug NewTaskScreen..." -ForegroundColor Green

# Start the application normally  
pwsh -File Start.ps1 -Debug

# Restore original
Copy-Item "Screens/ASC.004_NewTaskScreen_BACKUP.ps1" "Screens/ASC.004_NewTaskScreen.ps1"
Remove-Item "Screens/ASC.004_NewTaskScreen_BACKUP.ps1"
'@

$testScript | Out-File "test-debug-app.ps1" -Encoding UTF8

Write-Host "Run: pwsh -File test-debug-app.ps1" -ForegroundColor Green
Write-Host "Then navigate to New Task screen in the app to see debug output" -ForegroundColor Yellow