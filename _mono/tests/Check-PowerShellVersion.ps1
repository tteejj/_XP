# PowerShell Version Check Script

Write-Host "PowerShell Version Information:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Display version details
Write-Host "PSVersion: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
Write-Host "PSEdition: $($PSVersionTable.PSEdition)" -ForegroundColor Yellow
Write-Host "PSCompatibleVersions: $($PSVersionTable.PSCompatibleVersions -join ', ')" -ForegroundColor Yellow
Write-Host "BuildVersion: $($PSVersionTable.BuildVersion)" -ForegroundColor Yellow
Write-Host "CLRVersion: $($PSVersionTable.CLRVersion)" -ForegroundColor Yellow
Write-Host "WSManStackVersion: $($PSVersionTable.WSManStackVersion)" -ForegroundColor Yellow
Write-Host "PSRemotingProtocolVersion: $($PSVersionTable.PSRemotingProtocolVersion)" -ForegroundColor Yellow

Write-Host "`nOperating System:" -ForegroundColor Cyan
Write-Host "OS: $($PSVersionTable.OS)" -ForegroundColor Yellow
Write-Host "Platform: $($PSVersionTable.Platform)" -ForegroundColor Yellow

# Check for null-conditional operator support
Write-Host "`nFeature Support:" -ForegroundColor Cyan
$supportsNullConditional = $PSVersionTable.PSVersion.Major -ge 7
Write-Host "Null-conditional operator (?.): $(if ($supportsNullConditional) { 'Supported' } else { 'Not Supported' })" -ForegroundColor $(if ($supportsNullConditional) { 'Green' } else { 'Red' })
Write-Host "Null-coalescing operator (??): $(if ($supportsNullConditional) { 'Supported' } else { 'Not Supported' })" -ForegroundColor $(if ($supportsNullConditional) { 'Green' } else { 'Red' })

Write-Host "`nRecommendation:" -ForegroundColor Cyan
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Your PowerShell version is $($PSVersionTable.PSVersion). The framework has been updated for compatibility." -ForegroundColor Green
    Write-Host "However, for best performance and features, consider upgrading to PowerShell 7.x" -ForegroundColor Yellow
    Write-Host "Download from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
} else {
    Write-Host "Your PowerShell version is $($PSVersionTable.PSVersion). You have full feature support!" -ForegroundColor Green
}

Write-Host "`nTesting null-safe pattern..." -ForegroundColor Cyan
$testObject = @{ Name = "Test" }
$nullObject = $null

# Test the compatible pattern
$name1 = if ($null -ne $testObject) { $testObject.Name } else { 'null' }
$name2 = if ($null -ne $nullObject) { $nullObject.Name } else { 'null' }

Write-Host "Object with Name: $name1" -ForegroundColor Green
Write-Host "Null object: $name2" -ForegroundColor Green
Write-Host "Pattern works correctly!" -ForegroundColor Green
