# SQL Server Integration Services packages

These packages are intentionally small but well-formed DTSX XML samples for the WS4 source workload.

| Package | Purpose | Azure migration mapping |
| --- | --- | --- |
| `TailwindNightlyEtl.dtsx` | Recalculates order totals and models a nightly order-staging data flow. | Move to Azure-SSIS Integration Runtime in Azure Data Factory when package compatibility is required. |
| `TailwindStagingLoad.dtsx` | Prepares and loads a `StageOrders` table from the OLTP database. | Can be hosted on Azure-SSIS IR or rewritten as native ADF/Synapse pipelines. |

Microsoft Learn documents that Azure-SSIS Integration Runtime lets you deploy and run SSIS packages in Azure Data Factory. The SQL Agent job in `..\agent-jobs.sql` runs the package from the file system, which creates a migration decision: keep SQL Server Agent on Azure SQL Managed Instance or redesign scheduling with ADF, Elastic Jobs, or Automation.
