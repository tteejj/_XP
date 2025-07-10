# ==============================================================================
# Axiom-Phoenix v4.0 - DialogManager Service
# Manages modal dialogs using the window-based navigation model
# ==============================================================================

# ===== CLASS: DialogManager =====
# Module: dialog-manager
# Dependencies: NavigationService
# Purpose: Helper service for showing dialogs via NavigationService
class DialogManager {
    [object]$NavigationService = $null
    [object]$ServiceContainer = $null

    DialogManager([object]$serviceContainer) {
        $this.ServiceContainer = $serviceContainer
        $this.NavigationService = $serviceContainer.GetService("NavigationService")
        
        Write-Log -Level Debug -Message "DialogManager: Initialized with window-based model."
    }

    [void] ShowDialog([Dialog]$dialog) {
        if ($null -eq $dialog) {
            throw [System.ArgumentException]::new("Dialog cannot be null.", "dialog")
        }
        
        # WINDOW-BASED MODEL: Use NavigationService to show dialog as a window
        if ($this.NavigationService) {
            Write-Log -Level Debug -Message "DialogManager: Showing dialog '$($dialog.Name)' via NavigationService"
            
            # Initialize dialog if needed
            if ($dialog.PSObject.Methods['Initialize'] -and -not $dialog._isInitialized) {
                $dialog.Initialize()
                $dialog._isInitialized = $true
            }
            
            # Navigate to the dialog
            $this.NavigationService.NavigateTo($dialog)
        } else {
            Write-Log -Level Error -Message "DialogManager: NavigationService not available"
        }
    }

    [void] HideDialog([Dialog]$dialog) {
        # WINDOW-BASED MODEL: Dialog handles its own closing via Complete() method
        # which calls NavigationService.GoBack()
        Write-Log -Level Debug -Message "DialogManager: Dialog '$($dialog.Name)' will close itself via GoBack"
    }
    
    [void] ShowAlert([string]$title, [string]$message) {
        $alert = [AlertDialog]::new("Alert", $this.ServiceContainer)
        $alert.Show($title, $message)
        $this.ShowDialog($alert)
    }
    
    [void] ShowConfirm([string]$title, [string]$message, [scriptblock]$onConfirm, [scriptblock]$onCancel) {
        $confirm = [ConfirmDialog]::new("Confirm", $this.ServiceContainer)
        $confirm.Show($title, $message)
        $confirm.OnConfirm = $onConfirm
        $confirm.OnCancel = $onCancel
        $this.ShowDialog($confirm)
    }
    
    [object] ShowInput([string]$title, [string]$prompt, [string]$defaultValue) {
        $input = [InputDialog]::new("Input", $this.ServiceContainer)
        $input.Show($title, $prompt)
        $input.DefaultValue = $defaultValue
        $this.ShowDialog($input)
        return $input.Result
    }

    [void] Cleanup() {
        # Nothing to cleanup in window-based model
        Write-Log -Level Debug -Message "DialogManager: Cleanup complete."
    }
}

#<!-- END_PAGE: ASE.009 -->
