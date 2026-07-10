[CmdletBinding()]
param(
    [string]$Location = "swedencentral",
    [switch]$Register
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed or not on PATH."
}

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    throw "Not logged in. Run 'az login' before deploying."
}

Write-Host "Azure account: $($account.user.name)"
Write-Host "Subscription: $($account.name) ($($account.id))"

$providers = @(
    "Microsoft.Sql",
    "Microsoft.DBforPostgreSQL",
    "Microsoft.DBforMySQL",
    "Microsoft.DataFactory",
    "Microsoft.Compute",
    "Microsoft.Network",
    "Microsoft.KeyVault",
    "Microsoft.OperationalInsights",
    "Microsoft.Security",
    "Microsoft.DevTestLab"
)

foreach ($provider in $providers) {
    $state = az provider show --namespace $provider --query registrationState -o tsv
    if ($state -ne "Registered") {
        if ($Register) {
            Write-Host "Registering $provider..."
            az provider register --namespace $provider --only-show-errors | Out-Null
        } else {
            Write-Warning "$provider is $state. Run with -Register or execute: az provider register --namespace $provider"
        }
    } else {
        Write-Host "$provider registered"
    }
}

$region = az account list-locations --query "[?name=='$Location'].{name:name,displayName:displayName}" -o json | ConvertFrom-Json
if (-not $region) {
    throw "Region '$Location' is not available to this subscription."
}

Write-Host "Region available: $($region.displayName) ($($region.name))"
Write-Host "Preflight complete. Quotas/SKU availability should still be checked in the target subscription before a class delivery."
