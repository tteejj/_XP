# Test minimal TaskScreen

class TaskScreenLazyGitTest : Screen {
    TaskScreenLazyGitTest() {
        $this.Title = "TEST"
    }
    
    [string] Render() {
        return "Test screen working"
    }
}