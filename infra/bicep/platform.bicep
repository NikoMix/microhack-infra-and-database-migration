targetScope = 'resourceGroup'

@description('Canonical short prefix used by all microhack workstreams.')
param prefix string = 'ttmh'

@description('Azure region for all regional resources.')
param location string = 'swedencentral'

@description('Suffix used for globally unique names. Defaults to a deterministic subscription-scoped value.')
param suffix string = take(toLower(uniqueString(subscription().id, prefix)), 6)

@description('Object ID of the lab admin user/group/service principal to grant Key Vault Secrets Officer. Leave blank to skip the assignment.')
param adminObjectId string = ''

var tags = {
  env: 'microhack'
  workload: 'tailwind-migration'
}

var hubVnetName = 'vnet-${prefix}-hub'
var spokeVnetName = 'vnet-${prefix}-spoke'
var kvName = 'kv-${prefix}-${suffix}'
var logName = 'log-${prefix}-${suffix}'

module nsgWorkload 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'nsg-${prefix}-workload'
  params: {
    name: 'nsg-${prefix}-workload'
    location: location
    tags: tags
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
    enableTelemetry: false
  }
}

module nsgPrivateEndpoints 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'nsg-${prefix}-private-endpoints'
  params: {
    name: 'nsg-${prefix}-private-endpoints'
    location: location
    tags: tags
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
    enableTelemetry: false
  }
}

module nsgSqlMi 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'nsg-${prefix}-sqlmi'
  params: {
    name: 'nsg-${prefix}-sqlmi'
    location: location
    tags: tags
    securityRules: [
      {
        name: 'AllowMiManagementInbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '9000'
            '9003'
            '1438'
            '1440'
            '1452'
          ]
          sourceAddressPrefix: 'AzureCloud'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowMiHealthProbeInbound'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowMiVnetInbound'
        properties: {
          priority: 120
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowMiAzureCloudOutbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Outbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '11000-11999'
            '12000'
            '1438'
            '1440'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
        }
      }
      {
        name: 'AllowMiStorageOutbound'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Outbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Storage'
        }
      }
      {
        name: 'AllowMiSqlOutbound'
        properties: {
          priority: 120
          access: 'Allow'
          direction: 'Outbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Sql'
        }
      }
      {
        name: 'AllowMiMonitorOutbound'
        properties: {
          priority: 130
          access: 'Allow'
          direction: 'Outbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureMonitor'
        }
      }
    ]
    enableTelemetry: false
  }
}

resource sqlMiRouteTable 'Microsoft.Network/routeTables@2025-01-01' = {
  name: 'rt-${prefix}-sqlmi'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
  }
}

module hubVnet 'br/public:avm/res/network/virtual-network:0.9.0' = {
  name: 'vnet-${prefix}-hub'
  params: {
    name: hubVnetName
    location: location
    addressPrefixes: [
      '10.10.0.0/16'
    ]
    subnets: [
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.10.0.0/26'
      }
    ]
    tags: tags
    enableTelemetry: false
  }
}

module spokeVnet 'br/public:avm/res/network/virtual-network:0.9.0' = {
  name: 'vnet-${prefix}-spoke'
  params: {
    name: spokeVnetName
    location: location
    addressPrefixes: [
      '10.20.0.0/16'
    ]
    subnets: [
      {
        name: 'snet-workload'
        addressPrefix: '10.20.1.0/24'
        networkSecurityGroupResourceId: nsgWorkload.outputs.resourceId
      }
      {
        name: 'snet-private-endpoints'
        addressPrefix: '10.20.2.0/24'
        privateEndpointNetworkPolicies: 'Disabled'
        networkSecurityGroupResourceId: nsgPrivateEndpoints.outputs.resourceId
      }
      {
        name: 'snet-sqlmi'
        addressPrefix: '10.20.10.0/24'
        delegation: 'Microsoft.Sql/managedInstances'
        networkSecurityGroupResourceId: nsgSqlMi.outputs.resourceId
        routeTableResourceId: sqlMiRouteTable.id
      }
      {
        name: 'snet-postgresql'
        addressPrefix: '10.20.20.0/24'
        delegation: 'Microsoft.DBforPostgreSQL/flexibleServers'
      }
      {
        name: 'snet-mysql'
        addressPrefix: '10.20.21.0/24'
        delegation: 'Microsoft.DBforMySQL/flexibleServers'
      }
    ]
    tags: tags
    enableTelemetry: false
  }
}

resource hubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-07-01' = {
  name: '${hubVnetName}/${hubVnetName}-to-${spokeVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    remoteVirtualNetwork: {
      id: spokeVnet.outputs.resourceId
    }
  }
}

resource spokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-07-01' = {
  name: '${spokeVnetName}/${spokeVnetName}-to-${hubVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    remoteVirtualNetwork: {
      id: hubVnet.outputs.resourceId
    }
  }
}

module bastion 'br/public:avm/res/network/bastion-host:0.8.0' = {
  name: 'bas-${prefix}-hub'
  params: {
    name: 'bas-${prefix}-hub'
    location: location
    virtualNetworkResourceId: hubVnet.outputs.resourceId
    skuName: 'Basic'
    publicIPAddressObject: {
      name: 'pip-${prefix}-bastion'
      skuName: 'Standard'
      publicIPAllocationMethod: 'Static'
      tags: tags
    }
    tags: tags
    enableTelemetry: false
  }
}

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.15.0' = {
  name: 'log-${prefix}'
  params: {
    name: logName
    location: location
    skuName: 'PerGB2018'
    dataRetention: 30
    tags: tags
    enableTelemetry: false
  }
}

module keyVault 'br/public:avm/res/key-vault/vault:0.13.0' = {
  name: 'kv-${prefix}'
  params: {
    name: kvName
    location: location
    sku: 'standard'
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Enabled'
    tags: tags
    enableTelemetry: false
  }
}

resource kvSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(adminObjectId)) {
  name: guid(resourceId('Microsoft.KeyVault/vaults', kvName), adminObjectId, 'Key Vault Secrets Officer')
  properties: {
    principalId: adminObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
    principalType: 'User'
  }
}

#disable-next-line no-hardcoded-env-urls
var privateDnsZones = [
  #disable-next-line no-hardcoded-env-urls
  'privatelink.database.windows.net'
  'privatelink.postgres.database.azure.com'
  'privatelink.mysql.database.azure.com'
]

module privateDns 'br/public:avm/res/network/private-dns-zone:0.8.0' = [for zone in privateDnsZones: {
  name: 'pdns-${replace(zone, '.', '-')}'
  params: {
    name: zone
    tags: tags
    virtualNetworkLinks: [
      {
        name: '${hubVnetName}-link'
        virtualNetworkResourceId: hubVnet.outputs.resourceId
        registrationEnabled: false
      }
      {
        name: '${spokeVnetName}-link'
        virtualNetworkResourceId: spokeVnet.outputs.resourceId
        registrationEnabled: false
      }
    ]
    enableTelemetry: false
  }
}]

output hubVnetResourceId string = hubVnet.outputs.resourceId
output spokeVnetResourceId string = spokeVnet.outputs.resourceId
output privateEndpointSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnetName, 'snet-private-endpoints')
output sqlMiSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnetName, 'snet-sqlmi')
output postgresqlSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnetName, 'snet-postgresql')
output mysqlSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnetName, 'snet-mysql')
output keyVaultName string = kvName
output logAnalyticsWorkspaceName string = logName
