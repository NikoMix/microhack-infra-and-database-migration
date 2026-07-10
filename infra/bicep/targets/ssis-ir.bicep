targetScope = 'resourceGroup'

@description('Adds an Azure-SSIS Integration Runtime shell to an existing ADF for the SSIS migration challenge. Configure SSISDB/catalog parameters after SQL MI or Azure SQL catalog target is ready.')
param dataFactoryName string

@description('Azure-SSIS IR name.')
param integrationRuntimeName string = 'ttmh-ssis-ir'

param location string = resourceGroup().location

@description('Azure-SSIS node size.')
param nodeSize string = 'Standard_D2_v3'

@description('Number of Azure-SSIS IR nodes.')
param numberOfNodes int = 1

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource ssisIr 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  name: integrationRuntimeName
  parent: dataFactory
  properties: {
    type: 'Managed'
    typeProperties: {
      computeProperties: {
        location: location
        nodeSize: nodeSize
        numberOfNodes: numberOfNodes
        maxParallelExecutionsPerNode: 2
      }
    }
  }
}

output azureSsisIntegrationRuntimeName string = ssisIr.name
