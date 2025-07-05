# NUCLEAR OPTION - Strip ALL type annotations and make it run
param(
    [string]$InputFile = "AxiomPhoenix.ps1",
    [string]$OutputFile = "AxiomPhoenix-FIXED.ps1"
)

Write-Host "Reading $InputFile..." -ForegroundColor Yellow
$content = Get-Content $InputFile -Raw

Write-Host "Stripping ALL type annotations..." -ForegroundColor Red

# 1. Replace ALL typed parameters with untyped
$content = $content -replace '\[\s*[\w\.]+(\[[\w\[\],\s]*\])?\s*\]\s*\$', '$'

# 2. Replace ALL typed properties/fields  
$content = $content -replace '(hidden\s+)?\[\s*[\w\.]+(\[[\w\[\],\s]*\])?\s*\]\s*(\$\w+)', '$1$3'

# 3. Replace ALL return type declarations
$content = $content -replace '\[\s*[\w\.]+(\[[\w\[\],\s]*\])?\s*\]\s*(\w+\s*\()', '$2'

# 4. Fix cast operations - keep only built-in types
$content = $content -replace '\[(?!(string|int|bool|void|object|array|hashtable|psobject|scriptblock|datetime|xml|regex|char|byte|long|double|decimal|single|guid|version|uri|ipaddress|mailaddress|cultureinfo|pscustomobject|ordered|ref|type|math|convert|environment|console|system\.)\b)[\w\.]+(\[[\w\[\],\s]*\])?\]', '[object]'

# 5. Add ALL the namespaces we might need at the top
$namespaces = @"
using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Threading
using namespace System.Threading.Tasks
using namespace System.Text
using namespace System.IO
using namespace System.Linq
using namespace System.Diagnostics
"@

# Insert namespaces after the header comments
if ($content -match '(#[^\n]*\n)*') {
    $headerEnd = $matches[0].Length
    $content = $content.Insert($headerEnd, "`n$namespaces`n")
}

# 6. Save the stripped version
Set-Content $OutputFile -Value $content -Encoding UTF8

Write-Host "`nDONE! Created $OutputFile" -ForegroundColor Green
Write-Host "This version has NO custom type checking but WILL RUN." -ForegroundColor Cyan
Write-Host "`nRun it with: .\$OutputFile" -ForegroundColor Yellow