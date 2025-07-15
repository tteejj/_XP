#!/usr/bin/env pwsh
# Real focus debugging

# Add debug logging back to SimpleTaskDialog
$dialogContent = Get-Content "Components/ACO.025_SimpleTaskDialog.ps1" -Raw

# Add component creation debug
$textBoxContent = Get-Content "Components/ACO.003_TextBoxComponent.ps1" -Raw
$textBoxContent = $textBoxContent -replace '(\s+)(\$this\.Height = 3)', "`$1# Debug component creation`n`$1if (`$name -eq `"TitleBox`") {`n`$1    `$timestamp = Get-Date -Format `"HH:mm:ss.fff`"`n`$1    `"[`$timestamp] TextBoxComponent CREATED: `$name`" | Out-File `"/tmp/focus-debug.log`" -Append -Force`n`$1}`n`$1`$2"

$textBoxContent | Out-File "Components/ACO.003_TextBoxComponent.ps1" -Encoding UTF8

# Add focus debugging to SimpleTaskDialog OnEnter
$dialogContent = $dialogContent -replace '(\s+)(\[void\] OnEnter\(\) \{)', "`$1`$2`n`$1    `$timestamp = Get-Date -Format `"HH:mm:ss.fff`"`n`$1    `"[`$timestamp] SimpleTaskDialog.OnEnter() START`" | Out-File `"/tmp/focus-debug.log`" -Append -Force`n`$1    `"[`$timestamp] BEFORE base.OnEnter() - TitleBox.IsFocused: `$(`$this._titleBox.IsFocused)`" | Out-File `"/tmp/focus-debug.log`" -Append -Force"

$dialogContent = $dialogContent -replace '(\s+)(\(\[Screen\]\$this\)\.OnEnter\(\))', "`$1`$2`n`$1    `$timestamp = Get-Date -Format `"HH:mm:ss.fff`"`n`$1    `"[`$timestamp] AFTER base.OnEnter() - TitleBox.IsFocused: `$(`$this._titleBox.IsFocused)`" | Out-File `"/tmp/focus-debug.log`" -Append -Force`n`$1    `"[`$timestamp] GetFocusedChild: `$(`$this.GetFocusedChild().Name if `$this.GetFocusedChild() else `"null`")`" | Out-File `"/tmp/focus-debug.log`" -Append -Force"

$dialogContent = $dialogContent -replace '(\s+)(\$this\.RequestRedraw\(\))', "`$1`$2`n`$1    `$timestamp = Get-Date -Format `"HH:mm:ss.fff`"`n`$1    `"[`$timestamp] AFTER RequestRedraw() - TitleBox.IsFocused: `$(`$this._titleBox.IsFocused)`" | Out-File `"/tmp/focus-debug.log`" -Append -Force`n`$1    `"[`$timestamp] SimpleTaskDialog.OnEnter() END`" | Out-File `"/tmp/focus-debug.log`" -Append -Force"

$dialogContent | Out-File "Components/ACO.025_SimpleTaskDialog.ps1" -Encoding UTF8

Write-Host "Debug logging added. Run the app and check /tmp/focus-debug.log" -ForegroundColor Green
Write-Host "Then navigate to Task List -> press 'n' to create new task" -ForegroundColor Yellow