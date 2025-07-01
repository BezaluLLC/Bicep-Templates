/*
  Azure Data Warehouse Infrastructure Template - MIGRATED TO SHARED MODULES
  
  This template creates a comprehensive data warehouse infrastructure using shared modules:
  - Resource Group with naming pattern RG-{warehouseName}
  - Virtual Network with spoke architecture (vNET-{warehouseName})
  - Dedicated subnets for different database services (when deployed)
  - Optional deployment of various Azure database services
  - Additional data warehouse components for analytics and processing
  
  Design Decisions:
  - Uses shared module library for consistent, reusable components
  - Uses spoke VNet pattern for hub-spoke networking
  - Subnets are only created when corresponding services are enabled
  - Follows Azure naming conventions and best practices
  - Includes security configurations and monitoring capabilities
*/

targetScope = 'subscription'

// Parameters for warehouse configuration
@minLength(3)
@maxLength(12)
@description('The name of the data warehouse (used in resource naming)')
param warehouseName string

@description('The Azure region for the deployment')
param location string

@description('Environment identifier (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string

@description('Resource token for unique naming')
param resourceToken string = uniqueString(subscription().id, warehouseName, location)

// Database deployment options
@description('Deploy Azure SQL Database for relational data warehousing')
param deploySqlDatabase bool

@description('Deploy Azure Database for PostgreSQL Flexible Server')
param deployPostgreSQL bool

@description('Deploy Azure Cosmos DB for NoSQL/document storage')
param deployCosmosDB bool

@description('Deploy Azure Synapse Analytics workspace')
param deploySynapse bool

@description('Deploy Azure Data Factory for ETL pipelines')
param deployDataFactory bool

@description('Deploy Azure Storage Account for data lake')
param deployDataLake bool

@description('Deploy Azure Key Vault for secrets management')
param deployKeyVault bool

@description('Deploy Log Analytics workspace for monitoring')
param deployLogAnalytics bool

// Database configuration parameters
@description('Administrator username for database services')
param dbAdminUsername string

@description('Administrator password for database services')
@secure()
param dbAdminPassword string

// Network configuration
@description('VNet address prefix')
param vnetAddressPrefix string

@description('SQL Database subnet prefix')
param sqlSubnetPrefix string

@description('PostgreSQL subnet prefix')
param postgresSubnetPrefix string

@description('Cosmos DB subnet prefix')
param cosmosSubnetPrefix string

@description('Synapse subnet prefix')
param synapseSubnetPrefix string

@description('Services subnet prefix')
param servicesSubnetPrefix string

@description('Gateway subnet prefix')
param gatewaySubnetPrefix string

// Resource names
var rgName = 'RG-${warehouseName}'
var vnetName = 'vNET-${warehouseName}'
var sqlSubnetName = 'sNET-SqlDatabase'
var postgresSubnetName = 'sNET-PostgreSQL'
var cosmosSubnetName = 'sNET-CosmosDB'
var synapseSubnetName = 'sNET-Synapse'
var servicesSubnetName = 'sNET-Services'
var gatewaySubnetName = 'sNET-Gateway'

var sqlServerName = 'sql-${warehouseName}-${resourceToken}'
var sqlDatabaseName = '${warehouseName}-datawarehouse'
var postgresServerName = 'postgres-${warehouseName}-${resourceToken}'
var cosmosDatabaseName = 'cosmos-${warehouseName}-${resourceToken}'
var synapseWorkspaceName = 'synapse-${warehouseName}-${resourceToken}'
var dataFactoryName = 'adf-${warehouseName}-${resourceToken}'
var storageAccountName = 'st${warehouseName}${resourceToken}'
var keyVaultName = 'kv-${warehouseName}-${resourceToken}'
var logAnalyticsName = 'law-${warehouseName}-${resourceToken}'

// Common tags
var commonTags = {
  Environment: environment
  Project: 'DataWarehouse'
  WarehouseName: warehouseName
  'azd-env-name': '${warehouseName}-${environment}'
}

// Create the resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: rgName
  location: location
  tags: commonTags
}

// Deploy Log Analytics workspace first (as other services depend on it)
module logAnalytics '../../shared/bicep-modules/monitoring/loganalytics.bicep' = if (deployLogAnalytics) {
  scope: resourceGroup
  name: 'loganalytics-deployment'
  params: {
    workspaceName: logAnalyticsName
    location: location
    retentionInDays: 30
    dailyQuotaGb: 1
    tags: commonTags
  }
}

// Build dynamic subnets array based on deployment flags
var allPossibleSubnets = [
  {
    name: sqlSubnetName
    addressPrefix: sqlSubnetPrefix
    delegations: []
    serviceEndpoints: ['Microsoft.Sql']
    enabled: deploySqlDatabase
  }
  {
    name: postgresSubnetName
    addressPrefix: postgresSubnetPrefix
    delegations: [
      {
        name: 'PostgreSQLDelegation'
        properties: {
          serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
        }
      }
    ]
    serviceEndpoints: []
    enabled: deployPostgreSQL
  }
  {
    name: cosmosSubnetName
    addressPrefix: cosmosSubnetPrefix
    delegations: []
    serviceEndpoints: ['Microsoft.AzureCosmosDB']
    enabled: deployCosmosDB
  }
  {
    name: synapseSubnetName
    addressPrefix: synapseSubnetPrefix
    delegations: []
    serviceEndpoints: ['Microsoft.Sql']
    enabled: deploySynapse
  }
  {
    name: servicesSubnetName
    addressPrefix: servicesSubnetPrefix
    delegations: []
    serviceEndpoints: ['Microsoft.Storage', 'Microsoft.KeyVault']
    enabled: true // Always deploy services subnet
  }
  {
    name: gatewaySubnetName
    addressPrefix: gatewaySubnetPrefix
    delegations: []
    serviceEndpoints: []
    enabled: true // Always deploy gateway subnet
  }
]

// Filter enabled subnets  
var enabledSubnets = filter(allPossibleSubnets, subnet => subnet.enabled)

// Deploy the virtual network using shared general VNet module
module vnet '../../shared/bicep-modules/networking/vnet.bicep' = {
  scope: resourceGroup
  name: 'vnet-deployment'
  params: {
    vnetName: vnetName
    location: location
    addressPrefixes: [vnetAddressPrefix]
    subnets: enabledSubnets
    tags: commonTags
  }
}

// Deploy Key Vault using shared module
module keyVault '../../shared/bicep-modules/security/keyvault.bicep' = if (deployKeyVault) {
  scope: resourceGroup
  name: 'keyvault-deployment'
  params: {
    keyVaultName: keyVaultName
    location: location
    deployPrivateEndpoint: true
    subnetId: vnet.outputs.subnetIds[servicesSubnetName]
    vnetId: vnet.outputs.vnetId
    logAnalyticsWorkspaceId: deployLogAnalytics ? logAnalytics.outputs.workspaceId : ''
    tags: commonTags
  }
}

// Deploy Storage Account for data lake using shared module
module dataLake '../../shared/bicep-modules/storage/storage-account.bicep' = if (deployDataLake) {
  scope: resourceGroup
  name: 'datalake-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
    enableHierarchicalNamespace: true // Data Lake Gen2
    privateEndpointConfig: {
      enabled: true
      subnetId: vnet.outputs.subnetIds[servicesSubnetName]
      vnetId: vnet.outputs.vnetId
    }
    logAnalyticsWorkspaceId: deployLogAnalytics ? logAnalytics.outputs.workspaceId : ''
    tags: commonTags
  }
}

// Deploy SQL Database using shared module
module sqlDatabase '../../shared/bicep-modules/storage/sql-database.bicep' = if (deploySqlDatabase) {
  scope: resourceGroup
  name: 'sqldatabase-deployment'
  params: {
    sqlServerName: sqlServerName
    databaseNames: [sqlDatabaseName]
    location: location
    adminUsername: dbAdminUsername
    adminPassword: dbAdminPassword
    databaseSku: {
      name: 'S2'
      tier: 'Standard'
      capacity: 50
    }
    logAnalyticsWorkspaceId: deployLogAnalytics ? logAnalytics.outputs.workspaceId : ''
    tags: commonTags
  }
}

// Deploy PostgreSQL using shared module
module postgresql '../../shared/bicep-modules/storage/postgresql.bicep' = if (deployPostgreSQL) {
  scope: resourceGroup
  name: 'postgresql-deployment'
  params: {
    postgresServerName: postgresServerName
    location: location
    adminUsername: dbAdminUsername
    adminPassword: dbAdminPassword
    postgresVersion: '16'
    subnetId: vnet.outputs.subnetIds[postgresSubnetName]
    logAnalyticsWorkspaceId: deployLogAnalytics ? logAnalytics.outputs.workspaceId : ''
    tags: commonTags
  }
}

// Deploy Cosmos DB using shared module
module cosmosDB '../../shared/bicep-modules/storage/cosmosdb.bicep' = if (deployCosmosDB) {
  scope: resourceGroup
  name: 'cosmosdb-deployment'
  params: {
    cosmosAccountName: cosmosDatabaseName
    location: location
    databaseApi: 'Sql'
    databases: [
      {
        name: 'datawarehouse'
        containers: [
          {
            name: 'documents'
            partitionKeyPath: '/id'
            throughput: 400
          }
        ]
      }
    ]
    logAnalyticsWorkspaceId: deployLogAnalytics ? logAnalytics.outputs.workspaceId : ''
    tags: commonTags
  }
}

// Deploy Data Factory using shared module
module dataFactory '../../shared/bicep-modules/integration/data-factory.bicep' = if (deployDataFactory) {
  scope: resourceGroup
  name: 'datafactory-deployment'
  params: {
    dataFactoryName: dataFactoryName
    location: location
    publicNetworkAccess: 'Disabled'
    logAnalyticsWorkspaceId: deployLogAnalytics ? logAnalytics.outputs.workspaceId : ''
    tags: commonTags
  }
}

// Deploy Synapse (keeping original module for now - would need a shared Synapse module)
module synapse 'modules/synapse.bicep' = if (deploySynapse) {
  scope: resourceGroup
  name: 'synapse-deployment'
  params: {
    synapseWorkspaceName: synapseWorkspaceName
    location: location
    storageAccountName: deployDataLake ? dataLake.outputs.storageAccountName : storageAccountName
    sqlAdminLogin: dbAdminUsername
    sqlAdminPassword: dbAdminPassword
    vnetId: vnet.outputs.vnetId
    synapseSubnetId: vnet.outputs.subnetIds[synapseSubnetName]
    environment: environment
    warehouseName: warehouseName
  }
}

// Outputs
output resourceGroupName string = resourceGroup.name
output vnetId string = vnet.outputs.vnetId
output vnetName string = vnet.outputs.vnetName

output logAnalyticsWorkspaceId string = deployLogAnalytics ? logAnalytics.outputs.workspaceId : ''
output keyVaultId string = deployKeyVault ? keyVault.outputs.keyVaultId : ''
output storageAccountId string = deployDataLake ? dataLake.outputs.storageAccountId : ''

output sqlServerFqdn string = deploySqlDatabase ? sqlDatabase.outputs.sqlServerFqdn : ''
output postgresServerFqdn string = deployPostgreSQL ? postgresql.outputs.postgresServerFqdn : ''
output cosmosDbEndpoint string = deployCosmosDB ? cosmosDB.outputs.cosmosAccountEndpoint : ''
output dataFactoryId string = deployDataFactory ? dataFactory.outputs.dataFactoryId : ''
output synapseWorkspaceId string = deploySynapse ? synapse.outputs.synapseWorkspaceId : ''
