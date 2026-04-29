@{
    AliasesToExport=@('TeaBox',        'TeaCharSub',        'TeaComponent',        'TeaComponentMsg',        'TeaKeySub',        'TeaList',        'TeaPaginator',        'TeaProgressBar',        'TeaProgram',        'TeaRow',        'TeaSpinner',        'TeaStyle',        'TeaTable',        'TeaText',        'TeaTextarea',        'TeaTextInput',        'TeaTimerSub',        'TeaViewport',        'TeaWebServer',        'TeaWebSocketDriver')
    Author='Jake Hildreth'
    CmdletsToExport=@()
    CompanyName='Gilmour Technologies Ltd'
    CompatiblePSEditions=@('Desktop',        'Core')
    Copyright='(c) 2026 - 2026 Jake Hildreth, Gilmour Technologies Ltd. All rights reserved.'
    Description='A PowerShell implementation of The Elm Architecture (TEA). Heavily influenced by CharmBracelet''s BubbleTea and Textual.'
    FunctionsToExport=@('New-TeaWebSocketDriver',        'Start-TeaProgram',        'Start-TeaWebServer',        'New-TeaStyle',        'New-TeaCharSub',        'New-TeaKeySub',        'New-TeaTimerSub',        'New-TeaBox',        'New-TeaComponent',        'New-TeaComponentMsg',        'New-TeaList',        'New-TeaPaginator',        'New-TeaProgressBar',        'New-TeaRow',        'New-TeaSpinner',        'New-TeaTable',        'New-TeaText',        'New-TeaTextarea',        'New-TeaTextInput',        'New-TeaViewport')
    GUID='cbf58ecc-c67e-4772-b259-7a0bb30b03a6'
    ModuleVersion='2026.4.29.1542'
    PowerShellVersion='5.1'
    PrivateData=@{
        PSData=@{
            ExternalModuleDependencies=@('Microsoft.PowerShell.Utility',                'Microsoft.PowerShell.Management')
            ProjectUri='https://github.com/jakehildreth/PSTea'
            RequireLicenseAcceptance=$false
            Tags=@('TUI',                'Terminal',                'TEA',                'ElmArchitecture',                'BubbleTea',                'Windows',                'MacOS',                'Linux')
        }
    }
    RequiredModules=@('Microsoft.PowerShell.Utility',        'Microsoft.PowerShell.Management')
    RootModule='PSTea.psm1'
    VariablesToExport='*'
}
