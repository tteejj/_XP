# ==============================================================================
# Axiom-Phoenix v4.0 - All Functions (Load After Classes)
# Standalone functions for TUI operations and utilities
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: AFU.###" to find specific sections.
# Each section ends with "END_PAGE: AFU.###"
# ==============================================================================

#region Event System

function Subscribe-Event {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventName,
        [Parameter(Mandatory)][scriptblock]$Handler,
        [string]$Source = ""
    )
    
    if ($global:TuiState.Services.EventManager) {
        return $global:TuiState.Services.EventManager.Subscribe($EventName, $Handler)
    }
    
    # Fallback
    $subscriptionId = [Guid]::NewGuid().ToString()
    Write-Verbose "Subscribed to event '$EventName' with handler ID: $subscriptionId"
    return $subscriptionId
}

function Unsubscribe-Event {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventName,
        [Parameter(Mandatory)][string]$HandlerId
    )
    
    if ($global:TuiState.Services.EventManager) {
        $global:TuiState.Services.EventManager.Unsubscribe($EventName, $HandlerId)
    }
    Write-Verbose "Unsubscribed from event '$EventName' (Handler ID: $HandlerId)"
}

function Publish-Event {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventName,
        [hashtable]$EventData = @{}
    )
    
    if ($global:TuiState.Services.EventManager) {
        $global:TuiState.Services.EventManager.Publish($EventName, $EventData)
    }
    Write-Verbose "Published event '$EventName'"
}

#endregion
#<!-- END_PAGE: AFU.007 -->
