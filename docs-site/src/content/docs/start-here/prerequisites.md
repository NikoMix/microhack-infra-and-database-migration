---
title: Prerequisites
---

## Accounts and access

- One Azure subscription per pair. Use a sandbox or sponsor subscription where the trainer can create resource groups, virtual networks, VMs, Azure Migrate projects, SQL resources, Flexible Servers, Data Factory, Key Vault, Log Analytics, Defender for Cloud plans, Recovery Services vaults, and Azure Arc registrations.
- A GitHub account with access to the repository and GitHub Copilot.
- Tenant consent for Azure CLI, Visual Studio Code sign-in, GitHub CLI, and MCP server authentication.

## Cost guardrails

| Resource | Classroom default |
| --- | --- |
| Source VMs | Small B-series or D-series sizes |
| Azure SQL Database | Basic, Serverless, or low vCore General Purpose |
| SQL Managed Instance | Pre-provisioned demo instance only |
| PostgreSQL Flexible Server | Burstable tier where supported |
| MySQL Flexible Server | Burstable tier where supported |
| Azure-SSIS IR | Start only for the demo window, then stop |

SQL Managed Instance and Azure-SSIS IR can take hours or create meaningful cost. Pre-provision them for demonstrations and point students at shared evidence.

## Workstation or Codespaces

- GitHub Codespaces or the repository devcontainer.
- Node.js 24, Azure CLI, GitHub CLI, and Azure Developer CLI.
- Visual Studio Code with GitHub Copilot, GitHub Copilot Chat, Bicep, Azure Resources, SQL Server (MSSQL), Azure Account, and Markdown/Marp tooling.
- A browser profile that can access the Azure portal and GitHub.

## AI and MCP prerequisites

Choose one `INFERENCE_PROVIDER` for the migration Copilot package before class: `github_models`, `azure_openai`, or `foundry`. Enable Azure MCP and GitHub MCP servers only from trusted publishers, then validate that Copilot can list tools and access the repository context.
