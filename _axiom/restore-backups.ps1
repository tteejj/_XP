# restore-backups.ps1 - Restores original files from backups
Get-ChildItem -Path . -Filter "*.backup" -Recurse | ForEach-Object {
    $originalPath = $_.FullName.Replace('.backup', '')
    Copy-Item -Path $_.FullName -Destination $originalPath -Force
    Remove-Item -Path $_.FullName
    Write-Host "Restored: $($_.Name.Replace('.backup', ''))"
}
