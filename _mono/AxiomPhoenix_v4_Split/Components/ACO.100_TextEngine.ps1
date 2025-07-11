# ==============================================================================
# High-Performance Text Buffer Engine for Axiom-Phoenix
# Implements gap buffer with line indexing for optimal editing performance
# ==============================================================================

using namespace System.Collections.Generic

# Interface for edit commands (for undo/redo)
class IEditCommand {
    [void] Execute([TextBuffer]$buffer) { throw "Must override Execute" }
    [void] Undo([TextBuffer]$buffer) { throw "Must override Undo" }
    [string] ToString() { return "EditCommand" }
}

# Insert text command
class InsertCommand : IEditCommand {
    [int]$Position
    [string]$Text
    [int]$CursorBefore
    [int]$CursorAfter
    
    InsertCommand([int]$position, [string]$text, [int]$cursorBefore) {
        $this.Position = $position
        $this.Text = $text
        $this.CursorBefore = $cursorBefore
        $this.CursorAfter = $position + $text.Length
    }
    
    [void] Execute([TextBuffer]$buffer) {
        $buffer.InsertAt($this.Position, $this.Text)
    }
    
    [void] Undo([TextBuffer]$buffer) {
        $buffer.DeleteRange($this.Position, $this.Text.Length)
    }
}

# Delete text command
class DeleteCommand : IEditCommand {
    [int]$Position
    [string]$DeletedText
    [int]$CursorBefore
    [int]$CursorAfter
    
    DeleteCommand([int]$position, [int]$length, [string]$deletedText, [int]$cursorBefore) {
        $this.Position = $position
        $this.DeletedText = $deletedText
        $this.CursorBefore = $cursorBefore
        $this.CursorAfter = $position
    }
    
    [void] Execute([TextBuffer]$buffer) {
        $buffer.DeleteRange($this.Position, $this.DeletedText.Length)
    }
    
    [void] Undo([TextBuffer]$buffer) {
        $buffer.InsertAt($this.Position, $this.DeletedText)
    }
}

# High-performance text buffer using gap buffer algorithm
class TextBuffer {
    # Gap buffer arrays
    hidden [List[char]]$_preGap
    hidden [List[char]]$_postGap
    hidden [int]$_gapSize = 1024
    
    # Line tracking for O(1) line access
    hidden [List[int]]$_lineStarts  # Starting position of each line
    hidden [Dictionary[int,int]]$_lineLengths  # Cache of line lengths
    
    # Change tracking
    hidden [HashSet[int]]$_dirtyLines
    hidden [int]$_version = 0
    hidden [bool]$_linesCacheValid = $false
    
    # Properties
    [int]$Length = 0
    [int]$LineCount = 1
    
    TextBuffer() {
        $this._preGap = [List[char]]::new()
        $this._postGap = [List[char]]::new()
        $this._lineStarts = [List[int]]::new()
        $this._lineStarts.Add(0)  # First line starts at 0
        $this._lineLengths = [Dictionary[int,int]]::new()
        $this._dirtyLines = [HashSet[int]]::new()
    }
    
    # Get cursor position (gap position)
    [int] GetCursorPosition() {
        return $this._preGap.Count
    }
    
    # Move cursor to position (move gap)
    [void] SetCursorPosition([int]$position) {
        if ($position -lt 0) { $position = 0 }
        if ($position -gt $this.Length) { $position = $this.Length }
        
        $currentPos = $this._preGap.Count
        if ($position -eq $currentPos) { return }
        
        if ($position -lt $currentPos) {
            # Move gap left
            $moveCount = $currentPos - $position
            for ($i = 0; $i -lt $moveCount; $i++) {
                if ($this._preGap.Count -gt 0) {
                    $char = $this._preGap[$this._preGap.Count - 1]
                    $this._preGap.RemoveAt($this._preGap.Count - 1)
                    $this._postGap.Insert(0, $char)
                }
            }
        } else {
            # Move gap right
            $moveCount = $position - $currentPos
            for ($i = 0; $i -lt $moveCount; $i++) {
                if ($this._postGap.Count -gt 0) {
                    $char = $this._postGap[0]
                    $this._postGap.RemoveAt(0)
                    $this._preGap.Add($char)
                }
            }
        }
    }
    
    # Insert character at cursor
    [void] InsertChar([char]$char) {
        $this._preGap.Add($char)
        $this.Length++
        $this._version++
        
        if ($char -eq "`n") {
            $this._linesCacheValid = $false
            $this.InvalidateLinesFrom($this.GetLineFromPosition($this._preGap.Count - 1))
        } else {
            $line = $this.GetLineFromPosition($this._preGap.Count - 1)
            $this._dirtyLines.Add($line) | Out-Null
        }
    }
    
    # Insert string at cursor
    [void] Insert([string]$text) {
        if ([string]::IsNullOrEmpty($text)) { return }
        
        foreach ($char in $text.ToCharArray()) {
            $this._preGap.Add($char)
            $this.Length++
        }
        
        $this._version++
        $this._linesCacheValid = $false
        $this.InvalidateLinesFrom($this.GetLineFromPosition($this._preGap.Count - $text.Length))
    }
    
    # Insert at specific position
    [void] InsertAt([int]$position, [string]$text) {
        $oldPos = $this.GetCursorPosition()
        $this.SetCursorPosition($position)
        $this.Insert($text)
        $this.SetCursorPosition($oldPos + $text.Length)
    }
    
    # Delete character before cursor (backspace)
    [bool] DeleteBackward() {
        if ($this._preGap.Count -eq 0) { return $false }
        
        $deletedChar = $this._preGap[$this._preGap.Count - 1]
        $this._preGap.RemoveAt($this._preGap.Count - 1)
        $this.Length--
        $this._version++
        
        if ($deletedChar -eq "`n") {
            $this._linesCacheValid = $false
            $this.InvalidateLinesFrom($this.GetLineFromPosition($this._preGap.Count))
        } else {
            $line = $this.GetLineFromPosition($this._preGap.Count)
            $this._dirtyLines.Add($line) | Out-Null
        }
        
        return $true
    }
    
    # Delete character at cursor (delete)
    [bool] DeleteForward() {
        if ($this._postGap.Count -eq 0) { return $false }
        
        $deletedChar = $this._postGap[0]
        $this._postGap.RemoveAt(0)
        $this.Length--
        $this._version++
        
        if ($deletedChar -eq "`n") {
            $this._linesCacheValid = $false
            $this.InvalidateLinesFrom($this.GetLineFromPosition($this._preGap.Count))
        } else {
            $line = $this.GetLineFromPosition($this._preGap.Count)
            $this._dirtyLines.Add($line) | Out-Null
        }
        
        return $true
    }
    
    # Delete range of text
    [string] DeleteRange([int]$start, [int]$length) {
        if ($length -le 0) { return "" }
        
        $oldPos = $this.GetCursorPosition()
        $this.SetCursorPosition($start)
        
        $deleted = [System.Text.StringBuilder]::new()
        for ($i = 0; $i -lt $length -and $this._postGap.Count -gt 0; $i++) {
            $deleted.Append($this._postGap[0]) | Out-Null
            $this._postGap.RemoveAt(0)
            $this.Length--
        }
        
        $this._version++
        $this._linesCacheValid = $false
        $this.InvalidateLinesFrom($this.GetLineFromPosition($start))
        
        return $deleted.ToString()
    }
    
    # Get character at position
    [char] GetChar([int]$position) {
        if ($position -lt 0 -or $position -ge $this.Length) {
            throw "Position out of range"
        }
        
        if ($position -lt $this._preGap.Count) {
            return $this._preGap[$position]
        } else {
            return $this._postGap[$position - $this._preGap.Count]
        }
    }
    
    # Get substring
    [string] GetText([int]$start, [int]$length) {
        if ($start -lt 0) { $start = 0 }
        if ($start + $length -gt $this.Length) { $length = $this.Length - $start }
        if ($length -le 0) { return "" }
        
        $sb = [System.Text.StringBuilder]::new($length)
        $end = $start + $length
        
        for ($i = $start; $i -lt $end; $i++) {
            if ($i -lt $this._preGap.Count) {
                $sb.Append($this._preGap[$i]) | Out-Null
            } else {
                $sb.Append($this._postGap[$i - $this._preGap.Count]) | Out-Null
            }
        }
        
        return $sb.ToString()
    }
    
    # Get all text
    [string] GetAllText() {
        return $this.GetText(0, $this.Length)
    }
    
    # Get line from position
    [int] GetLineFromPosition([int]$position) {
        if (-not $this._linesCacheValid) {
            $this.RebuildLineCache()
        }
        
        # Binary search for line
        $left = 0
        $right = $this._lineStarts.Count - 1
        
        while ($left -le $right) {
            $mid = ($left + $right) / 2
            $lineStart = $this._lineStarts[$mid]
            
            if ($position -lt $lineStart) {
                $right = $mid - 1
            } elseif ($mid -eq $this._lineStarts.Count - 1 -or $position -lt $this._lineStarts[$mid + 1]) {
                return $mid
            } else {
                $left = $mid + 1
            }
        }
        
        return [Math]::Max(0, $this._lineStarts.Count - 1)
    }
    
    # Get line start position
    [int] GetLineStart([int]$line) {
        if (-not $this._linesCacheValid) {
            $this.RebuildLineCache()
        }
        
        if ($line -lt 0) { return 0 }
        if ($line -ge $this._lineStarts.Count) { return $this.Length }
        
        return $this._lineStarts[$line]
    }
    
    # Get line end position
    [int] GetLineEnd([int]$line) {
        if (-not $this._linesCacheValid) {
            $this.RebuildLineCache()
        }
        
        if ($line -lt 0) { return 0 }
        if ($line -ge $this._lineStarts.Count - 1) { return $this.Length }
        
        return $this._lineStarts[$line + 1] - 1  # Exclude newline
    }
    
    # Get line text
    [string] GetLineText([int]$line) {
        $start = $this.GetLineStart($line)
        $end = $this.GetLineEnd($line)
        
        if ($end -gt $start -and $this.GetChar($end - 1) -eq "`n") {
            $end--
        }
        
        return $this.GetText($start, $end - $start)
    }
    
    # Rebuild line cache
    hidden [void] RebuildLineCache() {
        $this._lineStarts.Clear()
        $this._lineStarts.Add(0)
        
        for ($i = 0; $i -lt $this.Length; $i++) {
            if ($this.GetChar($i) -eq "`n") {
                $this._lineStarts.Add($i + 1)
            }
        }
        
        $this.LineCount = $this._lineStarts.Count
        $this._linesCacheValid = $true
        $this._dirtyLines.Clear()
        
        # Mark all lines as dirty after rebuild
        for ($i = 0; $i -lt $this.LineCount; $i++) {
            $this._dirtyLines.Add($i) | Out-Null
        }
    }
    
    # Invalidate lines from a specific line
    hidden [void] InvalidateLinesFrom([int]$startLine) {
        if (-not $this._linesCacheValid) { return }
        
        for ($i = $startLine; $i -lt $this.LineCount; $i++) {
            $this._dirtyLines.Add($i) | Out-Null
        }
    }
    
    # Get dirty lines and clear
    [int[]] GetAndClearDirtyLines() {
        $dirty = @($this._dirtyLines)
        $this._dirtyLines.Clear()
        return $dirty
    }
    
    # Word boundary detection
    [bool] IsWordChar([char]$char) {
        return [char]::IsLetterOrDigit($char) -or $char -eq '_'
    }
    
    # Find next word boundary
    [int] FindNextWordBoundary([int]$position, [bool]$forward = $true) {
        if ($position -lt 0) { $position = 0 }
        if ($position -gt $this.Length) { $position = $this.Length }
        
        if ($forward) {
            # Skip current word
            while ($position -lt $this.Length -and $this.IsWordChar($this.GetChar($position))) {
                $position++
            }
            # Skip whitespace
            while ($position -lt $this.Length -and [char]::IsWhiteSpace($this.GetChar($position))) {
                $position++
            }
        } else {
            if ($position -gt 0) { $position-- }
            # Skip whitespace
            while ($position -gt 0 -and [char]::IsWhiteSpace($this.GetChar($position))) {
                $position--
            }
            # Skip to word start
            while ($position -gt 0 -and $this.IsWordChar($this.GetChar($position - 1))) {
                $position--
            }
        }
        
        return $position
    }
    
    # Find matching bracket
    [int] FindMatchingBracket([int]$position) {
        if ($position -lt 0 -or $position -ge $this.Length) { return -1 }
        
        $char = $this.GetChar($position)
        $openBrackets = '([{'
        $closeBrackets = ')]}'
        
        $openIndex = $openBrackets.IndexOf($char)
        $closeIndex = $closeBrackets.IndexOf($char)
        
        if ($openIndex -ge 0) {
            # Forward search
            $match = $closeBrackets[$openIndex]
            $depth = 1
            $pos = $position + 1
            
            while ($pos -lt $this.Length -and $depth -gt 0) {
                $c = $this.GetChar($pos)
                if ($c -eq $char) { $depth++ }
                elseif ($c -eq $match) { $depth-- }
                $pos++
            }
            
            return if ($depth -eq 0) { $pos - 1 } else { -1 }
        }
        elseif ($closeIndex -ge 0) {
            # Backward search
            $match = $openBrackets[$closeIndex]
            $depth = 1
            $pos = $position - 1
            
            while ($pos -ge 0 -and $depth -gt 0) {
                $c = $this.GetChar($pos)
                if ($c -eq $char) { $depth++ }
                elseif ($c -eq $match) { $depth-- }
                $pos--
            }
            
            return if ($depth -eq 0) { $pos + 1 } else { -1 }
        }
        
        return -1
    }
}

# Search result
class SearchResult {
    [int]$Start
    [int]$Length
    [int]$Line
    [string]$LineText
    
    SearchResult([int]$start, [int]$length, [int]$line, [string]$lineText) {
        $this.Start = $start
        $this.Length = $length
        $this.Line = $line
        $this.LineText = $lineText
    }
}

# Search engine for incremental search
class SearchEngine {
    hidden [TextBuffer]$_buffer
    hidden [string]$_lastPattern = ""
    hidden [List[SearchResult]]$_results
    hidden [int]$_currentResultIndex = -1
    hidden [bool]$_caseSensitive = $false
    hidden [bool]$_wholeWord = $false
    hidden [bool]$_useRegex = $false
    
    SearchEngine([TextBuffer]$buffer) {
        $this._buffer = $buffer
        $this._results = [List[SearchResult]]::new()
    }
    
    # Perform search
    [SearchResult[]] Search([string]$pattern, [bool]$caseSensitive = $false, [bool]$wholeWord = $false) {
        if ([string]::IsNullOrEmpty($pattern)) {
            $this._results.Clear()
            $this._currentResultIndex = -1
            return @()
        }
        
        $this._lastPattern = $pattern
        $this._caseSensitive = $caseSensitive
        $this._wholeWord = $wholeWord
        $this._results.Clear()
        
        $text = $this._buffer.GetAllText()
        $searchPattern = if ($caseSensitive) { $pattern } else { $pattern.ToLower() }
        $searchText = if ($caseSensitive) { $text } else { $text.ToLower() }
        
        $index = 0
        while ($index -lt $searchText.Length) {
            $foundIndex = $searchText.IndexOf($searchPattern, $index)
            if ($foundIndex -eq -1) { break }
            
            # Check whole word
            if ($wholeWord) {
                $isWordStart = $foundIndex -eq 0 -or -not $this._buffer.IsWordChar($text[$foundIndex - 1])
                $isWordEnd = $foundIndex + $pattern.Length -ge $text.Length -or -not $this._buffer.IsWordChar($text[$foundIndex + $pattern.Length])
                
                if (-not ($isWordStart -and $isWordEnd)) {
                    $index = $foundIndex + 1
                    continue
                }
            }
            
            $line = $this._buffer.GetLineFromPosition($foundIndex)
            $lineText = $this._buffer.GetLineText($line)
            
            $result = [SearchResult]::new($foundIndex, $pattern.Length, $line, $lineText)
            $this._results.Add($result)
            
            $index = $foundIndex + 1
        }
        
        if ($this._results.Count -gt 0) {
            $this._currentResultIndex = 0
        }
        
        return $this._results.ToArray()
    }
    
    # Get current result
    [SearchResult] GetCurrentResult() {
        if ($this._currentResultIndex -ge 0 -and $this._currentResultIndex -lt $this._results.Count) {
            return $this._results[$this._currentResultIndex]
        }
        return $null
    }
    
    # Move to next result
    [SearchResult] NextResult() {
        if ($this._results.Count -eq 0) { return $null }
        
        $this._currentResultIndex = ($this._currentResultIndex + 1) % $this._results.Count
        return $this._results[$this._currentResultIndex]
    }
    
    # Move to previous result
    [SearchResult] PreviousResult() {
        if ($this._results.Count -eq 0) { return $null }
        
        $this._currentResultIndex = ($this._currentResultIndex - 1 + $this._results.Count) % $this._results.Count
        return $this._results[$this._currentResultIndex]
    }
    
    # Replace current occurrence
    [bool] ReplaceCurrent([string]$replacement) {
        $current = $this.GetCurrentResult()
        if (-not $current) { return $false }
        
        $oldPos = $this._buffer.GetCursorPosition()
        $this._buffer.SetCursorPosition($current.Start)
        $this._buffer.DeleteRange($current.Start, $current.Length)
        $this._buffer.Insert($replacement)
        $this._buffer.SetCursorPosition($oldPos)
        
        # Re-search after replacement
        $this.Search($this._lastPattern, $this._caseSensitive, $this._wholeWord)
        
        return $true
    }
    
    # Replace all occurrences
    [int] ReplaceAll([string]$replacement) {
        if ($this._results.Count -eq 0) { return 0 }
        
        $count = 0
        $oldPos = $this._buffer.GetCursorPosition()
        
        # Replace from end to start to maintain positions
        for ($i = $this._results.Count - 1; $i -ge 0; $i--) {
            $result = $this._results[$i]
            $this._buffer.SetCursorPosition($result.Start)
            $this._buffer.DeleteRange($result.Start, $result.Length)
            $this._buffer.Insert($replacement)
            $count++
        }
        
        $this._buffer.SetCursorPosition($oldPos)
        $this._results.Clear()
        $this._currentResultIndex = -1
        
        return $count
    }
}

# Text selection
class TextSelection {
    [int]$Start = -1
    [int]$End = -1
    [bool]$IsActive = $false
    
    [void] StartSelection([int]$position) {
        $this.Start = $position
        $this.End = $position
        $this.IsActive = $true
    }
    
    [void] UpdateSelection([int]$position) {
        if ($this.IsActive) {
            $this.End = $position
        }
    }
    
    [void] ClearSelection() {
        $this.Start = -1
        $this.End = -1
        $this.IsActive = $false
    }
    
    [int] GetNormalizedStart() {
        if (-not $this.IsActive) { return -1 }
        return [Math]::Min($this.Start, $this.End)
    }
    
    [int] GetNormalizedEnd() {
        if (-not $this.IsActive) { return -1 }
        return [Math]::Max($this.Start, $this.End)
    }
    
    [int] GetLength() {
        if (-not $this.IsActive) { return 0 }
        return [Math]::Abs($this.End - $this.Start)
    }
    
    [bool] ContainsPosition([int]$position) {
        if (-not $this.IsActive) { return $false }
        $start = $this.GetNormalizedStart()
        $end = $this.GetNormalizedEnd()
        return $position -ge $start -and $position -lt $end
    }
}
