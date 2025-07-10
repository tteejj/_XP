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

#region Enums

enum TaskStatus {
    Pending
    InProgress
    Completed
    Cancelled
}

enum TaskPriority {
    Low
    Medium
    High
}

enum BillingType {
    Billable
    NonBillable
}

enum DialogResult {
    None
    OK
    Cancel
    Yes
    No
    Abort
    Retry
    Ignore
}

#endregion
#<!-- END_PAGE: AMO.001 -->
