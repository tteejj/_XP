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
