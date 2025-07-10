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

#region Exception Classes

# ===== CLASS: HeliosException =====
# Module: exceptions (from axiom)
# Dependencies: None (inherits from System.Exception)
# Purpose: Base exception for all framework exceptions
class HeliosException : System.Exception {
    [string]$ErrorCode
    [hashtable]$Context = @{}
    [string]$Component
    [DateTime]$Timestamp
    
    HeliosException([string]$message) : base($message) {
        $this.Timestamp = [DateTime]::Now
    }
    
    HeliosException([string]$message, [string]$component) : base($message) {
        $this.Component = $component
        $this.Timestamp = [DateTime]::Now
    }
    
    HeliosException([string]$message, [string]$component, [hashtable]$context) : base($message) {
        $this.Component = $component
        $this.Context = $context
        $this.Timestamp = [DateTime]::Now
    }
    
    HeliosException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $innerException) {
        $this.Component = $component
        $this.Context = $context
        $this.Timestamp = [DateTime]::Now
    }
}

# ===== CLASS: NavigationException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for navigation-related errors
class NavigationException : HeliosException {
    NavigationException([string]$message) : base($message) {}
    NavigationException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

# ===== CLASS: ServiceInitializationException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for service initialization failures
class ServiceInitializationException : HeliosException {
    ServiceInitializationException([string]$message) : base($message) {}
    ServiceInitializationException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

# ===== CLASS: ComponentRenderException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for component rendering failures
class ComponentRenderException : HeliosException {
    ComponentRenderException([string]$message) : base($message) {}
    ComponentRenderException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

# ===== CLASS: StateMutationException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for state mutation errors
class StateMutationException : HeliosException {
    StateMutationException([string]$message) : base($message) {}
    StateMutationException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

# ===== CLASS: InputHandlingException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for input handling errors
class InputHandlingException : HeliosException {
    InputHandlingException([string]$message) : base($message) {}
    InputHandlingException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

# ===== CLASS: DataLoadException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for data loading errors
class DataLoadException : HeliosException {
    DataLoadException([string]$message) : base($message) {}
    DataLoadException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

#endregion
#<!-- END_PAGE: AMO.004 -->
