---
title: Troubleshooting
---

## Azure authentication

Run `az account show` and confirm the subscription. If the wrong tenant is selected, run `az login --tenant <tenant-id>` and set the expected subscription.

## Azure Migrate discovery gaps

Check that the appliance or imported inventory can see each source host. For the classroom path, compare against `vm-web`, `vm-app`, `vm-sql`, `vm-pg`, and `vm-mysql`.

## SQL assessment confusion

Use Azure Migrate for migration planning and the MSSQL/Azure SQL migration extension flow for SQL Server feature compatibility and target assessment. Keep both outputs.

## Long-running SQL MI or SSIS IR

Switch to trainer-provisioned resources or evidence snapshots. Teach the decision, validation, and operating model instead of waiting for provisioning.

## MDX or docs build failures

Run the docs commands from `docs-site`. Escape MDX-sensitive text such as angle brackets by wrapping it in backticks.
