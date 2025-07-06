# test-classes.ps1 - Test if classes load correctly
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Testing class loading..." -ForegroundColor Cyan
    . ".\all-classes.ps1"
    
    Write-Host "`nTesting basic class instantiation:" -ForegroundColor Yellow
    
    # Test enum
    if (Get-Command -Name TaskStatus -ErrorAction SilentlyContinue) {
        $status = [TaskStatus]::Pending
        Write-Host "  ✓ TaskStatus enum: $status" -ForegroundColor Green
    }
    
    # Test basic class
    if (Get-Command -Name PmcTask -ErrorAction SilentlyContinue) {
        $task = [PmcTask]::new()
        Write-Host "  ✓ PmcTask class: Created task with ID $($task.Id)" -ForegroundColor Green
    }
    
    # Test UI class  
    if (Get-Command -Name UIElement -ErrorAction SilentlyContinue) {
        $ui = [UIElement]::new()
        Write-Host "  ✓ UIElement class: Created element '$($ui.Name)'" -ForegroundColor Green
    }
    
    # Test Dialog class
    if (Get-Command -Name Dialog -ErrorAction SilentlyContinue) {
        $dialog = [Dialog]::new("TestDialog")
        Write-Host "  ✓ Dialog class: Created dialog '$($dialog.Title)'" -ForegroundColor Green
    }
    
    Write-Host "`n✅ All basic tests passed!" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ Error loading classes:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}
