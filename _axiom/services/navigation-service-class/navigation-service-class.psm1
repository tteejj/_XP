# navigation-service-class.psm1

# Contains only the NavigationService and ScreenFactory class definitions.

using module ui-classes
using module logger
using module exceptions
using module event-system







class ScreenFactory {

hidden [hashtable] $Services

hidden [hashtable] $ScreenTypes = @{}



ScreenFactory([hashtable]$services) {

$this.Services = $services ?? (throw [System.ArgumentNullException]::new("services"))

Write-Log -Level Debug -Message "ScreenFactory initialized"

}



[void] RegisterScreen([string]$name, [type]$screenType) {

if (-not ($screenType -eq [Screen] -or $screenType.IsSubclassOf([Screen]))) {

throw "Screen type '$($screenType.Name)' must inherit from the Screen class."

}

$this.ScreenTypes[$name] = $screenType

Write-Log -Level Info -Message "Registered screen factory: $name -> $($screenType.Name)"

}



[Screen] CreateScreen([string]$screenName, [hashtable]$parameters) {

$screenType = $this.ScreenTypes[$screenName]

if (-not $screenType) {

throw "Unknown screen type: '$screenName'. Available screens: $($this.ScreenTypes.Keys -join ', ')"

}



try {

$screen = $screenType::new($this.Services)

if ($parameters) {

foreach ($key in $parameters.Keys) {

$screen.State[$key] = $parameters[$key]

}

}

Write-Log -Level Info -Message "Created screen: $screenName"

return $screen

} catch {

Write-Log -Level Error -Message "Failed to create screen '$screenName': $($_.Exception.Message)"

throw

}

}



[string[]] GetRegisteredScreens() {

return @($this.ScreenTypes.Keys)

}

}



class NavigationService {

[System.Collections.Generic.Stack[Screen]] $ScreenStack

[ScreenFactory] $ScreenFactory

[Screen] $CurrentScreen

[hashtable] $Services

[hashtable] $RouteMap = @{}



NavigationService([hashtable]$services) {

$this.Services = $services ?? (throw [System.ArgumentNullException]::new("services"))

$this.ScreenStack = [System.Collections.Generic.Stack[Screen]]::new()

$this.ScreenFactory = [ScreenFactory]::new($services)

$this.InitializeRoutes()

Write-Log -Level Info -Message "NavigationService initialized"

}



hidden [void] InitializeRoutes() {

$this.RouteMap = @{

"/" = "DashboardScreen"

"/dashboard" = "DashboardScreen"

"/tasks" = "TaskListScreen"

}

Write-Log -Level Debug -Message "Routes initialized: $($this.RouteMap.Keys -join ', ')"

}



[void] RegisterScreenClass([string]$name, [type]$screenType) {

$this.ScreenFactory.RegisterScreen($name, $screenType)

}



[void] GoTo([string]$path, [hashtable]$parameters = @{}) {

Invoke-WithErrorHandling -Component "NavigationService" -Context "GoTo:$path" -ScriptBlock {

if ([string]::IsNullOrWhiteSpace($path)) {

throw [System.ArgumentException]::new("Path cannot be empty.")

}

if ($path -eq "/exit") {

$this.RequestExit()

return

}



$screenName = $this.RouteMap[$path]

if (-not $screenName) {

$availableRoutes = $this.RouteMap.Keys -join ', '

throw "Unknown route: '$path'. Available routes: $availableRoutes"

}



Write-Log -Level Info -Message "Navigating to: $path -> $screenName"

$this.PushScreen($screenName, $parameters)

}

}



[void] PushScreen([string]$screenName, [hashtable]$parameters = @{}) {

Invoke-WithErrorHandling -Component "NavigationService" -Context "PushScreen:$screenName" -ScriptBlock {

Write-Log -Level Info -Message "Pushing screen: $screenName"



if ($this.CurrentScreen) {

Write-Log -Level Debug -Message "Exiting current screen: $($this.CurrentScreen.Name)"

$this.CurrentScreen.OnExit()

$this.ScreenStack.Push($this.CurrentScreen)

}



Write-Log -Level Debug -Message "Creating new screen: $screenName"

$newScreen = $this.ScreenFactory.CreateScreen($screenName, $parameters)

$this.CurrentScreen = $newScreen



Write-Log -Level Debug -Message "Initializing screen: $screenName"

$newScreen.Initialize()

$newScreen.OnEnter()



if (Get-Command "Push-Screen" -ErrorAction SilentlyContinue) {

Write-Log -Level Debug -Message "Pushing screen to TUI engine"

Push-Screen -Screen $newScreen

} else {

if ($global:TuiState) {

$global:TuiState.CurrentScreen = $newScreen

Request-TuiRefresh

}

}



Publish-Event -EventName "Navigation.ScreenChanged" -Data @{ Screen = $screenName; Action = "Push" }

Write-Log -Level Info -Message "Successfully pushed screen: $screenName"

}

}



[bool] PopScreen() {

return Invoke-WithErrorHandling -Component "NavigationService" -Context "PopScreen" -ScriptBlock {

if ($this.ScreenStack.Count -eq 0) {

Write-Log -Level Warning -Message "Cannot pop screen: stack is empty"

return $false

}



Write-Log -Level Info -Message "Popping screen"

$this.CurrentScreen?.OnExit()

$this.CurrentScreen = $this.ScreenStack.Pop()

$this.CurrentScreen?.OnResume()



if (Get-Command "Pop-Screen" -ErrorAction SilentlyContinue) {

Pop-Screen

} else {

if ($global:TuiState) {

$global:TuiState.CurrentScreen = $this.CurrentScreen

Request-TuiRefresh

}

}



Publish-Event -EventName "Navigation.ScreenPopped" -Data @{ Screen = $this.CurrentScreen.Name }

return $true

}

}



[void] RequestExit() {

Write-Log -Level Info -Message "Exit requested"

while ($this.PopScreen()) {} # Pop all screens

$this.CurrentScreen?.OnExit()

if (Get-Command "Stop-TuiEngine" -ErrorAction SilentlyContinue) {

Stop-TuiEngine

}

Publish-Event -EventName "Application.Exit"

}



[Screen] GetCurrentScreen() { return $this.CurrentScreen }

[bool] IsValidRoute([string]$path) { return $this.RouteMap.ContainsKey($path) }



[void] ListRegisteredScreens() {

$screens = $this.ScreenFactory.GetRegisteredScreens()

Write-Log -Level Info -Message "Registered screens: $($screens -join ', ')"

Write-Host "Registered screens: $($screens -join ', ')" -ForegroundColor Green

}



[void] ListAvailableRoutes() {

$routes = $this.RouteMap.Keys

Write-Log -Level Info -Message "Available routes: $($routes -join ', ')"

Write-Host "Available routes: $($routes -join ', ')" -ForegroundColor Green

}

}
