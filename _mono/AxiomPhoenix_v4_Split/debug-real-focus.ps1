#!/usr/bin/env pwsh

# This will inject debug code into SimpleTaskDialog to see what's happening in the REAL app

Write-Host "=== INJECTING DEBUG INTO REAL APP ===" -ForegroundColor Red

# Read SimpleTaskDialog
$dialogContent = Get-Content "Components/ACO.025_SimpleTaskDialog.ps1" -Raw

# Create backup
$dialogContent | Out-File "Components/ACO.025_SimpleTaskDialog_BACKUP.ps1" -Encoding UTF8

# Add extensive debug logging to OnEnter
$debugDialog = $dialogContent -replace '(\[void\] OnEnter\(\) \{)', @'
    [void] OnEnter() {
        Write-Host "=== REAL APP DEBUG: SimpleTaskDialog.OnEnter() START ===" -ForegroundColor Red
        Write-Host "DEBUG: Dialog Width=$($this.Width) Height=$($this.Height)" -ForegroundColor Red
        Write-Host "DEBUG: ServiceContainer exists: $($this.ServiceContainer -ne $null)" -ForegroundColor Red
        
        # Check components before base OnEnter
        Write-Host "DEBUG: Components before base.OnEnter():" -ForegroundColor Red
        Write-Host "  TitleBox: IsFocusable=$($this._titleBox.IsFocusable) Visible=$($this._titleBox.Visible) Enabled=$($this._titleBox.Enabled)" -ForegroundColor Red
        Write-Host "  SaveButton: IsFocusable=$($this._saveButton.IsFocusable) Visible=$($this._saveButton.Visible) Enabled=$($this._saveButton.Enabled)" -ForegroundColor Red
        
        # Check focusable collection before base OnEnter
        $focusableBefore = $this.GetFocusableChildren()
        Write-Host "DEBUG: Focusable components before base.OnEnter(): $($focusableBefore.Count)" -ForegroundColor Red
        foreach ($comp in $focusableBefore) {
            Write-Host "  - $($comp.Name) (TabIndex: $($comp.TabIndex))" -ForegroundColor Red
        }
'@

# Add debug after base OnEnter call
$debugDialog = $debugDialog -replace '(\(\[Screen\]\$this\)\.OnEnter\(\))', @'
        ([Screen]$this).OnEnter()
        
        Write-Host "DEBUG: After base.OnEnter() called" -ForegroundColor Red
        $focusedAfter = $this.GetFocusedChild()
        if ($focusedAfter) {
            Write-Host "DEBUG: Focus after base.OnEnter(): $($focusedAfter.Name)" -ForegroundColor Red
        } else {
            Write-Host "DEBUG: NO FOCUS after base.OnEnter()!" -ForegroundColor Red
        }
        
        # Check focusable collection after base OnEnter
        $focusableAfter = $this.GetFocusableChildren()
        Write-Host "DEBUG: Focusable components after base.OnEnter(): $($focusableAfter.Count)" -ForegroundColor Red
        
        # Try manual focus as fallback
        if (-not $focusedAfter -and $this._titleBox) {
            Write-Host "DEBUG: Attempting manual focus on TitleBox as fallback" -ForegroundColor Red
            $manualResult = $this.SetChildFocus($this._titleBox)
            Write-Host "DEBUG: Manual focus result: $manualResult" -ForegroundColor Red
            $finalFocus = $this.GetFocusedChild()
            if ($finalFocus) {
                Write-Host "DEBUG: Final focus after manual: $($finalFocus.Name)" -ForegroundColor Red
            } else {
                Write-Host "DEBUG: Manual focus FAILED!" -ForegroundColor Red
            }
        }
        
        Write-Host "=== REAL APP DEBUG: SimpleTaskDialog.OnEnter() END ===" -ForegroundColor Red
'@

# Add debug to HandleInput
$debugDialog = $debugDialog -replace '(\[bool\] HandleInput\(\[System\.ConsoleKeyInfo\]\$keyInfo\) \{)', @'
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        Write-Host "DEBUG: SimpleTaskDialog.HandleInput() called with key: $($keyInfo.Key)" -ForegroundColor Red
        $currentFocus = $this.GetFocusedChild()
        if ($currentFocus) {
            Write-Host "DEBUG: Current focus in HandleInput: $($currentFocus.Name)" -ForegroundColor Red
        } else {
            Write-Host "DEBUG: NO FOCUS in HandleInput!" -ForegroundColor Red
        }
'@

# Add debug to button OnClick
$debugDialog = $debugDialog -replace '(\$this\._saveButton\.OnClick = \{ \$screenRef\._SaveTask\(\) \})', @'
        $this._saveButton.OnClick = { 
            Write-Host "DEBUG: SaveButton OnClick triggered!" -ForegroundColor Red
            try {
                $screenRef._SaveTask()
                Write-Host "DEBUG: _SaveTask() completed successfully" -ForegroundColor Red
            } catch {
                Write-Host "DEBUG: _SaveTask() ERROR: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "DEBUG: _SaveTask() Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
            }
        }.GetNewClosure()
'@

# Add debug to _SaveTask method
$debugDialog = $debugDialog -replace '(hidden \[void\] _SaveTask\(\) \{)', @'
    hidden [void] _SaveTask() {
        Write-Host "DEBUG: _SaveTask() method called" -ForegroundColor Red
        Write-Host "DEBUG: Title text: '$($this._titleBox.Text)'" -ForegroundColor Red
        Write-Host "DEBUG: ServiceContainer exists: $($this.ServiceContainer -ne $null)" -ForegroundColor Red
'@

# Write the debug version
$debugDialog | Out-File "Components/ACO.025_SimpleTaskDialog.ps1" -Encoding UTF8

Write-Host "Debug version created. Now start the app with:" -ForegroundColor Green
Write-Host "  pwsh -File Start.ps1" -ForegroundColor Yellow
Write-Host "Then:" -ForegroundColor Yellow  
Write-Host "  1. Select option 2 (Task List)" -ForegroundColor Yellow
Write-Host "  2. Press 'n' to create new task" -ForegroundColor Yellow
Write-Host "  3. Watch the red debug output" -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow
Write-Host "To restore original after testing:" -ForegroundColor Green
Write-Host "  Copy-Item Components/ACO.025_SimpleTaskDialog_BACKUP.ps1 Components/ACO.025_SimpleTaskDialog.ps1" -ForegroundColor Yellow