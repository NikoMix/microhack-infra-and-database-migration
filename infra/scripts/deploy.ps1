[CmdletBinding()]
param(
    [string]$Prefix = "ttmh",
    [string]$Location = "swedencentral",
    [string]$Suffix = "",
    [string]$AdminObjectId = "",
    [string]$AdminUsername = "ttmhadmin",
    [string]$AdminPassword = "",
    [string]$AdminSourceAddressPrefix = "Internet",
    [string]$WorkloadRawBaseUrl = "https://raw.githubusercontent.com/<owner>/<repo>/<branch>",
    [string]$AadAdminObjectId = "",
    [string]$AadAdminLogin = "",
    [string]$PostgresqlAdminUsername = "ttmhpgadmin",
    [string]$PostgresqlAdminPassword = "",
    [string]$MysqlAdminUsername = "ttmhmysqladmin",
    [string]$MysqlAdminPassword = "",
    [switch]$SkipSourceEstate,
    [switch]$SkipTargets,
    [switch]$IncludeSqlMi,
    [switch]$DisableDefender
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$bicep = Join-Path $root "bicep"
if ([string]::IsNullOrWhiteSpace($Suffix)) {
    $Suffix = (az account show --query "id" -o tsv | ForEach-Object { $_.Replace("-", "").Substring(0, 6).ToLowerInvariant() })
}

$rgSource = "rg-$Prefix-source"
$rgPlatform = "rg-$Prefix-platform"
$rgData = "rg-$Prefix-data"
$rgAi = "rg-$Prefix-ai"
$enableDefenderValue = (-not $DisableDefender).ToString().ToLowerInvariant()

foreach ($rg in @($rgSource, $rgPlatform, $rgData, $rgAi)) {
    az group create --name $rg --location $Location --tags env=microhack workload=tailwind-migration --only-show-errors | Out-Null
}

Write-Host "What-if: platform"
az deployment sub what-if --location $Location --template-file (Join-Path $bicep "main.bicep") --parameters prefix=$Prefix location=$Location suffix=$Suffix adminObjectId=$AdminObjectId enableDefender=$enableDefenderValue
az deployment sub create --location $Location --template-file (Join-Path $bicep "main.bicep") --parameters prefix=$Prefix location=$Location suffix=$Suffix adminObjectId=$AdminObjectId enableDefender=$enableDefenderValue

if (-not $SkipSourceEstate) {
    if ([string]::IsNullOrWhiteSpace($AdminPassword)) { throw "AdminPassword is required unless -SkipSourceEstate is used." }
    Write-Host "What-if: source estate"
    az deployment group what-if --resource-group $rgSource --template-file (Join-Path $bicep "source-estate\main.bicep") --parameters prefix=$Prefix location=$Location adminUsername=$AdminUsername adminPassword=$AdminPassword adminSourceAddressPrefix=$AdminSourceAddressPrefix workloadRawBaseUrl=$WorkloadRawBaseUrl
    az deployment group create --resource-group $rgSource --template-file (Join-Path $bicep "source-estate\main.bicep") --parameters prefix=$Prefix location=$Location adminUsername=$AdminUsername adminPassword=$AdminPassword adminSourceAddressPrefix=$AdminSourceAddressPrefix workloadRawBaseUrl=$WorkloadRawBaseUrl
}

if (-not $SkipTargets) {
    if ([string]::IsNullOrWhiteSpace($AadAdminObjectId) -or [string]::IsNullOrWhiteSpace($AadAdminLogin) -or [string]::IsNullOrWhiteSpace($PostgresqlAdminPassword) -or [string]::IsNullOrWhiteSpace($MysqlAdminPassword)) {
        throw "AadAdminObjectId, AadAdminLogin, PostgresqlAdminPassword, and MysqlAdminPassword are required unless -SkipTargets is used."
    }
    Write-Host "What-if: data targets"
    az deployment group what-if --resource-group $rgData --template-file (Join-Path $bicep "targets\main.bicep") --parameters prefix=$Prefix location=$Location suffix=$Suffix platformResourceGroupName=$rgPlatform aadAdminObjectId=$AadAdminObjectId aadAdminLogin=$AadAdminLogin postgresqlAdminUsername=$PostgresqlAdminUsername postgresqlAdminPassword=$PostgresqlAdminPassword mysqlAdminUsername=$MysqlAdminUsername mysqlAdminPassword=$MysqlAdminPassword
    az deployment group create --resource-group $rgData --template-file (Join-Path $bicep "targets\main.bicep") --parameters prefix=$Prefix location=$Location suffix=$Suffix platformResourceGroupName=$rgPlatform aadAdminObjectId=$AadAdminObjectId aadAdminLogin=$AadAdminLogin postgresqlAdminUsername=$PostgresqlAdminUsername postgresqlAdminPassword=$PostgresqlAdminPassword mysqlAdminUsername=$MysqlAdminUsername mysqlAdminPassword=$MysqlAdminPassword
}

if ($IncludeSqlMi) {
    if ([string]::IsNullOrWhiteSpace($AdminPassword)) { throw "AdminPassword is required for SQL MI administratorLoginPassword." }
    Write-Warning "SQL MI provisioning commonly takes 4-6 hours and can incur significant cost."
    az deployment group what-if --resource-group $rgData --template-file (Join-Path $bicep "targets\sqlmi.bicep") --parameters prefix=$Prefix location=$Location suffix=$Suffix platformResourceGroupName=$rgPlatform administratorLogin=$AdminUsername administratorLoginPassword=$AdminPassword aadAdminObjectId=$AadAdminObjectId aadAdminLogin=$AadAdminLogin
    az deployment group create --resource-group $rgData --template-file (Join-Path $bicep "targets\sqlmi.bicep") --parameters prefix=$Prefix location=$Location suffix=$Suffix platformResourceGroupName=$rgPlatform administratorLogin=$AdminUsername administratorLoginPassword=$AdminPassword aadAdminObjectId=$AadAdminObjectId aadAdminLogin=$AadAdminLogin
}
