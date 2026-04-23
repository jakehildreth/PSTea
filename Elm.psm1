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