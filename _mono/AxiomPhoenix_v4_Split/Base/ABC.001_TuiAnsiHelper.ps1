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

#region TuiAnsiHelper - ANSI Code Generation with Truecolor Support
class TuiAnsiHelper {
    # No caches needed, sequences are generated dynamically now.

    static [hashtable] HexToRgb([string]$hexColor) {
        # Handle non-string values
        if ($hexColor -is [bool] -or $hexColor -eq $true -or $hexColor -eq $false) {
            $caller = (Get-PSCallStack)[1..3] | ForEach-Object { "$($_.FunctionName):$($_.ScriptLineNumber)" } | Join-String -Separator " -> "
            Write-Log -Level Warning -Message "Invalid hex color format: '$hexColor' (boolean value passed where color expected) - Called from: $caller"
            return $null
        }
        
        if ([string]::IsNullOrEmpty($hexColor) -or -not $hexColor.StartsWith("#") -or $hexColor.Length -ne 7) {
            Write-Log -Level Warning -Message "Invalid hex color format: '$hexColor'"
            return $null
        }
        try {
            return @{
                R = [System.Convert]::ToInt32($hexColor.Substring(1, 2), 16)
                G = [System.Convert]::ToInt32($hexColor.Substring(3, 2), 16)
                B = [System.Convert]::ToInt32($hexColor.Substring(5, 2), 16)
            }
        } catch {
            Write-Log -Level Warning -Message "Error parsing hex color '$hexColor': $($_.Exception.Message)"
            return $null
        }
    }

    static [string] GetAnsiSequence([string]$fgHex, [string]$bgHex, [hashtable]$attributes) {
        $sequences = [System.Collections.Generic.List[string]]::new()

        # Foreground color (Truecolor - SGR 38;2)
        if (-not [string]::IsNullOrEmpty($fgHex)) {
            $rgb = [TuiAnsiHelper]::HexToRgb($fgHex)
            if ($rgb) {
                $sequences.Add("38;2;$($rgb.R);$($rgb.G);$($rgb.B)")
            }
        }

        # Background color (Truecolor - SGR 48;2)
        if (-not [string]::IsNullOrEmpty($bgHex)) {
            $rgb = [TuiAnsiHelper]::HexToRgb($bgHex)
            if ($rgb) {
                $sequences.Add("48;2;$($rgb.R);$($rgb.G);$($rgb.B)")
            }
        }

        # Style attributes
        if ($attributes) {
            if ($attributes.ContainsKey('Bold') -and [bool]$attributes['Bold']) { $sequences.Add("1") }
            if ($attributes.ContainsKey('Italic') -and [bool]$attributes['Italic']) { $sequences.Add("3") }
            if ($attributes.ContainsKey('Underline') -and [bool]$attributes['Underline']) { $sequences.Add("4") }
            if ($attributes.ContainsKey('Strikethrough') -and [bool]$attributes['Strikethrough']) { $sequences.Add("9") }
        }

        if ($sequences.Count -eq 0) { return "" }
        return "`e[$($sequences -join ';')m"
    }

    static [string] Reset() { return "`e[0m" }
}
#endregion
#<!-- END_PAGE: ABC.001 -->