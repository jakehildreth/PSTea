# Dot source private functions
$privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
    } catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

# Dot source public functions
$publicFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue)
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
    } catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

# Export public functions and their aliases
Export-ModuleMember -Function ($publicFunctions | ForEach-Object { $_.BaseName }) -Alias *