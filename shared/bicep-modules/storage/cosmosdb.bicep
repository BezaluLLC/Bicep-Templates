/*
  Shared Cosmos DB Module
  
  Creates an Azure Cosmos DB account with configurable consistency, throughput,
  private endpoints, and container definitions for various data patterns.
*/

@description('Cosmos DB account name')
param cosmosAccountName string

@description('Location for the Cosmos DB account')
param location string

@description('Virtual network ID for private endpoint')
param vnetId string = ''

@description('Subnet ID for private endpoint')
param subnetId string = ''

@description('Enable private endpoint')
param enablePrivateEndpoint bool = true

@description('Cosmos DB API type')
@allowed(['Sql', 'MongoDB', 'Cassandra', 'Gremlin', 'Table'])
param databaseApi string = 'Sql'

@description('Cosmos DB consistency level')
@allowed(['Eventual', 'Session', 'BoundedStaleness', 'Strong', 'ConsistentPrefix'])
param consistencyLevel string = 'Session'

@description('Max staleness prefix (for BoundedStaleness)')
param maxStalenessPrefix int = 100000

@description('Max interval in seconds (for BoundedStaleness)')
param maxIntervalInSeconds int = 300

@description('Enable analytical storage')
param enableAnalyticalStorage bool = false

@description('Analytical storage schema type')
@allowed(['WellDefined', 'FullFidelity'])
param analyticalStorageSchemaType string = 'WellDefined'

@description('Enable free tier')
param enableFreeTier bool = false

@description('Enable serverless')
param enableServerless bool = false

@description('Enable multi-region writes')
param enableMultipleWriteLocations bool = false

@description('Enable automatic failover')
param enableAutomaticFailover bool = false

@description('Additional locations for geo-replication')
param additionalLocations array = []

@description('Backup policy configuration')
param backupPolicy object = {
  type: 'Periodic'
  intervalInMinutes: 240
  retentionInHours: 8
  storageRedundancy: 'Local'
}

@description('Database configurations')
param databases array = []

@description('IP filter rules (CIDR blocks or IP addresses)')
param ipRules array = []

@description('Allow Azure services access')
param allowAzureServices bool = true

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Resource tags')
param tags object = {}

@description('Enable burst capacity')
param enableBurstCapacity bool = false

@description('Enable partition merge')
param enablePartitionMerge bool = false

// Build additional locations with proper indexing
var additionalLocationsMapped = [for (loc, i) in additionalLocations: {
  locationName: loc.locationName
  failoverPriority: i + 1
  isZoneRedundant: loc.?isZoneRedundant ?? false
}]

// Build locations array
var locations = concat([
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
], additionalLocationsMapped)

// Build capabilities array
var capabilities = concat(
  enableServerless ? [{ name: 'EnableServerless' }] : [],
  databaseApi == 'MongoDB' ? [{ name: 'EnableMongo' }] : [],
  databaseApi == 'Cassandra' ? [{ name: 'EnableCassandra' }] : [],
  databaseApi == 'Gremlin' ? [{ name: 'EnableGremlin' }] : [],
  databaseApi == 'Table' ? [{ name: 'EnableTable' }] : [],
  enableAnalyticalStorage ? [{ name: 'EnableAnalyticalStorage' }] : []
)

// Cosmos DB Account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosAccountName
  location: location
  kind: databaseApi == 'MongoDB' ? 'MongoDB' : 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    enableAnalyticalStorage: enableAnalyticalStorage
    enableFreeTier: enableFreeTier
    enableMultipleWriteLocations: enableMultipleWriteLocations
    enableAutomaticFailover: enableAutomaticFailover
    isVirtualNetworkFilterEnabled: enablePrivateEndpoint
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    disableKeyBasedMetadataWriteAccess: true
    disableLocalAuth: false
    enableBurstCapacity: enableBurstCapacity
    enablePartitionMerge: enablePartitionMerge
    minimalTlsVersion: 'Tls12'
    
    consistencyPolicy: {
      defaultConsistencyLevel: consistencyLevel
      maxIntervalInSeconds: consistencyLevel == 'BoundedStaleness' ? maxIntervalInSeconds : null
      maxStalenessPrefix: consistencyLevel == 'BoundedStaleness' ? maxStalenessPrefix : null
    }
    
    locations: locations
    
    capabilities: capabilities
    
    backupPolicy: backupPolicy.type == 'Continuous' ? {
      type: 'Continuous'
      continuousModeProperties: {
        tier: backupPolicy.?tier ?? 'Continuous7Days'
      }
    } : {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: backupPolicy.?intervalInMinutes ?? 240
        backupRetentionIntervalInHours: backupPolicy.?retentionInHours ?? 8
        backupStorageRedundancy: backupPolicy.?storageRedundancy ?? 'Local'
      }
    }
    
    analyticalStorageConfiguration: enableAnalyticalStorage ? {
      schemaType: analyticalStorageSchemaType
    } : null
    
    networkAclBypass: allowAzureServices ? 'AzureServices' : 'None'
    networkAclBypassResourceIds: []
    
    virtualNetworkRules: enablePrivateEndpoint && !empty(subnetId) ? [
      {
        id: subnetId
        ignoreMissingVNetServiceEndpoint: false
      }
    ] : []
    
    ipRules: [for ipRule in ipRules: {
      ipAddressOrRange: ipRule
    }]
    
    cors: []
  }
  tags: union(tags, {
    DatabaseEngine: databaseApi
    ConsistencyLevel: consistencyLevel
  })
}

// Create databases based on API type
resource sqlDatabases 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = [for db in filter(databases, db => databaseApi == 'Sql'): {
  parent: cosmosAccount
  name: db.name
  properties: {
    resource: {
      id: db.name
    }
    options: enableServerless ? {} : {
      throughput: db.?throughput ?? 400
    }
  }
  tags: union(tags, {
    DatabaseName: db.name
  })
}]

// Create containers for SQL databases
resource sqlContainers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = [for (db, dbIndex) in filter(databases, db => databaseApi == 'Sql'): if (contains(db, 'containers')) {
  parent: sqlDatabases[dbIndex]
  name: db.containers[0].name // Single container per iteration
  properties: {
    resource: {
      id: db.containers[0].name
      partitionKey: {
        paths: db.containers[0].partitionKey.paths
        kind: db.containers[0].partitionKey.?kind ?? 'Hash'
      }
      indexingPolicy: db.containers[0].?indexingPolicy ?? {
        indexingMode: 'consistent'
        includedPaths: [{ path: '/*' }]
        excludedPaths: [{ path: '/"_etag"/?' }]
      }
      analyticalStorageTtl: enableAnalyticalStorage ? (db.containers[0].?analyticalStorageTtl ?? -1) : null
      defaultTtl: db.containers[0].?defaultTtl ?? -1
    }
    options: enableServerless ? {} : {
      throughput: db.containers[0].?throughput ?? 400
    }
  }
  tags: union(tags, {
    DatabaseName: db.name
    ContainerName: db.containers[0].name
  })
}]

// MongoDB databases
resource mongoDatabases 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2024-11-15' = [for db in filter(databases, db => databaseApi == 'MongoDB'): {
  parent: cosmosAccount
  name: db.name
  properties: {
    resource: {
      id: db.name
    }
    options: enableServerless ? {} : {
      throughput: db.?throughput ?? 400
    }
  }
  tags: union(tags, {
    DatabaseName: db.name
  })
}]

// Private Endpoint for Cosmos DB (if enabled)
resource cosmosPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (enablePrivateEndpoint && !empty(subnetId)) {
  name: 'pe-${cosmosAccountName}'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'cosmos-connection'
        properties: {
          privateLinkServiceId: cosmosAccount.id
          groupIds: [
            databaseApi == 'Sql' ? 'Sql' : databaseApi == 'MongoDB' ? 'MongoDB' : databaseApi
          ]
        }
      }
    ]
  }
  tags: tags
}

// Private DNS Zone for Cosmos DB (if private endpoint enabled)
var privateDnsZoneName = databaseApi == 'Sql' ? 'privatelink.documents.azure.com' 
  : databaseApi == 'MongoDB' ? 'privatelink.mongo.cosmos.azure.com'
  : databaseApi == 'Cassandra' ? 'privatelink.cassandra.cosmos.azure.com'
  : databaseApi == 'Gremlin' ? 'privatelink.gremlin.cosmos.azure.com'
  : 'privatelink.table.cosmos.azure.com'

resource cosmosPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (enablePrivateEndpoint && !empty(vnetId)) {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to VNet (if private endpoint enabled)
resource cosmosPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (enablePrivateEndpoint && !empty(vnetId)) {
  parent: cosmosPrivateDnsZone
  name: '${cosmosAccountName}-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// DNS Zone Group for Private Endpoint (if private endpoint enabled)
resource cosmosPrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (enablePrivateEndpoint && !empty(subnetId)) {
  parent: cosmosPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: cosmosPrivateDnsZone.id
        }
      }
    ]
  }
}

// Diagnostic Settings for Cosmos DB (if Log Analytics workspace provided)
resource cosmosDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  scope: cosmosAccount
  name: 'CosmosDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
      }
      {
        category: 'PartitionKeyStatistics'
        enabled: true
      }
      {
        category: 'PartitionKeyRUConsumption'
        enabled: true
      }
      {
        category: 'ControlPlaneRequests'
        enabled: true
      }
      {
        category: 'MongoRequests'
        enabled: databaseApi == 'MongoDB'
      }
      {
        category: 'CassandraRequests'
        enabled: databaseApi == 'Cassandra'
      }
      {
        category: 'GremlinRequests'
        enabled: databaseApi == 'Gremlin'
      }
      {
        category: 'TableApiRequests'
        enabled: databaseApi == 'Table'
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Outputs
output cosmosAccountName string = cosmosAccount.name
output cosmosAccountId string = cosmosAccount.id
output cosmosAccountEndpoint string = cosmosAccount.properties.documentEndpoint

output databaseNames array = [for db in databases: {
  name: db.name
  api: databaseApi
}]

output privateEndpointId string = enablePrivateEndpoint ? cosmosPrivateEndpoint.id : ''
output privateDnsZoneId string = enablePrivateEndpoint ? cosmosPrivateDnsZone.id : ''

// Note: Connection strings and access keys are not included in outputs as they contain secrets.
// Use Azure Key Vault or secure application configuration to store these values.
// You can retrieve them programmatically using Azure SDK or Azure CLI:
// - Connection strings: az cosmosdb keys list-connection-strings
// - Access keys: az cosmosdb keys list
