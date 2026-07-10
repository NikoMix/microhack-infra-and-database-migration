---
title: Architecture reference
---

## Source to target view

```mermaid
flowchart LR
  subgraph Source[Simulated on-prem source estate]
    web[vm-web Windows IIS .NET]
    app[vm-app Ubuntu NGINX Node]
    sql[vm-sql SQL Server 2019]
    pg[vm-pg PostgreSQL 14]
    mysql[vm-mysql MySQL 8]
  end
  subgraph Plan[AI-assisted planning]
    migrate[Azure Migrate discovery and assessment]
    copilot[Copilot agents skills MCP]
    iac[Bicep AVM what-if]
  end
  subgraph Azure[Azure target]
    lz[Hub-spoke landing zone]
    iaas[Azure VMs Backup Arc]
    sqldb[Azure SQL Database]
    mi[Azure SQL Managed Instance demo]
    adf[ADF Azure-SSIS IR]
    pgfs[PostgreSQL Flexible Server]
    mysqlfs[MySQL Flexible Server]
  end
  web --> migrate --> iaas
  app --> migrate --> iaas
  sql --> migrate --> sqldb
  sql --> mi
  sql --> adf
  pg --> pgfs
  mysql --> mysqlfs
  copilot --> iac --> lz
  lz --> iaas
  lz --> sqldb
  lz --> mi
  lz --> pgfs
  lz --> mysqlfs
```

## Naming conventions

Use `rg-ttmh-*` for resource groups, `sql-ttmh-*` for Azure SQL Database servers, `sqlmi-ttmh-*` for Managed Instance demos, `psql-ttmh-*` for PostgreSQL Flexible Server, `mysql-ttmh-*` for MySQL Flexible Server, and `adf-ttmh-*` for Data Factory.
