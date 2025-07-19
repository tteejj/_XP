# Smart Date Parser for BOLT-AXIOM

class DateParser {
    static [datetime] Parse([string]$input) {
        if ([string]::IsNullOrWhiteSpace($input)) {
            return [datetime]::MinValue
        }
        
        # Remove any spaces or common separators
        $cleaned = $input -replace '[\s\-/.]', ''
        
        # Check for relative date (+d format)
        if ($cleaned -match '^\+(\d+)$') {
            $days = [int]$matches[1]
            return [datetime]::Today.AddDays($days)
        }
        
        # Check for yyyymmdd format
        if ($cleaned -match '^(\d{4})(\d{2})(\d{2})$') {
            $year = [int]$matches[1]
            $month = [int]$matches[2]
            $day = [int]$matches[3]
            
            try {
                return [datetime]::new($year, $month, $day)
            } catch {
                return [datetime]::MinValue
            }
        }
        
        # Check for shortcuts
        switch ($cleaned.ToLower()) {
            'today' { return [datetime]::Today }
            'tomorrow' { return [datetime]::Today.AddDays(1) }
            'nextweek' { return [datetime]::Today.AddDays(7) }
            'nextmonth' { return [datetime]::Today.AddMonths(1) }
        }
        
        # Try standard parse as fallback
        $result = [datetime]::MinValue
        if ([datetime]::TryParse($input, [ref]$result)) {
            return $result
        }
        
        return [datetime]::MinValue
    }
    
    static [string] Format([datetime]$date) {
        if ($date -eq [datetime]::MinValue) {
            return ""
        }
        
        # Show relative dates for near future
        $daysUntil = ($date.Date - [datetime]::Today).TotalDays
        
        if ($daysUntil -eq 0) {
            return "Today"
        } elseif ($daysUntil -eq 1) {
            return "Tomorrow"
        } elseif ($daysUntil -gt 0 -and $daysUntil -le 7) {
            return "+$([int]$daysUntil)d ($($date.ToString('MMM d')))"
        } elseif ($daysUntil -lt 0) {
            return "$([int]-$daysUntil)d ago ($($date.ToString('MMM d')))"
        } else {
            return $date.ToString('MMM d, yyyy')
        }
    }
}