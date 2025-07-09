# Comprehensive syntax check for AllComponents.ps1
Write-Host "Checking AllComponents.ps1 syntax..." -ForegroundColor Yellow

$filePath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllComponents.ps1"

try {
    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $filePath,
        [ref]$tokens,
        [ref]$errors
    )
    
    if ($errors -and $errors.Count -gt 0) {
        Write-Host "`nParse Errors Found:" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "`nError: $($error.Message)" -ForegroundColor Red
            Write-Host "Line: $($error.Extent.StartLineNumber)" -ForegroundColor Yellow
            Write-Host "Column: $($error.Extent.StartColumnNumber)" -ForegroundColor Yellow
            Write-Host "Text: $($error.Extent.Text)" -ForegroundColor Gray
            
            # Show context
            $lines = Get-Content $filePath
            $startLine = [Math]::Max(0, $error.Extent.StartLineNumber - 3)
            $endLine = [Math]::Min($lines.Count - 1, $error.Extent.StartLineNumber + 2)
            
            Write-Host "`nContext:" -ForegroundColor Cyan
            for ($i = $startLine; $i -le $endLine; $i++) {
                $lineNum = $i + 1
                $prefix = if ($lineNum -eq $error.Extent.StartLineNumber) { ">>>" } else { "   " }
                $color = if ($lineNum -eq $error.Extent.StartLineNumber) { "White" } else { "Gray" }
                Write-Host "$prefix $lineNum`: $($lines[$i])" -ForegroundColor $color
            }
        }
    } else {
        Write-Host "No parse errors found!" -ForegroundColor Green
        
        # Additional validation
        Write-Host "`nPerforming additional validation..." -ForegroundColor Yellow
        
        # Find all methods that return bool
        $content = Get-Content $filePath -Raw
        $methodPattern = '\[bool\]\s+(\w+)\s*\([^)]*\)\s*\{'
        $methodMatches = [regex]::Matches($content, $methodPattern)
        
        Write-Host "Found $($methodMatches.Count) methods returning bool" -ForegroundColor Cyan
        
        # You can add more validation here if needed
    }
    
} catch {
    Write-Host "`nCRITICAL ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}

Write-Host "`nDone!" -ForegroundColor Green
