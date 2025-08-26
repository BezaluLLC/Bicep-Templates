/*
  Azure Synapse Analytics Workspace Module
  
  This module creates an Azure Synapse Analytics workspace for big data analytics and data warehousing.
  
  Features:
  - Synapse Analytics workspace with managed identity
  - Optional SQL pools and Spark pools
  - Private endpoint connectivity
  - Firewall rules and networking configuration
  - Integration with data lake storage
  - Security and monitoring configurations
*/

@description('Name of the Synapse workspace')
param synapseWorkspaceName string

@description('Azure region for deployment')
param location string

@description('Virtual network ID for private endpoint')
param vnetId string

@description('Subnet ID for Synapse workspace (compute subnet)')
param synapseSubnetId string

@description('Storage account name for Synapse default data lake (optional)')
param storageAccountName string = ''

@description('Environment identifier')
param environment string

@description('Warehouse name for tagging')
param warehouseName string

@description('SQL administrator login for Synapse')
param sqlAdminLogin string = 'sqladmin'

@description('SQL administrator password for Synapse')
@secure()
param sqlAdminPassword string = newGuid()

@description('Deploy dedicated SQL pool')
param deployDedicatedSqlPool bool = false

@description('Deploy Spark pool')
param deploySparkPool bool = false

// Variables for resource naming
var managedResourceGroupName = 'rg-synapse-managed-${synapseWorkspaceName}'
var privateEndpointName = 'pep-${synapseWorkspaceName}'
var privateDnsZoneName = 'privatelink.sql.azuresynapse.net'
var privateDnsZoneGroupName = 'default'

// Get storage account details if provided
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if (!empty(storageAccountName)) {
  name: storageAccountName
}

// Create Synapse Analytics workspace
resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseWorkspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: !empty(storageAccountName) ? {
      accountUrl: storageAccount.properties.primaryEndpoints.dfs
      filesystem: 'synapse'
      resourceId: storageAccount.id
      createManagedPrivateEndpoint: true
    } : null
    managedResourceGroupName: managedResourceGroupName
    sqlAdministratorLogin: sqlAdminLogin
    sqlAdministratorLoginPassword: sqlAdminPassword
    managedVirtualNetwork: 'default'
    publicNetworkAccess: 'Disabled'
    trustedServiceBypassEnabled: true
    managedVirtualNetworkSettings: {
      preventDataExfiltration: true
      linkedAccessCheckOnTargetResource: true
      allowedAadTenantIdsForLinking: []
    }
  }
  tags: {
    Environment: environment
    Project: 'DataWarehouse'
    WarehouseName: warehouseName
    Service: 'Synapse'
  }
}

// Create dedicated SQL pool (if enabled)
resource dedicatedSqlPool 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = if (deployDedicatedSqlPool) {
  parent: synapseWorkspace
  name: 'dwpool'
  location: location
  sku: {
    name: 'DW100c'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    createMode: 'Default'
    maxSizeBytes: 263882790666240
    storageAccountType: 'GRS'
  }
  tags: {
    Environment: environment
    Project: 'DataWarehouse'
    WarehouseName: warehouseName
    Service: 'SynapseSQLPool'
  }
}

// Create Spark pool (if enabled)
resource sparkPool 'Microsoft.Synapse/workspaces/bigDataPools@2021-06-01' = if (deploySparkPool) {
  parent: synapseWorkspace
  name: 'sparkpool'
  location: location
  properties: {
    nodeCount: 3
    nodeSizeFamily: 'MemoryOptimized'
    nodeSize: 'Small'
    autoScale: {
      enabled: true
      minNodeCount: 3
      maxNodeCount: 10
    }
    autoPause: {
      enabled: true
      delayInMinutes: 15
    }
    sparkVersion: '3.4'
    dynamicExecutorAllocation: {
      enabled: true
      minExecutors: 1
      maxExecutors: 4
    }
    sessionLevelPackagesEnabled: true
    cacheSize: 0
    customLibraries: []
  }
  tags: {
    Environment: environment
    Project: 'DataWarehouse'
    WarehouseName: warehouseName
    Service: 'SynapseSparkPool'
  }
}

// Create private DNS zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: {
    Environment: environment
    Project: 'DataWarehouse'
    WarehouseName: warehouseName
    Service: 'PrivateDNS'
  }
}

// Link private DNS zone to VNet
resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${synapseWorkspaceName}-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// Create private endpoint for Synapse workspace
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: synapseSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${synapseWorkspaceName}-sql-connection'
        properties: {
          privateLinkServiceId: synapseWorkspace.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
  }
  tags: {
    Environment: environment
    Project: 'DataWarehouse'
    WarehouseName: warehouseName
    Service: 'PrivateEndpoint'
  }
}

// Create private DNS zone group
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: privateEndpoint
  name: privateDnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'synapse-sql-config'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// Create firewall rule to allow Azure services
resource synapseFirewallRule 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  parent: synapseWorkspace
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Role assignment for Synapse to access storage account
resource synapseStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(storageAccountName)) {
  scope: storageAccount
  name: guid(storageAccount.id, synapseWorkspace.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: synapseWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output synapseWorkspaceName string = synapseWorkspace.name
output synapseWorkspaceId string = synapseWorkspace.id
output synapseWorkspaceUrl string = synapseWorkspace.properties.connectivityEndpoints.web
output synapseSqlEndpoint string = synapseWorkspace.properties.connectivityEndpoints.sql
output synapseSqlOnDemandEndpoint string = synapseWorkspace.properties.connectivityEndpoints.sqlOnDemand
output synapseDevEndpoint string = synapseWorkspace.properties.connectivityEndpoints.dev
output managedResourceGroupName string = synapseWorkspace.properties.managedResourceGroupName
output privateEndpointId string = privateEndpoint.id
output privateDnsZoneId string = privateDnsZone.id
