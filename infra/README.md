# WS2 Infrastructure as Code

This folder deploys the **Migrate & Modernize to Azure — MicroHack**
infrastructure for Tailwind Traders.

## What gets deployed

Deployment order:

1. **Platform landing zone** (`rg-ttmh-platform`) from
   `bicep/main.bicep` and `bicep/platform.bicep`
   - Hub/spoke VNets: `vnet-ttmh-hub`, `vnet-ttmh-spoke`
   - Azure Bastion
   - Workload, private endpoint, SQL MI, PostgreSQL, and MySQL subnets
   - SQL MI delegated subnet baseline with NSG and route table
   - Key Vault `kv-ttmh-<suffix>` with soft-delete and purge protection
   - Log Analytics `log-ttmh-<suffix>`
   - Private DNS zones:
     - `privatelink.database.windows.net`
     - `privatelink.postgres.database.azure.com`
     - `privatelink.mysql.database.azure.com`
   - Optional Microsoft Defender for Cloud plan enablement
2. **Source estate** (`rg-ttmh-source`) from
   `bicep/source-estate/main.bicep`
   - `vm-web`: Windows Server 2022 + IIS bootstrap
   - `vm-app`: Ubuntu 22.04 + NGINX + Node API bootstrap
   - `vm-sql`: SQL Server 2019 Developer on Windows Server 2022
   - `vm-pg`: Ubuntu 22.04 + PostgreSQL workload script
   - `vm-mysql`: Ubuntu 22.04 + MySQL workload script
   - Standard_LRS OS disks, boot diagnostics, public IPs, and daily
     DevTest Labs auto-shutdown schedules
3. **Migration targets** (`rg-ttmh-data`) from
   `bicep/targets/main.bicep`
   - Azure SQL logical server `sql-ttmh-<suffix>` and DB `TailwindOLTP`
   - PostgreSQL Flexible Server `psql-ttmh-<suffix>` and DB
     `TailwindCatalog`
   - MySQL Flexible Server `mysql-ttmh-<suffix>` and DB
     `TailwindSessions`
   - Azure Data Factory `adf-ttmh-<suffix>`
4. **Reserved AI resource group** (`rg-ttmh-ai`)
   - Created empty for other workstreams.

SQL Managed Instance is separated in `bicep/targets/sqlmi.bicep` because
provisioning commonly takes **4-6 hours**. Pre-provision it only for trainer
demo environments.

## Estimated monthly cost

Approximate pay-as-you-go estimates for a short-lived lab in Sweden Central:

| Resource group | Main cost drivers | Estimate |
| --- | --- | ---: |
| `rg-ttmh-platform` | Bastion Basic, Log Analytics, Key Vault, networking | USD 150-220 |
| `rg-ttmh-source` | 5 burstable VMs, Standard disks, public IPs | USD 180-320 |
| `rg-ttmh-data` | Azure SQL Basic, Burstable PostgreSQL/MySQL, ADF metadata | USD 80-180 |
| `rg-ttmh-data` with SQL MI | SQL MI GP Gen5 4 vCore | Add USD 600+ |
| `rg-ttmh-ai` | Empty | USD 0 |

Shut down or delete resources after the microhack. Defender for Cloud plans can
add cost; set `enableDefender=false` or `ENABLE_DEFENDER=false` for dry runs.

## AVM modules

Module names and versions were verified from the official AVM index/source
(`Azure/bicep-registry-modules` `version.json`) and by `az bicep build`.

| Module | Version | Used by |
| --- | --- | --- |
| `br/public:avm/res/network/network-security-group` | `0.5.0` | Platform NSGs |
| `br/public:avm/res/network/virtual-network` | `0.9.0` | Hub/spoke VNets |
| `br/public:avm/res/network/bastion-host` | `0.8.0` | Azure Bastion |
| `br/public:avm/res/operational-insights/workspace` | `0.15.0` | Log Analytics |
| `br/public:avm/res/key-vault/vault` | `0.13.0` | Key Vault |
| `br/public:avm/res/network/private-dns-zone` | `0.8.0` | Private DNS |
| `br/public:avm/res/sql/server` | `0.21.0` | Azure SQL DB |
| `br/public:avm/res/db-for-postgre-sql/flexible-server` | `0.15.0` | PostgreSQL |
| `br/public:avm/res/db-for-my-sql/flexible-server` | `0.10.0` | MySQL |
| `br/public:avm/res/data-factory/factory` | `0.11.0` | Data Factory |
| `br/public:avm/res/sql/managed-instance` | `0.4.0` | SQL MI demo |

Private endpoints and DevTest Lab auto-shutdown schedules use first-party
`Microsoft.*` resource declarations where that is clearer than nested AVM
configuration.

## Preflight

PowerShell:

```powershell
.\infra\scripts\preflight.ps1 -Location swedencentral
```

Bash:

```bash
./infra/scripts/preflight.sh
```

Add `-Register` or `REGISTER=true` to register missing resource providers.

## Deploy with what-if

The scripts always run `what-if` before each create operation.

PowerShell example:

```powershell
.\infra\scripts\deploy.ps1 `
  -Suffix demo01 `
  -AdminObjectId "<kv-rbac-object-id>" `
  -AdminUsername "ttmhadmin" `
  -AdminPassword "<secure-password>" `
  -AdminSourceAddressPrefix "<your-public-ip>/32" `
  -WorkloadRawBaseUrl "https://raw.githubusercontent.com/<owner>/<repo>/<branch>" `
  -AadAdminObjectId "<sql-admin-object-id>" `
  -AadAdminLogin "<sql-admin-upn-or-group>" `
  -PostgresqlAdminPassword "<secure-password>" `
  -MysqlAdminPassword "<secure-password>"
```

Bash example:

```bash
SUFFIX=demo01 \
ADMIN_OBJECT_ID="<kv-rbac-object-id>" \
ADMIN_PASSWORD="<secure-password>" \
ADMIN_SOURCE_ADDRESS_PREFIX="<your-public-ip>/32" \
WORKLOAD_RAW_BASE_URL="https://raw.githubusercontent.com/<owner>/<repo>/<branch>" \
AAD_ADMIN_OBJECT_ID="<sql-admin-object-id>" \
AAD_ADMIN_LOGIN="<sql-admin-upn-or-group>" \
POSTGRESQL_ADMIN_PASSWORD="<secure-password>" \
MYSQL_ADMIN_PASSWORD="<secure-password>" \
./infra/scripts/deploy.sh
```

To pre-provision SQL MI:

```powershell
.\infra\scripts\deploy.ps1 -IncludeSqlMi ...
```

or:

```bash
INCLUDE_SQLMI=true ./infra/scripts/deploy.sh
```

## Teardown

PowerShell:

```powershell
.\infra\scripts\teardown.ps1
.\infra\scripts\teardown.ps1 -Force
```

Bash:

```bash
./infra/scripts/teardown.sh
FORCE=true ./infra/scripts/teardown.sh
```

## Cross-workstream dependencies

The source-estate VM extensions reference workload installers that another
workstream owns:

- `workloads\sqlserver\install.ps1`
- `workloads\postgresql\install.sh`
- `workloads\mysql\install.sh`

Set `workloadRawBaseUrl` to the raw URL for the final repo branch before
running the source-estate deployment.
