targetScope = 'resourceGroup'

@description('Canonical short prefix used by all microhack workstreams.')
param prefix string = 'ttmh'

@description('Azure region for all source-estate resources.')
param location string = resourceGroup().location

@description('Local administrator username for all lab VMs.')
param adminUsername string

@secure()
@description('Local administrator password for Windows and Linux lab VMs. Use Key Vault references or secure CLI parameters.')
param adminPassword string

@description('CIDR allowed for SSH/RDP/HTTP lab access. Set to your public IP /32 for safer delivery.')
param adminSourceAddressPrefix string = 'Internet'

@description('Raw content base URL for this repo/branch, without trailing slash. Workload installers are downloaded from workloads/sqlserver/install.ps1, workloads/postgresql/install.sh, and workloads/mysql/install.sh.')
param workloadRawBaseUrl string = 'https://raw.githubusercontent.com/<owner>/<repo>/<branch>'

@description('Daily VM auto-shutdown time in HHmm format.')
param autoShutdownTime string = '1900'

@description('Time zone ID for DevTest Labs auto-shutdown schedules.')
param autoShutdownTimeZoneId string = 'UTC'

var tags = {
  env: 'microhack'
  workload: 'tailwind-migration'
  tier: 'source-estate'
}

var vnetName = 'vnet-${prefix}-source'
var subnetName = 'snet-source'
var subnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)

var vmDefinitions = [
  {
    name: 'vm-web'
    os: 'windows'
    size: 'Standard_B2s'
    privateIp: '10.30.1.10'
    image: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-g2'
      version: 'latest'
    }
  }
  {
    name: 'vm-app'
    os: 'linux'
    size: 'Standard_B2s'
    privateIp: '10.30.1.11'
    image: {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
  }
  {
    name: 'vm-sql'
    os: 'windows'
    size: 'Standard_B2ms'
    privateIp: '10.30.1.12'
    image: {
      publisher: 'MicrosoftSQLServer'
      offer: 'sql2019-ws2022'
      sku: 'sqldev-gen2'
      version: 'latest'
    }
  }
  {
    name: 'vm-pg'
    os: 'linux'
    size: 'Standard_B2s'
    privateIp: '10.30.1.13'
    image: {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
  }
  {
    name: 'vm-mysql'
    os: 'linux'
    size: 'Standard_B2s'
    privateIp: '10.30.1.14'
    image: {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
  }
]

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-01-01' = {
  name: 'nsg-${prefix}-source'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRdpFromAdmin'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: adminSourceAddressPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowSshFromAdmin'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: adminSourceAddressPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHttpFromAdmin'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '8080'
          ]
          sourceAddressPrefix: adminSourceAddressPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.30.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.30.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIps 'Microsoft.Network/publicIPAddresses@2025-01-01' = [for vm in vmDefinitions: {
  name: 'pip-${vm.name}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}]

resource nics 'Microsoft.Network/networkInterfaces@2025-01-01' = [for (vm, i) in vmDefinitions: {
  name: 'nic-${vm.name}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: vm.privateIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIps[i].id
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}]

resource vms 'Microsoft.Compute/virtualMachines@2024-11-01' = [for (vm, i) in vmDefinitions: {
  name: vm.name
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vm.size
    }
    osProfile: union({
      computerName: vm.name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }, vm.os == 'linux' ? {
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
    } : {
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
        }
      }
    })
    storageProfile: {
      imageReference: vm.image
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}]

resource webBootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  name: 'vm-web/bootstrap-iis'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Bypass -Command "Install-WindowsFeature Web-Server,Web-Asp-Net45 -IncludeManagementTools; Set-Content -Path C:\\inetpub\\wwwroot\\index.html -Value TailwindTradersWebSource"'
    }
  }
  dependsOn: [
    vms
  ]
}

resource sqlBootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  name: 'vm-sql/bootstrap-sql-workload'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${workloadRawBaseUrl}/workloads/sqlserver/install.ps1'
      ]
      commandToExecute: 'powershell -ExecutionPolicy Bypass -File install.ps1'
    }
  }
  dependsOn: [
    vms
  ]
}

resource appBootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  name: 'vm-app/bootstrap-node-nginx'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'bash -c "set -e; apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y nginx nodejs npm; mkdir -p /opt/tailwind-api; echo Y29uc3QgaHR0cD1yZXF1aXJlKCJodHRwIik7Cmh0dHAuY3JlYXRlU2VydmVyKChyZXEscmVzKT0+e3Jlcy53cml0ZUhlYWQoMjAwLHsiQ29udGVudC1UeXBlIjoiYXBwbGljYXRpb24vanNvbiJ9KTtyZXMuZW5kKEpTT04uc3RyaW5naWZ5KHtzZXJ2aWNlOiJUYWlsd2luZCBUcmFkZXJzIE5vZGUgQVBJIix2bToidm0tYXBwIn0pKTt9KS5saXN0ZW4oODA4MCwiMC4wLjAuMCIpOwo= | base64 -d > /opt/tailwind-api/server.js; echo W1VuaXRdCkRlc2NyaXB0aW9uPVRhaWx3aW5kIFRyYWRlcnMgZGVtbyBOb2RlIEFQSQpBZnRlcj1uZXR3b3JrLnRhcmdldApbU2VydmljZV0KRXhlY1N0YXJ0PS91c3IvYmluL25vZGUgL29wdC90YWlsd2luZC1hcGkvc2VydmVyLmpzClJlc3RhcnQ9YWx3YXlzCltJbnN0YWxsXQpXYW50ZWRCeT1tdWx0aS11c2VyLnRhcmdldAo= | base64 -d > /etc/systemd/system/tailwind-api.service; systemctl daemon-reload; systemctl enable --now tailwind-api; systemctl enable --now nginx"'
    }
  }
  dependsOn: [
    vms
  ]
}

resource pgBootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  name: 'vm-pg/bootstrap-postgresql-workload'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${workloadRawBaseUrl}/workloads/postgresql/install.sh'
      ]
      commandToExecute: 'bash install.sh'
    }
  }
  dependsOn: [
    vms
  ]
}

resource mysqlBootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  name: 'vm-mysql/bootstrap-mysql-workload'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${workloadRawBaseUrl}/workloads/mysql/install.sh'
      ]
      commandToExecute: 'bash install.sh'
    }
  }
  dependsOn: [
    vms
  ]
}

resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = [for vm in vmDefinitions: {
  name: 'shutdown-computevm-${vm.name}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZoneId
    targetResourceId: resourceId('Microsoft.Compute/virtualMachines', vm.name)
    notificationSettings: {
      status: 'Disabled'
    }
  }
  dependsOn: [
    vms
  ]
}]

output sourceVnetResourceId string = vnet.id
output vmNames array = [for vm in vmDefinitions: vm.name]
