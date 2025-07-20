# Project Model - Enhanced project definition based on PMC pattern

class Project {
    [string]$Id
    [string]$FullProjectName
    [string]$Nickname
    [string]$ID1
    [string]$ID2
    [DateTime]$DateAssigned
    [DateTime]$BFDate
    [DateTime]$DateDue
    [string]$Note
    [string]$CAAPath
    [string]$RequestPath
    [string]$T2020Path
    [decimal]$CumulativeHrs
    [DateTime]$ClosedDate
    [bool]$Deleted
    [DateTime]$CreatedAt
    
    Project([string]$fullName, [string]$nickname) {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.FullProjectName = $fullName
        $this.Nickname = $nickname
        $this.ID1 = ""
        $this.ID2 = ""
        $this.DateAssigned = [DateTime]::Now
        $this.BFDate = [DateTime]::Now
        $this.DateDue = [DateTime]::Now.AddDays(42)  # 6 weeks default
        $this.Note = ""
        $this.CAAPath = ""
        $this.RequestPath = ""
        $this.T2020Path = ""
        $this.CumulativeHrs = 0
        $this.ClosedDate = [DateTime]::MinValue
        $this.Deleted = $false
        $this.CreatedAt = [DateTime]::Now
    }
    
    # Legacy constructor for backward compatibility
    Project([string]$name) {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.FullProjectName = $name
        $this.Nickname = $name
        $this.ID1 = ""
        $this.ID2 = ""
        $this.DateAssigned = [DateTime]::Now
        $this.BFDate = [DateTime]::Now
        $this.DateDue = [DateTime]::Now.AddDays(42)
        $this.Note = ""
        $this.CAAPath = ""
        $this.RequestPath = ""
        $this.T2020Path = ""
        $this.CumulativeHrs = 0
        $this.ClosedDate = [DateTime]::MinValue
        $this.Deleted = $false
        $this.CreatedAt = [DateTime]::Now
    }
}