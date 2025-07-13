# FILES TO FIX - IN ORDER

## INSTRUCTIONS
1. Give the LLM the contents of `LLM_FIX_INSTRUCTIONS.md` first
2. Then give it each file below, one at a time
3. Save the LLM's output as the fixed file
4. Test after fixing the first file (ASC.003_ThemeScreen.ps1) to see if the app starts

## FILE LIST

### PRIORITY 1 - Fix this FIRST (it's blocking startup):
1. `Screens\ASC.003_ThemeScreen.ps1`

### PRIORITY 2 - Base Classes (foundation):
2. `Base\ABC.004_UIElement.ps1`
3. `Base\ABC.002_TuiCell.ps1`

### PRIORITY 3 - Components:
4. `Components\ACO.001_LabelComponent.ps1`
5. `Components\ACO.003_TextBoxComponent.ps1`
6. `Components\ACO.006_MultilineTextBoxComponent.ps1`
7. `Components\ACO.007_NumericInputComponent.ps1`
8. `Components\ACO.008_DateInputComponent.ps1`
9. `Components\ACO.011_Panel.ps1`
10. `Components\ACO.013_GroupPanel.ps1`
11. `Components\ACO.014_ListBox.ps1`
12. `Components\ACO.021_NavigationMenu.ps1`
13. `Components\ACO.022_DataGridComponent.ps1`

### PRIORITY 4 - Screens:
14. `Screens\ASC.001_DashboardScreen.ps1`
15. `Screens\ASC.002_TaskListScreen.ps1`
16. `Screens\ASC.004_NewTaskScreen.ps1`
17. `Screens\ASC.005_EditTaskScreen.ps1`
18. `Screens\ASC.005_FileCommanderScreen.ps1`
19. `Screens\ASC.006_TextEditorScreen.ps1`
20. `Screens\ASC.007_ProjectInfoScreen.ps1`
21. `Screens\ASC.008_ProjectsListScreen.ps1`

### PRIORITY 5 - Functions:
22. `Functions\AFU.004_ThemeFunctions.ps1`

## NOTES
- Start with file #1 (ThemeScreen) since that's what's preventing the app from starting
- After fixing it, test if the app runs
- If it runs but has issues, continue with the other files
- The .txt versions of these files may also need fixing if they're actual code files
