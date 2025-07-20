# Simple test to load ALCARLazyGitScreen with minimal dependencies

Write-Host "Testing ALCARLazyGitScreen loading..." -ForegroundColor Cyan

try {
    # Load only essential dependencies first
    Write-Host "Loading dependencies..." -ForegroundColor Green
    
    # Core dependencies
    . "./Core/vt100.ps1"
    . "./Core/ILazyGitView.ps1"
    . "./Core/LazyGitRenderer.ps1"
    . "./Core/LazyGitLayout.ps1"
    . "./Core/LazyGitPanel.ps1"
    . "./Core/LazyGitFocusManager.ps1"
    
    # Base Screen class
    . "./Base/Screen.ps1"
    
    Write-Host "Dependencies loaded successfully" -ForegroundColor Green
    
    # Now try to load ALCARLazyGitScreen
    Write-Host "Loading ALCARLazyGitScreen..." -ForegroundColor Yellow
    . "./Screens/ALCARLazyGitScreen.ps1"
    
    Write-Host "✅ ALCARLazyGitScreen loaded successfully!" -ForegroundColor Green
    
    # Try to reference the class
    $type = [ALCARLazyGitScreen]
    Write-Host "✅ ALCARLazyGitScreen type found: $($type.Name)" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error loading ALCARLazyGitScreen:" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host "   Position: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Yellow
}