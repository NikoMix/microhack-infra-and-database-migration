<#
.SYNOPSIS
  Run the full local quality suite. Skips areas whose source is not present yet.
#>
$ErrorActionPreference = 'Continue'
$fail = $false

function Invoke-Check($name, [scriptblock]$block) {
  Write-Host "`n==> $name" -ForegroundColor Cyan
  & $block
  if ($LASTEXITCODE -ne 0) { Write-Host "   FAILED" -ForegroundColor Red; $script:fail = $true }
}

if (Get-Command npx -ErrorAction SilentlyContinue) {
  Invoke-Check 'markdownlint' { npx --yes markdownlint-cli2 "**/*.md" "**/*.mdx" }
}

if (Test-Path 'docs-site/package.json') {
  Invoke-Check 'docs-site build' { Push-Location docs-site; npm ci; npm run build; Pop-Location }
}

if (Test-Path 'src/pyproject.toml') {
  Invoke-Check 'python' {
    Push-Location src; pip install -e ".[dev]" | Out-Null; ruff check .; mypy .; pytest -q; Pop-Location
  }
}

if (Test-Path 'infra/bicep/main.bicep') {
  Invoke-Check 'bicep build' { az bicep build --file infra/bicep/main.bicep --stdout | Out-Null }
}

Write-Host ''
if (-not $fail) { Write-Host 'ALL CHECKS PASSED' -ForegroundColor Green; exit 0 }
else { Write-Host 'SOME CHECKS FAILED' -ForegroundColor Red; exit 1 }
