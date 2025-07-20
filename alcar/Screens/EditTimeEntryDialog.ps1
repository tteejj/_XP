# EditTimeEntryDialog - Edit existing time entry

class EditTimeEntryDialog : GuidedTimeEntryDialog {
    [TimeEntry]$ExistingEntry
    
    EditTimeEntryDialog([object]$parent, [TimeEntry]$entry) : base($parent) {
        $this.ExistingEntry = $entry
        $this.Title = "EDIT TIME ENTRY"
        
        # Pre-populate fields
        $this.ID2 = $entry.ProjectID
        $this.DateInput = $entry.Date.ToString("MMdd")
        $this.HoursInput = $entry.Hours.ToString()
        $this.ParsedDate = $entry.Date
        $this.ParsedHours = $entry.Hours
    }
    
    [void] CreateEntry() {
        try {
            # Update existing entry
            $this.ExistingEntry.ProjectID = $this.ID2
            $this.ExistingEntry.Date = $this.ParsedDate
            $this.ExistingEntry.Hours = $this.ParsedHours
            $this.ExistingEntry.ModifiedAt = [datetime]::Now
            
            # Update via service
            $success = $this.TimeService.UpdateTimeEntry($this.ExistingEntry)
            
            if ($success) {
                $this.Result = [DialogResult]::OK
                $this.Close()
            } else {
                $this.ErrorMessage = "Failed to update entry"
            }
        } catch {
            $this.ErrorMessage = "Failed to update entry: $($_.Exception.Message)"
        }
    }
}