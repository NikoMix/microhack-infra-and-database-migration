targetScope = 'subscription'

@description('Canonical short prefix used by all microhack workstreams.')
param prefix string = 'ttmh'

@description('Azure region for all regional resources.')
param location string = 'swedencentral'

@description('Suffix used for globally unique names. Defaults to a deterministic subscription-scoped value.')
param suffix string = take(toLower(uniqueString(subscription().id, prefix)), 6)

@description('Object ID of the lab admin user/group/service principal to grant Key Vault Secrets Officer. Leave blank to skip the assignment.')
param adminObjectId string = ''

@description('Enable Microsoft Defender for Cloud plans used by the lab. This can incur Defender charges.')
param enableDefender bool = true

var tags = {
  env: 'microhack'
  workload: 'tailwind-migration'
}

var platformResourceGroupName = 'rg-${prefix}-platform'
var aiResourceGroupName = 'rg-${prefix}-ai'

resource platformRg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: platformResourceGroupName
  location: location
  tags: tags
}

resource aiRg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: aiResourceGroupName
  location: location
  tags: union(tags, {
    purpose: 'reserved-ai-workstream'
  })
}


var defenderPlans = [
  'VirtualMachines'
  'SqlServers'
  'SqlServerVirtualMachines'
  'OpenSourceRelationalDatabases'
]

resource defenderPricing 'Microsoft.Security/pricings@2024-01-01' = [for plan in defenderPlans: if (enableDefender) {
  name: plan
  properties: {
    pricingTier: 'Standard'
  }
}]

module platform './platform.bicep' = {
  name: 'platform-${prefix}'
  scope: platformRg
  params: {
    prefix: prefix
    location: location
    suffix: suffix
    adminObjectId: adminObjectId
  }
}

output platformResourceGroupName string = platformResourceGroupName
output aiResourceGroupName string = aiResourceGroupName
output hubVnetResourceId string = platform.outputs.hubVnetResourceId
output spokeVnetResourceId string = platform.outputs.spokeVnetResourceId
output privateEndpointSubnetResourceId string = platform.outputs.privateEndpointSubnetResourceId
output sqlMiSubnetResourceId string = platform.outputs.sqlMiSubnetResourceId
output postgresqlSubnetResourceId string = platform.outputs.postgresqlSubnetResourceId
output mysqlSubnetResourceId string = platform.outputs.mysqlSubnetResourceId
output keyVaultName string = platform.outputs.keyVaultName
output logAnalyticsWorkspaceName string = platform.outputs.logAnalyticsWorkspaceName
