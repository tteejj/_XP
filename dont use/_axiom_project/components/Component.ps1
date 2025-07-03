class Component : UIElement {
    Component([string]$name) : base($name) {
    }

    # AI: Default implementation renders all visible children to buffer
    hidden [void] _RenderContent() {
        # Call parent implementation for buffer management
        ([UIElement]$this)._RenderContent()
    }
}
