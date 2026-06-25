#!/usr/bin/env bash
# Run the full local quality suite. Skips areas whose source is not present yet.
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
  ( cd docs-site && npm ci && npm run build )
  [ $? -eq 0 ] || fail=1
fi

if [ -f src/pyproject.toml ]; then
  ( cd src && pip install -e ".[dev]" >/dev/null && ruff check . && mypy . && pytest -q )
  [ $? -eq 0 ] || fail=1
fi

if [ -f infra/bicep/main.bicep ]; then
  run "bicep build" az bicep build --file infra/bicep/main.bicep --stdout
fi

echo ""
if [ $fail -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $fail
