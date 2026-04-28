# Dot source private functions
$privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
    } catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

# Dot source public functions
$publicFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
    } catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

# Export public functions and their aliases
Export-ModuleMember -Function ($publicFunctions | ForEach-Object { $_.BaseName }) -Alias *

# Load bundled web assets for Start-TeaWebServer (Phase 7).
# SilentlyContinue: module works normally without these; they are only required for web serving.
$script:XtermJs       = Get-Content -Path "$PSScriptRoot/Private/Web/xterm.min.js"       -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
$script:XtermAddonFit = Get-Content -Path "$PSScriptRoot/Private/Web/xterm-addon-fit.min.js" -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
$script:XtermCss      = Get-Content -Path "$PSScriptRoot/Private/Web/xterm.css"          -Raw -Encoding UTF8 -ErrorAction SilentlyContinue