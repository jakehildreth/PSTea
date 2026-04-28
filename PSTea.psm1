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

# Registry for the active web server driver.
# Uses AppDomain named data so the reference survives -Force reimport of the module
# (a $script: variable would be reset to $null on every reimport, losing the
# handle to the previous HttpListener and causing 'port already in use' errors).
# The slot is initialised only once per process; subsequent imports are no-ops.
if ($null -eq [System.AppDomain]::CurrentDomain.GetData('PSTea.DriverContainer')) {
    $driverContainer = [hashtable]::Synchronized(@{ Active = $null })
    [System.AppDomain]::CurrentDomain.SetData('PSTea.DriverContainer', $driverContainer)
}
$script:TeaDriverContainer = [System.AppDomain]::CurrentDomain.GetData('PSTea.DriverContainer')

# Belt 1 — clean up on explicit Remove-Module.
if ($null -ne $ExecutionContext.Module) {
    $ExecutionContext.Module.OnRemove = {
        $c = [System.AppDomain]::CurrentDomain.GetData('PSTea.DriverContainer')
        if ($null -ne $c -and $null -ne $c.Active) {
            try { & $c.Active.Stop } catch {}
            $c.Active = $null
        }
    }
}