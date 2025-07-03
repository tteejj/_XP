function Write-TuiText {
    param(
        [TuiBuffer]$Buffer,
        [int]$X,
        [int]$Y,
        [string]$Text,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        [bool]$Bold = $false,
        [bool]$Underline = $false
    )
    
    if ($null -eq $Buffer -or [string]::IsNullOrEmpty($Text)) { return }
    
    $cell = [TuiCell]::new(' ', $ForegroundColor, $BackgroundColor)
    $cell.Bold = $Bold
    $cell.Underline = $Underline
    
    $currentX = $X
    foreach ($char in $Text.ToCharArray()) {
        if ($currentX -ge $Buffer.Width) { break }
        if ($currentX -ge 0) {
            $charCell = [TuiCell]::new($cell)
            $charCell.Char = $char
            $Buffer.SetCell($currentX, $Y, $charCell)
        }
        $currentX++
    }
}

function Write-TuiBox {
    param(
        [TuiBuffer]$Buffer,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [string]$BorderStyle = "Single",
        [ConsoleColor]$BorderColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        [string]$Title = ""
    )
    
    if ($null -eq $Buffer -or $Width -le 0 -or $Height -le 0) { return }
    
    $borders = Get-TuiBorderChars -Style $BorderStyle
    
    # Top border
    $topLine = "$($borders.TopLeft)$($borders.Horizontal * ($Width - 2))$($borders.TopRight)"
    Write-TuiText -Buffer $Buffer -X $X -Y $Y -Text $topLine -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    
    # Title if specified
    if (-not [string]::IsNullOrEmpty($Title)) {
        $titleText = " $Title "
        if ($titleText.Length -le ($Width - 2)) {
            $titleX = $X + [Math]::Floor(($Width - $titleText.Length) / 2)
            Write-TuiText -Buffer $Buffer -X $titleX -Y $Y -Text $titleText -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        }
    }
    
    # Side borders and fill
    for ($i = 1; $i -lt ($Height - 1); $i++) {
        $currentY = $Y + $i
        
        # Left border
        Write-TuiText -Buffer $Buffer -X $X -Y $currentY -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        
        # Fill
        $fillText = ' ' * ($Width - 2)
        Write-TuiText -Buffer $Buffer -X ($X + 1) -Y $currentY -Text $fillText -BackgroundColor $BackgroundColor
        
        # Right border
        Write-TuiText -Buffer $Buffer -X ($X + $Width - 1) -Y $currentY -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
    
    # Bottom border
    if ($Height -gt 1) {
        $bottomLine = "$($borders.BottomLeft)$($borders.Horizontal * ($Width - 2))$($borders.BottomRight)"
        Write-TuiText -Buffer $Buffer -X $X -Y ($Y + $Height - 1) -Text $bottomLine -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
}

function Show-AlertDialog { param([string]$Title="Alert", [string]$Message); Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowAlertDialog" -ScriptBlock { ([AlertDialog]::new($Title, $Message)).Show() } }

function Show-ConfirmDialog { param([string]$Title="Confirm", [string]$Message, [scriptblock]$OnConfirm, [scriptblock]$OnCancel={}); Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowConfirmDialog" -ScriptBlock { ([ConfirmDialog]::new($Title, $Message, $OnConfirm, $OnCancel)).Show() } }

function Show-InputDialog { param([string]$Title="Input", [string]$Prompt, [string]$DefaultValue="", [scriptblock]$OnSubmit, [scriptblock]$OnCancel={}); Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowInputDialog" -ScriptBlock { $d = [InputDialog]::new($Title, $Prompt, $OnSubmit, $OnCancel); if ($DefaultValue) { $d.SetDefaultValue($DefaultValue) }; $d.Show() } }

function Show-ProgressDialog { param([string]$Title="Progress", [string]$Message="Processing...", [int]$PercentComplete=0, [switch]$ShowCancel); Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowProgressDialog" -ScriptBlock { $d = [ProgressDialog]::new($Title, $Message); $d.PercentComplete = $PercentComplete; $d.ShowCancel = $ShowCancel; $d.Show(); return $d } }

function Show-ListDialog { param([string]$Title="Select Item", [string]$Prompt="Choose an item:", [string[]]$Items, [scriptblock]$OnSelect, [scriptblock]$OnCancel={}, [switch]$AllowMultiple); Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowListDialog" -ScriptBlock { $d = [ListDialog]::new($Title, $Prompt, $Items, $OnSelect, $OnCancel); $d.AllowMultiple = $AllowMultiple; $d.Show() } }

function Show-TuiOverlay {
    param([UIElement]$Element)
    $global:TuiState.OverlayStack.Add($Element)
    Request-TuiRefresh
}

