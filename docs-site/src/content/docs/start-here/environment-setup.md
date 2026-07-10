---
title: Environment setup
---

## Clone and open the container

```bash
gh repo clone NikoMix/microhack-infra-and-database-migration
cd microhack-infra-and-database-migration
code .
```

In Visual Studio Code, choose **Dev Containers: Reopen in Container** or create a Codespace from GitHub. Wait for post-create tasks to finish.

## Authenticate

```bash
az login
az account show --query "{name:name,id:id,tenant:tenantId}" -o table
gh auth login
gh auth status
azd auth login
```

## Select an inference provider

```bash
export INFERENCE_PROVIDER=github_models
export AZURE_LOCATION=swedencentral
```

PowerShell users can use:

```powershell
$env:INFERENCE_PROVIDER = 'github_models'
$env:AZURE_LOCATION = 'swedencentral'
```

## Enable MCP servers and agents

1. In VS Code, open Copilot Chat and confirm agent mode is available.
2. Add the trusted Azure MCP and GitHub MCP server configurations for the repo or user profile.
3. Verify the custom agents are visible: **Engagement Copilot**, **IaC Architect**, and **Schema Converter**.
4. Run package smoke tests from the repository root:

```bash
python -m migration_copilot --help
mcopilot assess --help
mcopilot architect --help
mcopilot convert --help
```

## Validation

- `az account show` returns the expected subscription.
- `gh auth status` reports an authenticated account.
- Copilot Chat can see the repository, enabled MCP tools, and the three custom agents.
- `INFERENCE_PROVIDER` is set in the active shell before Challenge 00.
