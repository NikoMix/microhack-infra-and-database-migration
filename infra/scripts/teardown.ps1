[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Prefix = "ttmh",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$resourceGroups = @("rg-$Prefix-source", "rg-$Prefix-platform", "rg-$Prefix-data", "rg-$Prefix-ai")

if (-not $Force) {
    $answer = Read-Host "Delete resource groups $($resourceGroups -join ', ')? Type DELETE to continue"
    if ($answer -ne "DELETE") {
        Write-Host "Teardown cancelled."
        exit 0
    }
}

foreach ($rg in $resourceGroups) {
    $exists = az group exists --name $rg -o tsv
    if ($exists -eq "true") {
        Write-Host "Deleting $rg..."
        az group delete --name $rg --yes --no-wait
    }
}
