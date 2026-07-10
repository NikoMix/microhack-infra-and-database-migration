<#
.SYNOPSIS
  Run the full local quality suite. Skips areas whose source is not present yet.
#>
$ErrorActionPreference = 'Continue'
$script:fail = $false

# Run a named check. Treats BOTH a thrown exception (e.g. command not found) and a
# non-zero native exit code as a failure, so checks can never pass silently.
function Invoke-Check($name, [scriptblock]$block) {
  Write-Host "`n==> $name" -ForegroundColor Cyan
  $global:LASTEXITCODE = 0
  try { & $block }
  catch { Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red; $script:fail = $true; return }
  if ($LASTEXITCODE -ne 0) { Write-Host "   FAILED (exit $LASTEXITCODE)" -ForegroundColor Red; $script:fail = $true }
}

# Resolve a Python interpreter: prefer the project venv, then python/py on PATH.
# Using "python -m <tool>" avoids depending on per-user Scripts dirs being on PATH.
function Get-Python {
  $venv = Join-Path $PSScriptRoot '..\src\.venv\Scripts\python.exe'
  if (Test-Path $venv) { return (Resolve-Path $venv).Path }
  if (Get-Command python -ErrorAction SilentlyContinue) { return 'python' }
  return 'py'
}

if (Get-Command npx -ErrorAction SilentlyContinue) {
  Invoke-Check 'markdownlint' { npx --yes markdownlint-cli2 "**/*.md" "**/*.mdx" }
}

if (Test-Path 'docs-site/package.json') {
  Invoke-Check 'docs-site: npm ci'    { Push-Location docs-site; try { npm ci } finally { Pop-Location } }
  Invoke-Check 'docs-site: build'     { Push-Location docs-site; try { npm run build } finally { Pop-Location } }
  # Enforce the zero-known-vulnerabilities requirement (moderate and above).
  Invoke-Check 'docs-site: npm audit' { Push-Location docs-site; try { npm audit --audit-level=moderate } finally { Pop-Location } }
}

if (Test-Path 'src/pyproject.toml') {
  $py = Get-Python
  Invoke-Check 'python: install'   { Push-Location src; try { & $py -m pip install -e ".[dev]" --quiet } finally { Pop-Location } }
  Invoke-Check 'python: ruff'      { Push-Location src; try { & $py -m ruff check . } finally { Pop-Location } }
  Invoke-Check 'python: mypy'      { Push-Location src; try { & $py -m mypy . } finally { Pop-Location } }
  Invoke-Check 'python: pytest'    { Push-Location src; try { & $py -m pytest -q } finally { Pop-Location } }
  Invoke-Check 'python: pip-audit' { Push-Location src; try { & $py -m pip install pip-audit --quiet; & $py -m pip_audit } finally { Pop-Location } }
}

if (Test-Path 'infra/bicep/main.bicep') {
  Invoke-Check 'bicep build' {
    Get-ChildItem -Recurse infra/bicep -Filter *.bicep | ForEach-Object {
      az bicep build --file $_.FullName --stdout | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "bicep build failed for $($_.FullName)" }
    }
  }
}

Write-Host ''
if (-not $script:fail) { Write-Host 'ALL CHECKS PASSED' -ForegroundColor Green; exit 0 }
else { Write-Host 'SOME CHECKS FAILED' -ForegroundColor Red; exit 1 }
