@description('Data Factory name')
param dataFactoryName string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Enable managed virtual network for Data Factory')
param enableManagedVNet bool = true

@description('Public network access setting')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'

@description('Git repository configuration (optional)')
param gitRepoConfig object = {}

@description('Global parameters for Data Factory')
param globalParameters object = {}

@description('Integration runtime configurations')
param integrationRuntimes array = [
  {
    name: 'AutoResolveIntegrationRuntime'
    type: 'AutoResolve'
    computeType: 'General'
    coreCount: 8
    timeToLive: 10
  }
]

@description('Enable diagnostic settings')
param enableDiagnostics bool = true

@description('Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Diagnostic settings configuration')
param diagnosticSettings object = {
  logs: [
    {
      categoryGroup: 'allLogs'
      enabled: true
      retentionPolicy: {
        enabled: false
        days: 0
      }
    }
  ]
  metrics: [
    {
      category: 'AllMetrics'
      enabled: true
      retentionPolicy: {
        enabled: false
        days: 0
      }
    }
  ]
}

@description('Resource tags')
param tags object = {}

// Variables
var managedVNetName = 'default'

// Create Azure Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
    globalParameters: !empty(globalParameters) ? globalParameters : {}
    repoConfiguration: !empty(gitRepoConfig) ? gitRepoConfig : null
  }
  tags: tags
}

// Create managed virtual network (if enabled)
resource managedVirtualNetwork 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = if (enableManagedVNet) {
  parent: dataFactory
  name: managedVNetName
  properties: {}
}

// Create auto-resolve integration runtimes
resource autoResolveIntegrationRuntimes 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = [for ir in filter(integrationRuntimes, ir => ir.type == 'AutoResolve'): {
  parent: dataFactory
  name: ir.name
  properties: {
    type: 'Managed'
    managedVirtualNetwork: enableManagedVNet ? {
      referenceName: managedVirtualNetwork.name
      type: 'ManagedVirtualNetworkReference'
    } : null
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
        dataFlowProperties: {
          computeType: ir.?computeType ?? 'General'
          coreCount: ir.?coreCount ?? 8
          timeToLive: ir.?timeToLive ?? 10
          cleanup: false
        }
      }
    }
  }
}]

// Create Azure integration runtimes
resource azureIntegrationRuntimes 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = [for ir in filter(integrationRuntimes, ir => ir.type == 'Azure'): {
  parent: dataFactory
  name: ir.name
  properties: {
    type: 'Managed'
    managedVirtualNetwork: enableManagedVNet ? {
      referenceName: managedVirtualNetwork.name
      type: 'ManagedVirtualNetworkReference'
    } : null
    typeProperties: {
      computeProperties: {
        location: ir.?location ?? location
        dataFlowProperties: {
          computeType: ir.?computeType ?? 'General'
          coreCount: ir.?coreCount ?? 8
          timeToLive: ir.?timeToLive ?? 10
          cleanup: false
        }
      }
    }
  }
}]

// Create self-hosted integration runtimes
resource selfHostedIntegrationRuntimes 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = [for ir in filter(integrationRuntimes, ir => ir.type == 'SelfHosted'): {
  parent: dataFactory
  name: ir.name
  properties: {
    type: 'SelfHosted'
    description: ir.?description ?? ''
  }
}]

// Diagnostic settings
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${dataFactoryName}-diagnostics'
  scope: dataFactory
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: diagnosticSettings.logs
    metrics: diagnosticSettings.metrics
  }
}

// Outputs
output dataFactoryId string = dataFactory.id
output dataFactoryName string = dataFactory.name
output systemAssignedIdentityPrincipalId string = dataFactory.identity.principalId
output managedVirtualNetworkName string = enableManagedVNet ? managedVirtualNetwork.name : ''
output integrationRuntimeNames array = [for ir in integrationRuntimes: ir.name]
