class MultilineTextBoxComponent : UIElement {
    [string[]]$Lines = @("")
    [string]$Placeholder = "Enter text..."
    [int]$MaxLines = 10
    [int]$MaxLineLength = 100
    [int]$CurrentLine = 0
    [int]$CursorPosition = 0
    [int]$ScrollOffsetY = 0
    [bool]$WordWrap = $true
    [scriptblock]$OnChange
    
    MultilineTextBoxComponent([string]$name) : base() {
        $this.Name = $name
        $this.IsFocusable = $true
        $this.Width = 40
        $this.Height = 10
    }
    
    # AI: REFACTORED - Now uses UIElement buffer system
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            
            # AI: Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Calculate visible area
            $textAreaHeight = $this.Height - 2
            $textAreaWidth = $this.Width - 2
            $startLine = $this.ScrollOffsetY
            $endLine = [Math]::Min($this.Lines.Count - 1, $startLine + $textAreaHeight - 1)
            
            # AI: Render text lines
            for ($i = $startLine; $i -le $endLine; $i++) {
                if ($i -ge $this.Lines.Count) { break }
                
                $line = $this.Lines[$i] ?? ""
                $displayLine = $line
                if ($displayLine.Length -gt $textAreaWidth) {
                    $displayLine = $displayLine.Substring(0, $textAreaWidth)
                }
                
                $lineY = 1 + ($i - $startLine)
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y $lineY -Text $displayLine `
                    -ForegroundColor ([ConsoleColor]::White) -BackgroundColor ([ConsoleColor]::Black)
            }
            
            # AI: Show placeholder if empty and not focused
            if ($this.Lines.Count -eq 1 -and [string]::IsNullOrEmpty($this.Lines[0]) -and -not $this.IsFocused) {
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $this.Placeholder `
                    -ForegroundColor ([ConsoleColor]::DarkGray) -BackgroundColor ([ConsoleColor]::Black)
            }
            
            # AI: Draw cursor if focused
            if ($this.IsFocused) {
                $cursorLine = $this.CurrentLine - $this.ScrollOffsetY
                if ($cursorLine -ge 0 -and $cursorLine -lt $textAreaHeight) {
                    $cursorX = 1 + $this.CursorPosition
                    $cursorY = 1 + $cursorLine
                    if ($cursorX -lt $this.Width - 1) {
                        Write-TuiText -Buffer $this._private_buffer -X $cursorX -Y $cursorY -Text "_" `
                            -ForegroundColor ([ConsoleColor]::Yellow) -BackgroundColor ([ConsoleColor]::Black)
                    }
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "MultilineTextBox render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $currentLineText = $this.Lines[$this.CurrentLine] ?? ""
            $originalLines = $this.Lines.Clone()
            $handled = $true
            
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this.CurrentLine -gt 0) {
                        $this.CurrentLine--
                        $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.Lines[$this.CurrentLine].Length)
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $this.CurrentLine++
                        $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.Lines[$this.CurrentLine].Length)
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.CursorPosition -gt 0) {
                        $this.CursorPosition--
                    } elseif ($this.CurrentLine -gt 0) {
                        $this.CurrentLine--
                        $this.CursorPosition = $this.Lines[$this.CurrentLine].Length
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.CursorPosition -lt $currentLineText.Length) {
                        $this.CursorPosition++
                    } elseif ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $this.CurrentLine++
                        $this.CursorPosition = 0
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::Home) { $this.CursorPosition = 0 }
                ([ConsoleKey]::End) { $this.CursorPosition = $currentLineText.Length }
                ([ConsoleKey]::Enter) {
                    if ($this.Lines.Count -lt $this.MaxLines) {
                        $beforeCursor = $currentLineText.Substring(0, $this.CursorPosition)
                        $afterCursor = $currentLineText.Substring($this.CursorPosition)
                        
                        $this.Lines[$this.CurrentLine] = $beforeCursor
                        $this.Lines = @($this.Lines[0..$this.CurrentLine]) + @($afterCursor) + @($this.Lines[($this.CurrentLine + 1)..($this.Lines.Count - 1)])
                        
                        $this.CurrentLine++
                        $this.CursorPosition = 0
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CursorPosition -gt 0) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Remove($this.CursorPosition - 1, 1)
                        $this.CursorPosition--
                    } elseif ($this.CurrentLine -gt 0 -and $this.Lines.Count -gt 1) {
                        $previousLine = $this.Lines[$this.CurrentLine - 1]
                        $this.CursorPosition = $previousLine.Length
                        $this.Lines[$this.CurrentLine - 1] = $previousLine + $currentLineText
                        $this.Lines = @($this.Lines[0..($this.CurrentLine - 1)]) + @($this.Lines[($this.CurrentLine + 1)..($this.Lines.Count - 1)])
                        $this.CurrentLine--
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($this.CursorPosition -lt $currentLineText.Length) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Remove($this.CursorPosition, 1)
                    } elseif ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $nextLine = $this.Lines[$this.CurrentLine + 1]
                        $this.Lines[$this.CurrentLine] = $currentLineText + $nextLine
                        $this.Lines = @($this.Lines[0..$this.CurrentLine]) + @($this.Lines[($this.CurrentLine + 2)..($this.Lines.Count - 1)])
                    }
                }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar) -and $currentLineText.Length -lt $this.MaxLineLength) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Insert($this.CursorPosition, $key.KeyChar)
                        $this.CursorPosition++
                    } else {
                        $handled = $false
                    }
                }
            }
            
            if ($handled -and $this.OnChange -and -not $this._ArraysEqual($originalLines, $this.Lines)) {
                Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -Context "Change Event" -ScriptBlock { 
                    & $this.OnChange -NewValue $this.Lines 
                }
                $this.RequestRedraw()
            }
            
            return $handled
        } catch { 
            Write-Log -Level Error -Message "MultilineTextBox input error for '$($this.Name)': $_"
            return $false 
        }
    }
    
    hidden [void] _UpdateScrolling() {
        $textAreaHeight = $this.Height - 2
        if ($this.CurrentLine -lt $this.ScrollOffsetY) {
            $this.ScrollOffsetY = $this.CurrentLine
        } elseif ($this.CurrentLine -ge ($this.ScrollOffsetY + $textAreaHeight)) {
            $this.ScrollOffsetY = $this.CurrentLine - $textAreaHeight + 1
        }
    }
    
    hidden [bool] _ArraysEqual([string[]]$array1, [string[]]$array2) {
        if ($array1.Count -ne $array2.Count) { return $false }
        for ($i = 0; $i -lt $array1.Count; $i++) {
            if ($array1[$i] -ne $array2[$i]) { return $false }
        }
        return $true
    }
    
    [string] GetText() {
        return $this.Lines -join "`n"
    }
    
    [void] SetText([string]$text) {
        $this.Lines = if ([string]::IsNullOrEmpty($text)) { @("") } else { $text -split "`n" }
        $this.CurrentLine = 0
        $this.CursorPosition = 0
        $this.ScrollOffsetY = 0
        $this.RequestRedraw()
    }
}
