# Migration Copilot (WS3)

Python multi-agent workstream for the Tailwind Traders **Migrate & Modernize to Azure — MicroHack**. It reads `assessment.json` and writes canonical artifacts to `agent-output\<project>\`.

## Install

```powershell
cd src
python -m venv .venv
.\.venv\Scripts\python -m pip install -U pip
.\.venv\Scripts\python -m pip install -e .[dev]
```

## Run

```powershell
mcopilot assess --assessment tests\fixtures\assessment.json --project tailwind-traders
mcopilot architect --assessment tests\fixtures\assessment.json --project tailwind-traders --approve
mcopilot convert --assessment tests\fixtures\assessment.json --project tailwind-traders
mcopilot runbook --assessment tests\fixtures\assessment.json --project tailwind-traders
mcopilot evidence --assessment tests\fixtures\assessment.json --project tailwind-traders
```

Artifacts: `01-assessment.md`, `02-architecture.md`, `03-cost-estimate.md`, `04-iac-plan.md`, `05-runbook.md`, `06-evidence-index.md`.

## Modular inference

`migration_copilot.inference.get_chat_client()` selects `INFERENCE_PROVIDER`:

- `foundry`: `AZURE_AI_PROJECT_ENDPOINT`, `AZURE_AI_MODEL_DEPLOYMENT_NAME`, `DefaultAzureCredential`.
- `azure_openai`: `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_CHAT_DEPLOYMENT_NAME`, optional `AZURE_OPENAI_API_KEY`; no key uses `DefaultAzureCredential`.
- `github_models`: OpenAI-compatible `https://models.github.ai/inference` with `GITHUB_TOKEN` and `GITHUB_MODELS_MODEL`.

Secrets stay in environment variables or a local `.env`; use `.env.example` as the template.

## Public-preview doc deltas verified

The request referenced older preview classes (`ChatAgent`, `AzureOpenAIChatClient`, `AzureAIAgentClient`). Current Microsoft Agent Framework Python docs and samples (checked 2026-06-26) use:

- `from agent_framework import Agent` or `client.as_agent(...)` instead of `ChatAgent`.
- `from agent_framework.foundry import FoundryChatClient` for Foundry project endpoints.
- `from agent_framework.openai import OpenAIChatClient` for both GitHub Models and Azure OpenAI; Azure routing uses `azure_endpoint`, `model`, `api_version`, and `credential`/`api_key`.

The factory follows current docs and keeps compatibility fallbacks for older preview names.

## Test and audit

```powershell
cd src
ruff check .
ruff format --check .
mypy .
pytest -q
pip-audit
```

Tests use `tests\mock_chat.py` and do not call Azure, GitHub Models, or any model endpoint.

### Dependency &amp; audit note

To keep the dependency closure free of known vulnerabilities, this project pins the **explicit minimal Agent Framework provider packages** instead of the `agent-framework` meta-package:

- `agent-framework-core` — base runtime, agents, and workflows
- `agent-framework-openai` — `OpenAIChatClient` (GitHub Models + Azure OpenAI)
- `agent-framework-foundry` — `FoundryChatClient` (Azure AI Foundry projects)

The meta-package transitively pulls every optional integration (including `agent-framework-mem0` → `mem0ai`, which carries `CVE-2026-7597`). This lab never uses Mem0 memory, so depending on only the three packages above removes that integration entirely and `pip-audit` reports **no known vulnerabilities**. Add another `agent-framework-*` provider package only if a challenge requires it, and re-run `pip-audit`.
