class TableColumn {
    [string]$Key
    [string]$Header
    [int]$Width
    [string]$Alignment = "Left"
    
    TableColumn([string]$key, [string]$header, [int]$width) {
        $this.Key = $key
        $this.Header = $header
        $this.Width = $width
    }
}
