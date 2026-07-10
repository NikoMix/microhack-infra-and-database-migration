#!/usr/bin/env bash
# Dev container bootstrap for the Migrate & Modernize to Azure MicroHack.
set -euo pipefail

echo "==> Installing Bicep CLI"
az bicep install || true

if [ -f docs-site/package.json ]; then
  echo "==> Installing docs-site dependencies"
  (cd docs-site && npm install)
fi

if [ -f src/pyproject.toml ]; then
  echo "==> Installing Python package (editable, with dev extras)"
  python -m pip install --upgrade pip
  pip install -e "src[dev]" || pip install -e src || true
fi

echo "==> Dev container ready. Trainers: docs-site/src/content/docs/trainer/. Attendees: Challenge 00."
