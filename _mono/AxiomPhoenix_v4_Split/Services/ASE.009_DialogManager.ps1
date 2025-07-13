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
        
        if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "DialogManager: Initialized with window-based model."
        }
    }

    [void] ShowDialog([Dialog]$dialog) {
        if ($null -eq $dialog) {
            throw [System.ArgumentException]::new("Dialog cannot be null.", "dialog")
        }
        
        # FIXED: WINDOW-BASED MODEL: Use NavigationService to show dialog as a window
        if ($this.NavigationService) {
            if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Debug -Message "DialogManager: Showing dialog '$($dialog.Name)' via NavigationService"
            }
            
            # FIXED: Initialize dialog if needed before navigating
            if ($dialog.PSObject.Methods['Initialize'] -and -not $dialog._isInitialized) {
                $dialog.Initialize()
            }
            
            # Navigate to the dialog
            $this.NavigationService.NavigateTo($dialog)
        } else {
            if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Error -Message "DialogManager: NavigationService not available"
            }
        }
    }

    [void] HideDialog([Dialog]$dialog) {
        # FIXED: WINDOW-BASED MODEL: Dialog handles its own closing via Complete() method
        # which calls NavigationService.GoBack(). This method is now a no-op.
        if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "DialogManager: HideDialog is a no-op. Dialog '$($dialog.Name)' will close itself via its Complete() method."
        }
    }
    
    [void] ShowAlert([string]$title, [string]$message) {
        # FIXED: Pass the service container to the constructor
        $alert = [AlertDialog]::new("Alert", $this.ServiceContainer)
        $alert.Show($title, $message)
        $this.ShowDialog($alert)
    }
    
    [void] ShowConfirm([string]$title, [string]$message, [scriptblock]$onConfirm, [scriptblock]$onCancel = $null) {
        # FIXED: Pass the service container to the constructor
        $confirm = [ConfirmDialog]::new("Confirm", $this.ServiceContainer)
        $confirm.Show($title, $message)
        # The dialog's OnClick handlers will call Complete(), which calls GoBack()
        $confirm.OnClose = {
            param($result)
            if ($result -and $onConfirm) {
                & $onConfirm
            } elseif (-not $result -and $onCancel) {
                & $onCancel
            }
        }.GetNewClosure()
        $this.ShowDialog($confirm)
    }
    
    [void] ShowInput([string]$title, [string]$prompt, [scriptblock]$onComplete, [string]$defaultValue = "") {
        # FIXED: Pass the service container to the constructor
        $input = [InputDialog]::new("Input", $this.ServiceContainer)
        $input.Show($title, $prompt, $defaultValue)
        $input.OnClose = {
            param($result)
            # Only call the completion handler if the user didn't cancel (result is not null)
            if ($null -ne $result -and $onComplete) {
                & $onComplete $result
            }
        }.GetNewClosure()
        $this.ShowDialog($input)
    }

    [void] Cleanup() {
        # Nothing to cleanup in window-based model
        if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "DialogManager: Cleanup complete."
        }
    }
}

#<!-- END_PAGE: ASE.009 -->