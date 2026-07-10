---
title: Facilitator guide
---

## Challenge solution keys

| Challenge | Timing | Talk track | Common pitfalls | Expected output |
| --- | --- | --- | --- | --- |
| Ch00 | 45 min | Source estate is Azure-hosted only to simulate on-premises safely. | Wrong tenant, incomplete devcontainer, Copilot not signed in. | `rg-ttmh-source` with `vm-web`, `vm-app`, `vm-sql`, `vm-pg`, `vm-mysql`. |
| Ch01 | 55 min | Discovery is evidence that drives target choice. | Mixing server assessment with SQL compatibility assessment. | Azure Migrate assessment plus SQL blocker notes. |
| Ch02 | 60 min | Agents draft; humans approve. | Deploying without `what-if`, naming drift, missing private endpoints. | Approved `02-architecture.md` and `04-iac-plan.md`. |
| Ch03 | 65 min | Rehost can be a fast risk-reduction step. | Skipping test migration or completing final cutover too early. | Test migration works; Backup, Defender, and Arc evidence captured. |
| Ch04 | 75 min | Azure SQL Database and MI solve different compatibility needs. | Waiting for MI provisioning; ignoring SSIS or Agent jobs. | SQL DB validation, MI blocker rationale, SSIS and job target map. |
| Ch05 | 55 min | Flexible Server provides managed operations for OSS engines. | Open firewalls, secrets in scripts, leftover dumps. | PostgreSQL and MySQL counts validate on target. |
| Ch06 | 50 min | Technical work becomes specialization proof. | Runbook lacks owner, rollback, or communication columns. | `05-runbook.md`, `06-evidence-index.md`, and teach-back notes. |

## Facilitation pattern

For each challenge, demonstrate the first two minutes, let pairs work, then stop for a three-minute teach-back prompt: customer value, trainer warning, and evidence produced.
