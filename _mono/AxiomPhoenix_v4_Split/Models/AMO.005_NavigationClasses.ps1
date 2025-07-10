# ==============================================================================
# Axiom-Phoenix v4.0 - All Models (No UI Dependencies) - UPDATED
# Data models, enums, and validation classes
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: AMO.###" to find specific sections.
# Each section ends with "END_PAGE: AMO.###"
# ==============================================================================

#region Navigation Classes

# ===== CLASS: NavigationItem =====
# Module: navigation-class (from axiom)
# Dependencies: None
# Purpose: Represents a menu item for local/contextual navigation
class NavigationItem {
    [string]$Key
    [string]$Label
    [scriptblock]$Action
    [bool]$Enabled = $true
    [bool]$Visible = $true
    [string]$Description = ""

    NavigationItem([string]$key, [string]$label, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw [System.ArgumentException]::new("Navigation key cannot be null or empty")
        }
        if ([string]::IsNullOrWhiteSpace($label)) {
            throw [System.ArgumentException]::new("Navigation label cannot be null or empty")
        }
        if (-not $action) {
            throw [System.ArgumentNullException]::new("action", "Navigation action cannot be null")
        }

        $this.Key = $key.ToUpper()
        $this.Label = $label
        $this.Action = $action
    }

    [void] Execute() {
        try {
            if (-not $this.Enabled) {
                return
            }
            
            & $this.Action
        }
        catch {
            throw
        }
    }

    [string] ToString() {
        return "NavigationItem(Key='$($this.Key)', Label='$($this.Label)', Enabled=$($this.Enabled))"
    }
}

#endregion
#<!-- END_PAGE: AMO.005 -->
