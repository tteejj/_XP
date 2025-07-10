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

#region Base Validation Class

# ===== CLASS: ValidationBase =====
# Module: models (from axiom)
# Dependencies: None
# Purpose: Provides common validation methods used across model classes
class ValidationBase {
    # Validates that a string value is not null, empty, or whitespace.
    # Throws an ArgumentException if the validation fails.
    static [void] ValidateNotEmpty(
        [string]$value,
        [string]$parameterName
    ) {
        try {
            if ([string]::IsNullOrWhiteSpace($value)) {
                $errorMessage = "Parameter '$($parameterName)' cannot be null or empty."
                throw [System.ArgumentException]::new($errorMessage, $parameterName)
            }
        }
        catch {
            # Re-throw to ensure calling context handles the exception
            throw
        }
    }
}

#endregion
#<!-- END_PAGE: AMO.002 -->
