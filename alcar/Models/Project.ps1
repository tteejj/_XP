# Project Model - Simple project definition

class Project {
    [string]$Id
    [string]$Name
    [string]$Description
    [DateTime]$CreatedAt
    
    Project([string]$name) {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.Name = $name
        $this.Description = ""
        $this.CreatedAt = [DateTime]::Now
    }
}