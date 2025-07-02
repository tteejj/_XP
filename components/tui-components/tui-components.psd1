@{
    RootModule = 'tui-components.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'd4e5f6g7-h8i9-0123-defg-456789012345'
    Author = 'PMC Terminal'
    Description = 'Basic TUI components - Label, Button, TextBox, CheckBox, RadioButton'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        @{ ModuleName = '.\ui-classes.psd1'; RequiredVersion = '1.0.0' }
    )
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    ClassesToExport = @(
        'LabelComponent',
        'ButtonComponent',
        'TextBoxComponent',
        'CheckBoxComponent',
        'RadioButtonComponent'
    )
}
