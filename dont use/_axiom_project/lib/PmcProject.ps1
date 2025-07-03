class PmcProject : ValidationBase {
    [string]$Key = ([Guid]::NewGuid().ToString().Split('-')[0]).ToUpper()
    [string]$Name
    [string]$Client
    [BillingType]$BillingType = [BillingType]::NonBillable
    [double]$Rate = 0.0
    [double]$Budget = 0.0
    [bool]$Active = $true
    [datetime]$CreatedAt = [datetime]::Now
    [datetime]$UpdatedAt = [datetime]::Now

    PmcProject() {}
    PmcProject([string]$key, [string]$name) {
        [ValidationBase]::ValidateNotEmpty($key, "Key"); [ValidationBase]::ValidateNotEmpty($name, "Name")
        $this.Key = $key; $this.Name = $name
    }

    [hashtable] ToLegacyFormat() {
        return @{
            Key = $this.Key; Name = $this.Name; Client = $this.Client
            BillingType = $this.BillingType.ToString(); Rate = $this.Rate; Budget = $this.Budget
            Active = $this.Active; CreatedAt = $this.CreatedAt.ToString("o")
        }
    }

    static [PmcProject] FromLegacyFormat([hashtable]$legacyData) {
        $project = [PmcProject]::new()
        $project.Key = $legacyData.Key ?? $project.Key
        $project.Name = $legacyData.Name
        $project.Client = $legacyData.Client
        if ($legacyData.Rate) { $project.Rate = [double]$legacyData.Rate }
        if ($legacyData.Budget) { $project.Budget = [double]$legacyData.Budget }
        if ($legacyData.Active -is [bool]) { $project.Active = $legacyData.Active }
        if ($legacyData.BillingType) { try { $project.BillingType = [BillingType]::$($legacyData.BillingType) } catch {} }
        if ($legacyData.CreatedAt) { try { $project.CreatedAt = [datetime]::Parse($legacyData.CreatedAt) } catch {} }
        $project.UpdatedAt = $project.CreatedAt
        return $project
    }
}
