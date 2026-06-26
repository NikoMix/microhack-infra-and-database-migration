# Contributing

Thanks for helping improve the **Migrate & Modernize to Azure** MicroHack. We treat this repo as a
reusable training asset — improvements from every delivery are welcome.

## Ground rules

- **Permissive licenses only.** Any new dependency must be MIT / Apache-2.0 / BSD / ISC. No
  vendor-paid SDKs or trial-locked tools.
- **No secrets, ever.** Use `.env` (git-ignored) locally and GitHub Actions secrets in CI. The
  `gitleaks` workflow will fail the PR if a secret is detected.
- **Latest, patched dependencies.** Keep `package.json` / `pyproject.toml` current; `npm audit` and
  `pip-audit` must be clean.

## Local quality gates

| Area | Command |
| --- | --- |
| Docs site build | `cd docs-site && npm ci && npm run build` |
| Markdown lint | `npx markdownlint-cli2 "**/*.md" "**/*.mdx"` |
| Prose lint | `vale .` |
| Python lint/type | `cd src && ruff check . && mypy .` |
| Python tests | `cd src && pytest` |
| Bicep | `az bicep build --file infra/bicep/main.bicep` |

Run `tools/verify.ps1` (Windows) or `tools/verify.sh` (Linux/macOS) to execute the full suite.

## Workflow

1. Branch from `main` using a descriptive kebab-case name.
2. Make focused changes scoped to one workstream where possible.
3. Ensure all local quality gates pass.
4. Open a PR; link the relevant workstream issue. CI must be green before merge.

## Conventional commits

Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`,
`chore:`, `ci:`, `refactor:`, `test:`.
