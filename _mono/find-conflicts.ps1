# Find all property/variable conflicts in mono framework

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Pattern to find class properties
$propertyPattern = '^\s*\[.+\]\s*\$(\w+)\s*='

# Pattern to find local variable assignments
$variablePattern = '^\s*\$(\w+)\s*='

$files = @(
    'AllComponents.ps1',
    'AllScreens.ps1',
    'AllServices.ps1',
    'AllRuntime.ps1'
)

Write-Host "Searching for property/variable conflicts..." -ForegroundColor Cyan

foreach ($file in $files) {
    $filePath = Join-Path $scriptRoot $file
    $content = Get-Content $filePath -Raw
    $lines = Get-Content $filePath
    
    Write-Host "`nChecking $file..." -ForegroundColor Yellow
    
    # Find all class definitions and their properties
    $classPattern = 'class\s+(\w+)\s*(?::\s*\w+)?\s*\{'
    $matches = [regex]::Matches($content, $classPattern)
    
    foreach ($match in $matches) {
        $className = $match.Groups[1].Value
        $classStart = ($content.Substring(0, $match.Index) -split "`n").Count
        
        # Find the end of this class
        $braceCount = 0
        $inClass = $false
        $classProperties = @{}
        
        for ($i = $classStart - 1; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            if ($line -match 'class\s+\w+') {
                $inClass = $true
            }
            
            if ($inClass) {
                $braceCount += ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                $braceCount -= ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                
                if ($braceCount -eq 0 -and $inClass) {
                    break # End of class
                }
                
                # Check for properties
                if ($line -match $propertyPattern) {
                    $propName = $matches[1]
                    $classProperties[$propName.ToLower()] = @{
                        Name = $propName
                        Line = $i + 1
                        Type = if ($line -match '\[(.+?)\]') { $matches[1] } else { 'object' }
                    }
                }
            }
        }
        
        # Now check for conflicting variable assignments within the class
        $inMethod = $false
        $methodBraceCount = 0
        
        for ($i = $classStart - 1; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            if ($line -match '^\s*\[.+\]\s+\w+\s*\(') {
                $inMethod = $true
                $methodBraceCount = 0
            }
            
            if ($inMethod) {
                $methodBraceCount += ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                $methodBraceCount -= ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                
                if ($methodBraceCount -eq 0 -and $line -match '}') {
                    $inMethod = $false
                }
                
                # Check for variable assignments that conflict with properties
                if ($line -match '^\s*\$(\w+)\s*=' -and -not ($line -match '^\s*\$this\.')) {
                    $varName = $matches[1]
                    if ($classProperties.ContainsKey($varName.ToLower())) {
                        Write-Host "  CONFLICT in $className at line $($i + 1): Variable `$$varName conflicts with property" -ForegroundColor Red
                        Write-Host "    Property defined at line $($classProperties[$varName.ToLower()].Line)" -ForegroundColor Gray
                        Write-Host "    Line: $($line.Trim())" -ForegroundColor Gray
                    }
                }
            }
        }
    }
}

Write-Host "`nDone!" -ForegroundColor Green
