targetScope = 'resourceGroup'

@description('Deploys the long-running Azure SQL Managed Instance target. Provisioning commonly takes 4-6 hours; run only when pre-provisioning the demo environment.')
param deployWarning string = 'SQL MI is intentionally separated because provisioning is long-running and may incur significant cost.'

param prefix string = 'ttmh'
param location string = resourceGroup().location
param suffix string = take(toLower(uniqueString(subscription().id, resourceGroup().id, prefix)), 6)
param platformResourceGroupName string = 'rg-${prefix}-platform'

param administratorLogin string

@secure()
param administratorLoginPassword string

@description('Optional Microsoft Entra administrator object ID. Leave empty to use SQL authentication only for this demo MI.')
param aadAdminObjectId string = ''

param aadAdminLogin string = 'TTMH SQL MI Admin'

@allowed([
  'User'
  'Group'
  'Application'
])
param aadAdminPrincipalType string = 'User'

var tags = {
  env: 'microhack'
  workload: 'tailwind-migration'
  tier: 'target-data'
  caveat: 'long-running-sqlmi'
}

var sqlMiName = 'sqlmi-${prefix}-${suffix}'
var sqlMiSubnetId = resourceId(platformResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', 'vnet-${prefix}-spoke', 'snet-sqlmi')

module sqlManagedInstance 'br/public:avm/res/sql/managed-instance:0.4.0' = {
  name: 'sqlmi-${prefix}'
  params: {
    name: sqlMiName
    location: location
    subnetResourceId: sqlMiSubnetId
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    skuName: 'GP_Gen5'
    skuTier: 'GeneralPurpose'
    vCores: 4
    storageSizeInGB: 32
    licenseType: 'LicenseIncluded'
    publicDataEndpointEnabled: false
    proxyOverride: 'Proxy'
    requestedBackupStorageRedundancy: 'Local'
    administrators: empty(aadAdminObjectId) ? null : {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: false
      login: aadAdminLogin
      principalType: aadAdminPrincipalType
      sid: aadAdminObjectId
      tenantId: tenant().tenantId
    }
    databases: [
      {
        name: 'TailwindOLTP'
      }
    ]
    tags: tags
    enableTelemetry: false
  }
}

output warning string = deployWarning
output sqlManagedInstanceName string = sqlMiName
output sqlManagedInstanceResourceId string = sqlManagedInstance.outputs.resourceId
