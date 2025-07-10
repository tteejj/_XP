# ==============================================================================
# Axiom-Phoenix v4.0 - Base Classes (Load First)
# Core framework classes with NO external dependencies
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ABC.###" to find specific sections.
# Each section ends with "END_PAGE: ABC.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Management.Automation
using namespace System.Threading

# Disable verbose output during TUI rendering
$script:TuiVerbosePreference = 'SilentlyContinue'

#region Component - A generic container component
class Component : UIElement {
    Component([string]$name) : base($name) {
        $this.Name = $name
        # Write-Verbose "Component '$($this.Name)' created."
    }

    hidden [void] _RenderContent() {
        ([UIElement]$this)._RenderContent()
        # Write-Verbose "_RenderContent called for Component '$($this.Name)' (delegating to base UIElement)."
    }

    [string] ToString() {
        return "Component(Name='$($this.Name)', Children=$($this.Children.Count))"
    }
}
#endregion
#<!-- END_PAGE: ABC.005 -->
