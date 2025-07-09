        # Add filter textbox at the top
        $this._filterBox = [TextBoxComponent]::new("FilterBox")
        $this._filterBox.Placeholder = "Type to filter tasks..."
        $this._filterBox.X = 2
        $this._filterBox.Y = 2
        $this._filterBox.Width = [Math]::Floor($this.Width * 0.6) - 4
        $this._filterBox.Height = 1
        
        # Fix: Properly capture $this reference for the closure
        $thisScreen = $this
        $this._filterBox.OnChange = {
            param($sender, $newText)
            $thisScreen._filterText = $newText
            $thisScreen._RefreshTasks()
            $thisScreen._UpdateDisplay()
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._filterBox)
