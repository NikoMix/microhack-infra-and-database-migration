#!/usr/bin/env bash
# Run the full local quality suite (parity with .github/workflows/ci.yml).
# Skips areas whose source is not present yet. Enforces zero known vulnerabilities.
set -uo pipefail
fail=0
run() { echo ""; echo "==> $1"; shift; "$@" || { echo "   FAILED"; fail=1; }; }

if command -v npx >/dev/null 2>&1; then
  run "markdownlint" npx --yes markdownlint-cli2 "**/*.md" "**/*.mdx"
fi

if command -v vale >/dev/null 2>&1; then
  vale sync >/dev/null 2>&1 || true
  run "vale prose lint" vale .
fi

if [ -f docs-site/package.json ]; then
  run "docs-site: npm ci"    bash -c 'cd docs-site && npm ci'
  run "docs-site: build"     bash -c 'cd docs-site && npm run build'
  # Enforce the zero-known-vulnerabilities requirement (moderate and above).
  run "docs-site: npm audit" bash -c 'cd docs-site && npm audit --audit-level=moderate'
fi

if [ -f src/pyproject.toml ]; then
  PY="python"; command -v python >/dev/null 2>&1 || PY="python3"
  run "python: install"   bash -c "cd src && $PY -m pip install -e '.[dev]' >/dev/null"
  run "python: ruff"      bash -c "cd src && $PY -m ruff check ."
  run "python: mypy"      bash -c "cd src && $PY -m mypy ."
  run "python: pytest"    bash -c "cd src && $PY -m pytest -q"
  run "python: pip-audit" bash -c "cd src && $PY -m pip install pip-audit >/dev/null && $PY -m pip_audit"
fi

if [ -f infra/bicep/main.bicep ]; then
  run "bicep build" bash -c "set -e; find infra/bicep -name '*.bicep' -print0 | while IFS= read -r -d '' f; do az bicep build --file \"\$f\" --stdout >/dev/null; done"
fi

echo ""
if [ $fail -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $fail
