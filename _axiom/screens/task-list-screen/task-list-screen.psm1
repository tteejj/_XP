# ==============================================================================
# PMC Terminal v5 - NCurses Task List Screen
# Displays and manages tasks with buffer-based rendering
# CORRECTED (v2): Fixed $this scoping issue in scriptblocks for dialogs/input.
#
# ARCHITECTURAL NOTE:
# This class is a "Screen" and acts as a top-level container. It does not
# perform any rendering itself. Instead, it orchestrates child "Panel"
# components, which are responsible for their own rendering. The TUI Engine
# composites the final view from the buffers of these child components.
# ==============================================================================
class TaskListScreen : Screen {
# --- Core Architecture ---
[Panel] $MainPanel
[Panel] $HeaderPanel
[Panel] $TablePanel
[Panel] $FooterPanel
[Table] $TaskTable
[System.Collections.Generic.List[UIElement]] $Components

# --- State Management ---
[string] $FilterStatus = "All"
[object[]] $AllTasks = @()
[System.Collections.ArrayList] $FilteredTasks = [System.Collections.ArrayList]::new()
[int] $SelectedIndex = 0

# --- Constructor ---
TaskListScreen([hashtable]$services) : base("TaskListScreen", $services) {
$this.Name = "TaskListScreen"
$this.Components = [System.Collections.Generic.List[UIElement]]::new()
$this.IsFocusable = $true
$this.Enabled = $true
$this.Visible = $true
}

# --- Initialization ---
[void] Initialize() {
Invoke-WithErrorHandling -Component "TaskListScreen" -Context "Initialize" -ScriptBlock {
$this.Width = $global:TuiState.BufferWidth
$this.Height = $global:TuiState.BufferHeight

if ($null -ne $this.{_private_buffer}) {
$this.{_private_buffer}.Resize($this.Width, $this.Height)
}

$this.MainPanel = [Panel]::new(0, 0, $this.Width, $this.Height, "Task List")
$this.MainPanel.HasBorder = $true
$this.MainPanel.BorderStyle = "Double"
$this.MainPanel.BorderColor = [ConsoleColor]::Gray
$this.MainPanel.BackgroundColor = [ConsoleColor]::Black
$this.MainPanel.Name = "MainTaskPanel"
$this.AddChild($this.MainPanel)

$this.HeaderPanel = [Panel]::new(1, 1, $this.Width - 2, 3, "")
$this.HeaderPanel.HasBorder = $false
$this.HeaderPanel.BackgroundColor = [ConsoleColor]::Black
$this.HeaderPanel.Name = "HeaderPanel"
$this.MainPanel.AddChild($this.HeaderPanel)

$this.TablePanel = [Panel]::new(1, 4, $this.Width - 2, $this.Height - 8, "")
$this.TablePanel.HasBorder = $true
$this.TablePanel.BorderStyle = "Single"
$this.TablePanel.BorderColor = [ConsoleColor]::DarkGray
$this.TablePanel.BackgroundColor = [ConsoleColor]::Black
$this.TablePanel.Name = "TablePanel"
$this.MainPanel.AddChild($this.TablePanel)

$this.FooterPanel = [Panel]::new(1, $this.Height - 4, $this.Width - 2, 3, "")
$this.FooterPanel.HasBorder = $false
$this.FooterPanel.BackgroundColor = [ConsoleColor]::Black
$this.FooterPanel.Name = "FooterPanel"
$this.MainPanel.AddChild($this.FooterPanel)

$this.TaskTable = [Table]::new("TaskTable")
$this.TaskTable.Move(0, 0)
$this.TaskTable.Resize($this.TablePanel.ContentWidth, $this.TablePanel.ContentHeight)
$this.TaskTable.ShowBorder = $false

$columns = @(
[TableColumn]::new('Title', 'Task Title', 50),
[TableColumn]::new('Status', 'Status', 15),
[TableColumn]::new('Priority', 'Priority', 12),
[TableColumn]::new('DueDate', 'Due Date', 15)
)
$this.TaskTable.SetColumns($columns)

$this.TablePanel.AddChild($this.TaskTable)

$this.RefreshData()
$this.UpdateDisplay()

$this.RequestRedraw()
$this.Render()
}
}

# --- Data Management ---
hidden [void] RefreshData() {
Invoke-WithErrorHandling -Component "TaskListScreen" -Context "RefreshData" -ScriptBlock {
try {
$this.AllTasks = @($this.Services.DataManager.GetTasks())
if ($null -eq $this.AllTasks) { $this.AllTasks = @() }
} catch {
Write-Log -Level Warning -Message "Failed to load tasks: $_"
$this.AllTasks = @()
}

$filterResult = switch ($this.FilterStatus) {
"Active" { $this.AllTasks | Where-Object { $_.Status -ne [TaskStatus]::Completed } }
"Completed" { $this.AllTasks | Where-Object { $_.Status -eq [TaskStatus]::Completed } }
default { $this.AllTasks }
}

$this.FilteredTasks = [System.Collections.ArrayList]::new()
if ($null -ne $filterResult) {
if ($filterResult -is [array]) {
foreach ($item in $filterResult) { $this.FilteredTasks.Add($item) | Out-Null }
} else {
$this.FilteredTasks.Add($filterResult) | Out-Null
}
}

$this.TaskTable.SetData($this.FilteredTasks)

if ($null -ne $this.FilteredTasks -and $this.SelectedIndex -ge $this.FilteredTasks.Count) {
$this.SelectedIndex = [Math]::Max(0, $this.FilteredTasks.Count - 1)
}

$this.RequestRedraw()
}
}

hidden [void] UpdateDisplay() {
Invoke-WithErrorHandling -Component "TaskListScreen" -Context "UpdateDisplay" -ScriptBlock {
$taskCount = if ($null -ne $this.FilteredTasks) { $this.FilteredTasks.Count } else { 0 }
$headerText = "Filter: $($this.FilterStatus) | Total: $taskCount tasks"
$this.WriteTextToPanel($this.HeaderPanel, $headerText, 0, 0, [ConsoleColor]::White)
$this.HeaderPanel.RequestRedraw()

$footerText = "[↑↓]Navigate [Space]Toggle [N]ew [E]dit [D]elete [F]ilter [Esc]Back"
$this.WriteTextToPanel($this.FooterPanel, $footerText, 0, 0, [ConsoleColor]::Yellow)
$this.FooterPanel.RequestRedraw()

$this.TaskTable.SelectedIndex = $this.SelectedIndex

$this.RequestRedraw()
}
}

# --- Helper Methods ---
hidden [void] WriteTextToPanel([Panel]$panel, [string]$text, [int]$x, [int]$y, [ConsoleColor]$color) {
if ($null -eq $panel -or $null -eq $panel.{_private_buffer}) { return }
$chars = $text.ToCharArray()
for ($i = 0; $i -lt $chars.Length -and ($x + $i) -lt $panel.ContentWidth; $i++) {
$cell = [TuiCell]::new($chars[$i], $color, $panel.BackgroundColor)
$panel.{_private_buffer}.SetCell($panel.ContentX + $x + $i, $panel.ContentY + $y, $cell)
}
}

# --- Input Handling ---
[bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
# Capture the screen instance ($this) into a local variable so the
# scriptblock passed to Invoke-WithErrorHandling can access it.
$self = $this
Invoke-WithErrorHandling -Component "TaskListScreen" -Context "HandleInput" -ScriptBlock {
switch ($keyInfo.Key) {
([ConsoleKey]::UpArrow) {
if ($self.SelectedIndex -gt 0) {
$self.SelectedIndex--
$self.UpdateDisplay()
return $true
}
}
([ConsoleKey]::DownArrow) {
if ($self.SelectedIndex -lt ($self.FilteredTasks.Count - 1) -and $self.FilteredTasks.Count -gt 0) {
$self.SelectedIndex++
$self.UpdateDisplay()
return $true
}
}
([ConsoleKey]::Spacebar) {
$self.ToggleSelectedTask()
return $true
}
([ConsoleKey]::Escape) {
$self.NavigateBack()
return $true
}
default {
$keyChar = $keyInfo.KeyChar.ToString().ToUpper()
switch ($keyChar) {
'N' { $self.ShowNewTaskDialog(); return $true }
'E' { $self.EditSelectedTask(); return $true }
'D' { $self.DeleteSelectedTask(); return $true }
'F' { $self.CycleFilter(); return $true }
}
}
}
}
return $false
}

# --- Task Actions ---
hidden [void] ToggleSelectedTask() {
if ($this.FilteredTasks.Count -eq 0 -or $this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $this.FilteredTasks.Count) { return }
$task = $this.FilteredTasks[$this.SelectedIndex]
if ($null -eq $task) { return }
$newCompletedStatus = $task.Status -ne [TaskStatus]::Completed
$this.Services.DataManager.UpdateTask(@{ Task = $task; Completed = $newCompletedStatus })
$this.RefreshData()
$this.UpdateDisplay()
}

hidden [void] ShowNewTaskDialog() {
# Capture necessary context for the dialog's callback scriptblock.
$dataManager = $this.Services.DataManager
$screen = $this
Show-InputDialog -Title "New Task" -Prompt "Enter task title:" -OnSubmit {
param($Value)
if (-not [string]::IsNullOrWhiteSpace($Value)) {
$dataManager.AddTask($Value, "", "medium", "General")
$screen.RefreshData()
$screen.UpdateDisplay()
}
}
}

hidden [void] EditSelectedTask() {
if ($null -eq $this.FilteredTasks -or $this.FilteredTasks.Count -eq 0 -or $this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $this.FilteredTasks.Count) { return }
$task = $this.FilteredTasks[$this.SelectedIndex]
if ($null -eq $task) { return }
# Capture necessary context for the dialog's callback scriptblock.
$dataManager = $this.Services.DataManager
$screen = $this
Show-InputDialog -Title "Edit Task" -Prompt "New title:" -DefaultValue $task.Title -OnSubmit {
param($Value)
if (-not [string]::IsNullOrWhiteSpace($Value)) {
$dataManager.UpdateTask(@{ Task = $task; Title = $Value })
$screen.RefreshData()
$screen.UpdateDisplay()
}
}
}

hidden [void] DeleteSelectedTask() {
if ($null -eq $this.FilteredTasks -or $this.FilteredTasks.Count -eq 0 -or $this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $this.FilteredTasks.Count) { return }
$task = $this.FilteredTasks[$this.SelectedIndex]
if ($null -eq $task) { return }
# Capture necessary context for the dialog's callback scriptblock.
$dataManager = $this.Services.DataManager
$screen = $this
Show-ConfirmDialog -Title "Delete Task" -Message "Are you sure you want to delete `"$($task.Title)`"?" -OnConfirm {
$dataManager.RemoveTask($task)
$screen.RefreshData()
$screen.UpdateDisplay()
}
}

hidden [void] CycleFilter() {
$this.FilterStatus = switch ($this.FilterStatus) {
"All" { "Active" }
"Active" { "Completed" }
default { "All" }
}
$this.RefreshData()
$this.UpdateDisplay()
}

hidden [void] NavigateBack() {
$this.Services.Navigation.PopScreen()
}

# --- Lifecycle Methods ---
[void] OnEnter() {
$this.RefreshData()
$this.UpdateDisplay()
}

[void] OnExit() { }

[void] Cleanup() {
$this.Components.Clear()
$this.Children.Clear()
}
}

# --- END OF ORIGINAL FILE for screens\task-list-screen\task-list-screen.psm1 ---
