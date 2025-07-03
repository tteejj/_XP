class TuiAnsiHelper {
    static [hashtable] $ColorMap = @{
        Black = 30; DarkBlue = 34; DarkGreen = 32; DarkCyan = 36
        DarkRed = 31; DarkMagenta = 35; DarkYellow = 33; Gray = 37
        DarkGray = 90; Blue = 94; Green = 92; Cyan = 96
        Red = 91; Magenta = 95; Yellow = 93; White = 97
    }

    static [int] GetForegroundCode([ConsoleColor]$color) {
        return [TuiAnsiHelper]::ColorMap[$color.ToString()]
    }

    static [int] GetBackgroundCode([ConsoleColor]$color) {
        return [TuiAnsiHelper]::ColorMap[$color.ToString()] + 10
    }

    static [string] Reset() {
        return "`e[0m"
    }

    static [string] Bold() {
        return "`e[1m"
    }

    static [string] Underline() {
        return "`e[4m"
    }

    static [string] Italic() {
        return "`e[3m"
    }
}
