targetScope = 'resourceGroup'

@description('Canonical short prefix used by all microhack workstreams.')
param prefix string = 'ttmh'

@description('Azure region for migration targets.')
param location string = resourceGroup().location

@description('Suffix used for globally unique service names.')
param suffix string = take(toLower(uniqueString(subscription().id, resourceGroup().id, prefix)), 6)

@description('Name of the platform resource group containing vnet-ttmh-spoke and private DNS zones.')
param platformResourceGroupName string = 'rg-${prefix}-platform'

@description('Object ID of the Microsoft Entra administrator for Azure SQL logical server.')
param aadAdminObjectId string

@description('Display/login name of the Microsoft Entra administrator for Azure SQL logical server.')
param aadAdminLogin string = 'TTMH Azure SQL Admin'

@description('Principal type for the Azure SQL administrator.')
@allowed([
  'User'
  'Group'
  'Application'
])
param aadAdminPrincipalType string = 'User'

@description('Database administrator username for PostgreSQL Flexible Server.')
param postgresqlAdminUsername string

@secure()
@description('Database administrator password for PostgreSQL Flexible Server.')
param postgresqlAdminPassword string

@description('Database administrator username for MySQL Flexible Server.')
param mysqlAdminUsername string

@secure()
@description('Database administrator password for MySQL Flexible Server.')
param mysqlAdminPassword string

var tags = {
  env: 'microhack'
  workload: 'tailwind-migration'
  tier: 'target-data'
}

var sqlServerName = 'sql-${prefix}-${suffix}'
var postgresqlName = 'psql-${prefix}-${suffix}'
var mysqlName = 'mysql-${prefix}-${suffix}'
var adfName = 'adf-${prefix}-${suffix}'
var spokeVnetName = 'vnet-${prefix}-spoke'
var privateEndpointSubnetId = resourceId(platformResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', spokeVnetName, 'snet-private-endpoints')
var postgresqlSubnetId = resourceId(platformResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', spokeVnetName, 'snet-postgresql')
var mysqlSubnetId = resourceId(platformResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', spokeVnetName, 'snet-mysql')
#disable-next-line no-hardcoded-env-urls
var sqlPrivateDnsZoneId = resourceId(platformResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.database.windows.net')
var pgPrivateDnsZoneId = resourceId(platformResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.postgres.database.azure.com')
var mysqlPrivateDnsZoneId = resourceId(platformResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.mysql.database.azure.com')

module sqlServer 'br/public:avm/res/sql/server:0.21.0' = {
  name: 'sql-${prefix}'
  params: {
    name: sqlServerName
    location: location
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: aadAdminLogin
      principalType: aadAdminPrincipalType
      sid: aadAdminObjectId
      tenantId: tenant().tenantId
    }
    databases: [
      {
        name: 'TailwindOLTP'
        availabilityZone: -1
        sku: {
          name: 'Basic'
          tier: 'Basic'
          capacity: 5
        }
        maxSizeBytes: 2147483648
        tags: tags
      }
    ]
    tags: tags
    enableTelemetry: false
  }
}

resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: 'pe-${sqlServerName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'sqlServer'
        properties: {
          privateLinkServiceId: sqlServer.outputs.resourceId
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource sqlPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  name: 'default'
  parent: sqlPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZoneId
        }
      }
    ]
  }
}

module postgresql 'br/public:avm/res/db-for-postgre-sql/flexible-server:0.15.0' = {
  name: 'psql-${prefix}'
  params: {
    name: postgresqlName
    location: location
    administratorLogin: postgresqlAdminUsername
    administratorLoginPassword: postgresqlAdminPassword
    skuName: 'Standard_B1ms'
    tier: 'Burstable'
    availabilityZone: 1
    highAvailability: 'Disabled'
    backupRetentionDays: 7
    geoRedundantBackup: 'Disabled'
    storageSizeGB: 32
    version: '14'
    delegatedSubnetResourceId: postgresqlSubnetId
    privateDnsZoneArmResourceId: pgPrivateDnsZoneId
    publicNetworkAccess: 'Disabled'
    databases: [
      {
        name: 'TailwindCatalog'
        charset: 'UTF8'
        collation: 'en_US.utf8'
      }
    ]
    tags: tags
    enableTelemetry: false
  }
}

module mysql 'br/public:avm/res/db-for-my-sql/flexible-server:0.10.0' = {
  name: 'mysql-${prefix}'
  params: {
    name: mysqlName
    location: location
    administratorLogin: mysqlAdminUsername
    administratorLoginPassword: mysqlAdminPassword
    skuName: 'Standard_B1ms'
    tier: 'Burstable'
    availabilityZone: 1
    highAvailability: 'Disabled'
    backupRetentionDays: 7
    geoRedundantBackup: 'Disabled'
    storageSizeGB: 32
    storageIOPS: 360
    version: '8.0.21'
    delegatedSubnetResourceId: mysqlSubnetId
    privateDnsZoneResourceId: mysqlPrivateDnsZoneId
    publicNetworkAccess: 'Disabled'
    databases: [
      {
        name: 'TailwindSessions'
        charset: 'utf8'
        collation: 'utf8_general_ci'
      }
    ]
    tags: tags
    enableTelemetry: false
  }
}

module dataFactory 'br/public:avm/res/data-factory/factory:0.11.0' = {
  name: 'adf-${prefix}'
  params: {
    name: adfName
    location: location
    publicNetworkAccess: 'Enabled'
    managedIdentities: {
      systemAssigned: true
    }
    managedVirtualNetwork: {
      name: 'default'
    }
    tags: tags
    enableTelemetry: false
  }
}

output sqlServerName string = sqlServerName
output sqlDatabaseName string = 'TailwindOLTP'
output postgresqlServerName string = postgresqlName
output postgresqlDatabaseName string = 'TailwindCatalog'
output mysqlServerName string = mysqlName
output mysqlDatabaseName string = 'TailwindSessions'
output dataFactoryName string = adfName
