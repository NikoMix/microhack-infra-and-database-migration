# Tailwind Traders sample workloads

WS4 provides synthetic source workloads for a one-day Azure migration Train-the-Trainer microhack. The scripts are idempotent, unattended, and intended for VM extension execution by the infrastructure workstream.

| Workload | Source host | Demonstrates | Migration decision |
| --- | --- | --- | --- |
| SQL Server `TailwindOLTP` and `TailwindRef` | `vm-sql` | OLTP tables, indexes, stored procedures, reference data, SQL Server Agent jobs, and SSIS packages. | Cross-database query, SQL Agent, and SSIS push attendees toward Azure SQL Managed Instance or deliberate redesign for Azure SQL Database plus ADF or Elastic Jobs. |
| PostgreSQL `TailwindCatalog` | `vm-pg` | Catalog schema, generated synthetic product data, a search function, and `pg_trgm` GIN indexing. | Validate extension support and choose Azure Database for PostgreSQL Flexible Server. |
| MySQL `TailwindSessions` | `vm-mysql` | Web sessions, clickstream events, carts, indexes, a trigger, and a funnel routine. | Replatform to Azure Database for MySQL Flexible Server. |
| Assessment export | `workloads\sample-data` | Azure Migrate-style synthetic JSON for all five servers. | Lets AI agents demo recommendations without a live Azure Migrate project. |

## Intentional incompatibilities and assessment talking points

- `workloads\sqlserver\schema.sql` creates `dbo.vwCustomerTaxProfile` in `TailwindOLTP` with three-part references to `TailwindRef.dbo.*`. This cross-database pattern is intentionally flagged as a condition for Azure SQL Database and a reason to consider Azure SQL Managed Instance.
- `workloads\sqlserver\agent-jobs.sql` uses `msdb.dbo.sp_add_job`, `sp_add_jobstep`, `sp_add_schedule`, and `sp_add_jobserver` to create `IndexMaintenanceNightly` and `TriggerNightlyEtl`. Later modules can compare Managed Instance Agent support with Elastic Jobs, Automation, or ADF schedules.
- `workloads\sqlserver\ssis\*.dtsx` are minimal DTSX package XML files representing nightly staging and Execute SQL tasks. Microsoft Learn documents running SSIS packages in Azure Data Factory by using Azure-SSIS Integration Runtime.
- `workloads\postgresql\schema.sql` enables `pg_trgm` and creates a GIN index for product search. This exercises extension-readiness checks before moving to Azure Database for PostgreSQL Flexible Server.
- All customer-like values are generated synthetic examples under `synthetic.tailwindtraders.example`; no real PII or secrets are included.

## Install entry points

- SQL Server on Windows: `powershell.exe -ExecutionPolicy Bypass -File workloads\sqlserver\install.ps1`
- PostgreSQL on Linux: `bash workloads/postgresql/install.sh`
- MySQL on Linux: `bash workloads/mysql/install.sh`

The SQL Server installer copies DTSX packages to `C:\Tailwind\ssis` and deploys them to MSDB when `dtutil.exe` is available. OSS install scripts use local admin tooling or environment-provided admin connections and do not hardcode passwords.

## Documentation grounding

- SQL Server Agent job scripting: [sp_add_job](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-job-transact-sql), [sp_add_jobstep](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-jobstep-transact-sql), and [sp_add_schedule](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-schedule-transact-sql).
- SSIS package migration path: [Azure-SSIS Integration Runtime in Azure Data Factory](https://learn.microsoft.com/en-us/azure/data-factory/concepts-integration-runtime#azure-ssis-integration-runtime).
- PostgreSQL extension readiness: [Extensions in Azure Database for PostgreSQL Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-extensions).
- MySQL target service: [Azure Database for MySQL Flexible Server](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/overview).
