[CmdletBinding()]
param(
    [string]$SqlInstance = $env:TAILWIND_SQL_INSTANCE,
    [string]$PackageRoot = 'C:\Tailwind\ssis'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SqlInstance)) {
    $SqlInstance = 'localhost'
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-Tool {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$CandidatePaths = @()
    )

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    foreach ($candidate in $CandidatePaths) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

$sqlcmd = Find-Tool -Name 'sqlcmd.exe' -CandidatePaths @(
    'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe',
    'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\sqlcmd.exe',
    'C:\Program Files\Microsoft SQL Server\150\Tools\Binn\sqlcmd.exe'
)

if (-not $sqlcmd) {
    throw 'sqlcmd.exe was not found. Install SQL Server command-line tools before running this script.'
}

function Invoke-SqlFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    Write-Host "Applying $Path to $SqlInstance"
    & $sqlcmd -S $SqlInstance -E -b -I -i $Path
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd failed for $Path with exit code $LASTEXITCODE"
    }
}

New-Item -ItemType Directory -Force -Path $PackageRoot | Out-Null
Copy-Item -Path (Join-Path $scriptRoot 'ssis\*.dtsx') -Destination $PackageRoot -Force

Invoke-SqlFile -Path (Join-Path $scriptRoot 'schema.sql')
Invoke-SqlFile -Path (Join-Path $scriptRoot 'seed.sql')
Invoke-SqlFile -Path (Join-Path $scriptRoot 'agent-jobs.sql')

$dtutil = Find-Tool -Name 'dtutil.exe' -CandidatePaths @(
    'C:\Program Files\Microsoft SQL Server\150\DTS\Binn\dtutil.exe',
    'C:\Program Files\Microsoft SQL Server\140\DTS\Binn\dtutil.exe'
)

if ($dtutil) {
    foreach ($package in Get-ChildItem -Path $PackageRoot -Filter '*.dtsx') {
        $packageName = [System.IO.Path]::GetFileNameWithoutExtension($package.Name)
        Write-Host "Deploying $($package.FullName) to MSDB package store as $packageName"
        & $dtutil /SQL $packageName /DELETE /QUIET 2>$null
        & $dtutil /FILE $package.FullName /COPY "SQL;$packageName" /QUIET
        if ($LASTEXITCODE -ne 0) {
            throw "dtutil failed for $($package.FullName) with exit code $LASTEXITCODE"
        }
    }
}
else {
    Write-Warning 'dtutil.exe was not found; packages were copied to the file system only.'
}

Write-Host 'Tailwind SQL Server workload installation completed.'
