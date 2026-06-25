<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# 🚀 Migrate &amp; Modernize to Azure — MicroHack

### A 1-day, classroom-led **Train-the-Trainer** hands-on lab covering every **Module B** requirement of the *Infrastructure &amp; Database Migration to Microsoft Azure* Advanced Specialization — accelerated by **GitHub Copilot agents, skills &amp; MCP servers**.

[![Deploy Docs](https://github.com/NikoMix/microhack-infra-and-database-migration/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/NikoMix/microhack-infra-and-database-migration/actions/workflows/deploy-pages.yml)
[![CI](https://github.com/NikoMix/microhack-infra-and-database-migration/actions/workflows/ci.yml/badge.svg)](https://github.com/NikoMix/microhack-infra-and-database-migration/actions/workflows/ci.yml)
[![CodeQL](https://github.com/NikoMix/microhack-infra-and-database-migration/actions/workflows/codeql.yml/badge.svg)](https://github.com/NikoMix/microhack-infra-and-database-migration/actions/workflows/codeql.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## 🎯 What this is

This repository is a **productised, reusable microhack** that a trainer can deliver in a single
classroom day. Attendees migrate a fictional customer estate (**Tailwind Traders**) to Microsoft
Azure across the three Module B migration pillars — **IaaS rehost**, **Azure SQL family**, and
**open-source database PaaS** — using the newest Azure migration tooling and a custom **multi-agent
AI assistant** surfaced through GitHub Copilot.

It is built **Train-the-Trainer**: every challenge ships with a student guide *and* a facilitator
guide (timing, talk track, common pitfalls, solution key).

## 🧭 Module B coverage

| Control | Where |
|---|---|
| **B.1.1** Migration Delivery Capability | Challenges 01–05 (rehost + replatform + refactor) |
| **B.2.1 / B.2.2** ACR Performance &amp; Customer Diversity | Challenge 06 + slides |
| **B.3.1** Certifications (AZ-104 / AZ-305 / DP-300 / AZ-800-801) | Closing block |
| **B.4.1 / B.4.2** Audit Readiness &amp; Partner Onboarding Assets | Challenge 06 (AI-generated evidence pack) |

## 🗺️ The day at a glance

| # | Challenge | Pillar / Control |
|---|---|---|
| 00 | Setup &amp; Source Estate | B.1.1 |
| 01 | Discovery &amp; Assessment (Azure Migrate + AI Engagement Copilot) | B.1.1 |
| 02 | Landing Zone via **agentic IaC** (Bicep AVM) | B.1.1 |
| 03 | IaaS Rehost (Azure Migrate Server Migration) | Pillar 1 |
| 04 | Azure SQL Family (SQL DB, **SSIS→ADF**, **SQL Agent→Elastic Jobs**, SQL MI) | Pillar 2 |
| 05 | OSS DB PaaS (PostgreSQL Flex, MySQL Flex) | Pillar 3 |
| 06 | Cutover, Audit Evidence &amp; Hypercare (AI-generated) | B.2 / B.3 / B.4 |

## 🤖 AI &amp; Copilot surface

- **Multi-agent system** (`src/migration_copilot/`): an Engagement Copilot, an Agentic IaC Architect,
  and a Schema/Artifact Converter — built on the MIT-licensed **Microsoft Agent Framework**.
- **Modular inference** — switch between **Azure AI Foundry**, **Azure OpenAI**, and **GitHub Models**
  with one environment variable.
- **GitHub Copilot custom agents &amp; skills** (`.github/agents/`, `.github/skills/`) plus
  **MCP servers** (Azure MCP + GitHub MCP) wired for VS Code &amp; Copilot CLI.

## 🏁 Quick start

```bash
# 1. Open in GitHub Codespaces (recommended) or VS Code Dev Containers
# 2. Authenticate to Azure
az login
# 3. Follow the docs site
cd docs-site && npm install && npm run dev
```

Trainers: start with **`docs-site/src/content/docs/trainer/`** (facilitator guide + agenda).
Attendees: start with **Challenge 00**.

## 📁 Repository layout

```text
docs-site/    Astro + Starlight lab site (student + trainer guides)  → GitHub Pages
slides/       Marp classroom slide deck
infra/        Bicep AVM (source estate + landing zone + targets) + teardown scripts
src/          Multi-agent AI system with modular inference
workloads/    Sample SQL Server / PostgreSQL / MySQL workloads (+ SSIS + Agent jobs)
.github/      Copilot agents, skills, CI/CD, security
.mcp/         MCP server configuration
```

## ✅ Requirements

- A **GitHub account** (Codespaces + Copilot) and an **Azure subscription** with Owner rights.
- Ability to provision in a region that supports Azure AI Foundry models (e.g. **Sweden Central**).
- Familiarity with Azure fundamentals; programming experience is helpful but not required.

> 💸 **Cost-aware:** labs use low-cost SKUs, auto-shutdown, and ship **teardown scripts**. Estimated
> attendee spend is documented in the trainer cost guide. Always run teardown at the end of the day.

## 🤝 Contributing &amp; license

Contributions welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md). Licensed under [MIT](LICENSE).
All dependencies use permissive (MIT/Apache/BSD/ISC) licenses; no vendor-paid SDKs are required.