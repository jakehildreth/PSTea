param (
    # CalVer string to override the default yyyy.M.d.Hmm version.
    [string]$CalVer,
    [switch]$PublishToPSGallery,
    [string]$PSGalleryAPIPath,
    [string]$PSGalleryAPIKey
)

# The VS Code PowerShell Extension pre-loads PSScriptAnalyzer into the host
# process. PSPublishModule imports PSScriptAnalyzer internally, and loading a
# second copy of its assembly into the same appdomain throws an assembly-already-
# loaded error. Re-invoke in a clean pwsh -NoProfile child process to avoid it.
if ($Host.Name -eq 'Visual Studio Code Host' -or
    $null -ne [System.AppDomain]::CurrentDomain.GetAssemblies().Where({
        $_.GetName().Name -eq 'Microsoft.Windows.PowerShell.ScriptAnalyzer'
    }, 'First')[0]) {
    Write-Host 'Re-invoking in a clean pwsh process to avoid PSScriptAnalyzer assembly conflict...'
    $passThrough = @('-NoProfile', '-File', $PSCommandPath)
    if ($CalVer)            { $passThrough += '-CalVer';            $passThrough += $CalVer }
    if ($PublishToPSGallery){ $passThrough += '-PublishToPSGallery' }
    if ($PSGalleryAPIPath)  { $passThrough += '-PSGalleryAPIPath';  $passThrough += $PSGalleryAPIPath }
    if ($PSGalleryAPIKey)   { $passThrough += '-PSGalleryAPIKey';   $passThrough += $PSGalleryAPIKey }
    & pwsh @passThrough
    exit $LASTEXITCODE
}

if (Get-Module -Name 'PSPublishModule' -ListAvailable) {
    Write-Verbose 'PSPublishModule is installed.'
} else {
    Write-Verbose 'PSPublishModule is not installed. Attempting installation.'
    try {
        Install-Module -Name Pester          -AllowClobber -Scope CurrentUser -SkipPublisherCheck -Force
        Install-Module -Name PSScriptAnalyzer -AllowClobber -Scope CurrentUser -Force
        Install-Module -Name PSPublishModule  -AllowClobber -MaximumVersion 2.0.27 -Scope CurrentUser -Force
    } catch {
        Write-Error "PSPublishModule installation failed. $_"
    }
}

Import-Module -Name PSPublishModule -Force

$CopyrightYear = if ($CalVer) { $CalVer.Split('.')[0] } else { (Get-Date -Format yyyy) }

Build-Module -ModuleName 'PSTea' {

    $Manifest = [ordered] @{
        ModuleVersion        = if ($CalVer) { $CalVer } else { (Get-Date -Format yyyy.M.d.Hmm) }
        CompatiblePSEditions = @('Desktop', 'Core')
        GUID                 = 'cbf58ecc-c67e-4772-b259-7a0bb30b03a6'
        Author               = 'Jake Hildreth'
        CompanyName          = 'Gilmour Technologies Ltd'
        Copyright            = "(c) 2026 - $CopyrightYear Jake Hildreth, Gilmour Technologies Ltd. All rights reserved."
        Description          = "A PowerShell implementation of The Elm Architecture (TEA). Heavily influenced by CharmBracelet's BubbleTea and Textual."
        PowerShellVersion    = '5.1'
        Tags                 = @('TUI', 'Terminal', 'TEA', 'ElmArchitecture', 'BubbleTea', 'Windows', 'MacOS', 'Linux')
        ProjectUri           = 'https://github.com/jakehildreth/PSTea'
        # PSPublishModule's alias-folder scan only detects top-level Set-Alias calls.
        # PSTea aliases are inside function bodies, so they must be listed explicitly.
        AliasesToExport      = @(
            'TeaBox', 'TeaCharSub', 'TeaComponent', 'TeaComponentMsg', 'TeaKeySub',
            'TeaList', 'TeaPaginator', 'TeaProgressBar', 'TeaProgram', 'TeaRow',
            'TeaSpinner', 'TeaStyle', 'TeaTable', 'TeaText', 'TeaTextarea',
            'TeaTextInput', 'TeaTimerSub', 'TeaViewport', 'TeaWebServer', 'TeaWebSocketDriver'
        )
    }
    New-ConfigurationManifest @Manifest

    New-ConfigurationModule -Type ExternalModule -Name 'Microsoft.PowerShell.Utility'
    New-ConfigurationModule -Type ExternalModule -Name 'Microsoft.PowerShell.Management'

    New-ConfigurationModuleSkip -IgnoreFunctionName 'Invoke-Formatter', 'Find-Module', 'dbg' -IgnoreModuleName 'platyPS'

    New-ConfigurationInformation `
        -FunctionsToExportFolder 'Public' `
        -AliasesToExportFolder   'Public' `
        -IncludePS1              'Private', 'Public' `
        -IncludeAll              @('Private\Web\') `
        -IncludeRoot             @('*.psm1', '*.psd1', 'LICENSE*', 'README.md')

    $ConfigurationFormat = [ordered] @{
        RemoveComments = $false

        PlaceOpenBraceEnable             = $true
        PlaceOpenBraceOnSameLine         = $true
        PlaceOpenBraceNewLineAfter       = $true
        PlaceOpenBraceIgnoreOneLineBlock = $false

        PlaceCloseBraceEnable             = $true
        PlaceCloseBraceNewLineAfter       = $true
        PlaceCloseBraceIgnoreOneLineBlock = $false
        PlaceCloseBraceNoEmptyLineBefore  = $true

        UseConsistentIndentationEnable              = $true
        UseConsistentIndentationKind                = 'space'
        UseConsistentIndentationPipelineIndentation = 'IncreaseIndentationAfterEveryPipeline'
        UseConsistentIndentationIndentationSize     = 4

        UseConsistentWhitespaceEnable          = $true
        UseConsistentWhitespaceCheckInnerBrace = $true
        UseConsistentWhitespaceCheckOpenBrace  = $true
        UseConsistentWhitespaceCheckOpenParen  = $true
        UseConsistentWhitespaceCheckOperator   = $true
        UseConsistentWhitespaceCheckPipe       = $true
        UseConsistentWhitespaceCheckSeparator  = $true

        AlignAssignmentStatementEnable         = $true
        AlignAssignmentStatementCheckHashtable = $true

        UseCorrectCasingEnable = $true
    }

    New-ConfigurationFormat -ApplyTo 'OnMergePSM1' -Sort None @ConfigurationFormat
    New-ConfigurationFormat -ApplyTo 'DefaultPSM1' -EnableFormatting -Sort None
    New-ConfigurationFormat -ApplyTo 'OnMergePSD1' -PSD1Style 'Minimal'

    New-ConfigurationDocumentation -Enable:$false -StartClean -UpdateWhenNew -PathReadme 'Docs\Readme.md' -Path 'Docs'

    New-ConfigurationImportModule -ImportSelf -ImportRequiredModules

    New-ConfigurationBuild `
        -Enable:$true `
        -SignModule:$false `
        -DeleteTargetModuleBeforeBuild `
        -MergeModuleOnBuild `
        -MergeFunctionsFromApprovedModules `
        -DoNotAttemptToFixRelativePaths

    #New-ConfigurationArtefact -Type Unpacked -Enable -Path "$PSScriptRoot\..\Artefacts\Unpacked"
    #New-ConfigurationArtefact -Type Packed   -Enable -Path "$PSScriptRoot\..\Artefacts\Packed" -IncludeTagName

    if ($PublishToPSGallery) {
        if ($PSGalleryAPIKey) {
            New-ConfigurationPublish -Type PowerShellGallery -ApiKey $PSGalleryAPIKey -Enabled:$true
        } elseif ($PSGalleryAPIPath) {
            New-ConfigurationPublish -Type PowerShellGallery -FilePath $PSGalleryAPIPath -Enabled:$true
        } else {
            Write-Error 'PublishToPSGallery specified but neither PSGalleryAPIKey nor PSGalleryAPIPath provided.'
        }
    }
}
