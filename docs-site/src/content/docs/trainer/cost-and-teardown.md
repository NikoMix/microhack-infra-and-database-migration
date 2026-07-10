---
title: Cost and teardown
---

## Estimated classroom cost

Costs vary by region, runtime, and trainer choices. For a one-day pair using small VMs, low-tier Azure SQL Database, burstable Flexible Servers, Log Analytics, Key Vault, Backup, and short-lived Data Factory activity, plan for a low tens-of-dollars range per pair. SQL Managed Instance and Azure-SSIS IR are excluded from per-pair estimates because they should be pre-provisioned shared or demonstrated from evidence.

## Cost controls

- Use the lowest SKU that still demonstrates the concept.
- Stop test VMs and Azure-SSIS IR when not actively used.
- Prefer locally redundant backup for classroom labs.
- Delete local database dumps after validation.
- Keep budgets and cost alerts enabled on training subscriptions.

## Teardown

Run the repository teardown script from the repo root after evidence is approved:

```powershell
.\infra\scripts\teardown.ps1 -Prefix ttmh -Force
```

Or use the Bash equivalent if available:

```bash
PREFIX=ttmh FORCE=true ./infra/scripts/teardown.sh
```

Validate cleanup:

```bash
az group list --query "[?starts_with(name, 'rg-ttmh-')].name" -o table
```

Do not delete shared trainer resources unless your delivery owner confirms they are not reused by another cohort.
