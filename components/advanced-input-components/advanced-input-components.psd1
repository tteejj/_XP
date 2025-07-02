@{
    RootModule = 'advanced-input-components.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f6g7h8i9-j0k1-2345-fghi-678901234567'
    Author = 'PMC Terminal'
    Description = 'Advanced input components - MultilineTextBox, NumericInput, DateInput, ComboBox'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        @{ ModuleName = 'ui-classes'; ModuleVersion = '1.0.0' }
    )
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    ClassesToExport = @(
        'MultilineTextBoxComponent',
        'NumericInputComponent',
        'DateInputComponent',
        'ComboBoxComponent'
    )
}
