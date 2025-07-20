# Test KanbanScreen creation without UI
# Load only the necessary components

Write-Host "Loading classes..." -ForegroundColor Green

# Load VT class
. ./Core/vt100.ps1

# Load base classes
. ./Base/Component.ps1
. ./Base/Screen.ps1

# Load services
. ./Services/UnifiedDataService.ps1

# Load components
. ./Components/KanbanColumn.ps1

# Load KanbanScreen
. ./Screens/KanbanScreen.ps1

Write-Host "Classes loaded. Creating KanbanScreen..." -ForegroundColor Green

try {
    $kanbanScreen = [KanbanScreen]::new()
    Write-Host "KanbanScreen created successfully!" -ForegroundColor Green
    
    Write-Host "Testing RenderContent..." -ForegroundColor Yellow
    $content = $kanbanScreen.RenderContent()
    
    if ($content) {
        Write-Host "RenderContent returned content (length: $($content.Length))" -ForegroundColor Green
        Write-Host "First 200 chars: $($content.Substring(0, [Math]::Min(200, $content.Length)))" -ForegroundColor Cyan
    } else {
        Write-Host "RenderContent returned empty content!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host "Test complete." -ForegroundColor Green