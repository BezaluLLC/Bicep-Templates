/*
  Shared Storage Account Module
  
  Creates an Azure Storage Account with configurable features including:
  - Data Lake Gen2 (hierarchical namespace)
  - Private endpoints for blob, dfs, file, queue, and table services
  - Blob containers with lifecycle management
  - File shares
  - Security and encryption configurations
  - Diagnostic settings
*/

@description('Storage account name')
param storageAccountName string

@description('Location for the storage account')
param location string

@description('Storage account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Standard_GZRS', 'Standard_RAGZRS', 'Premium_LRS', 'Premium_ZRS'])
param storageAccountSku string = 'Standard_LRS'

@description('Storage account kind')
@allowed(['Storage', 'StorageV2', 'BlobStorage', 'FileStorage', 'BlockBlobStorage'])
param storageAccountKind string = 'StorageV2'

@description('Access tier for the storage account')
@allowed(['Hot', 'Cool'])
param accessTier string = 'Hot'

@description('Enable hierarchical namespace (Data Lake Gen2)')
param enableHierarchicalNamespace bool = false

@description('Enable SFTP support')
param enableSftp bool = false

@description('Enable NFS v3 support')
param enableNfsV3 bool = false

@description('Enable large file shares')
param enableLargeFileShares bool = false

@description('Allow blob public access')
param allowBlobPublicAccess bool = false

@description('Allow shared key access')
param allowSharedKeyAccess bool = true

@description('Default to OAuth authentication')
param defaultToOAuthAuthentication bool = false

@description('Public network access')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

@description('Minimum TLS version')
@allowed(['TLS1_0', 'TLS1_1', 'TLS1_2'])
param minimumTlsVersion string = 'TLS1_2'

@description('Require infrastructure encryption')
param requireInfrastructureEncryption bool = false

@description('Allow cross-tenant replication')
param allowCrossTenantReplication bool = false

@description('Virtual network rules for network ACLs')
param virtualNetworkRules array = []

@description('IP rules for network ACLs (CIDR blocks or IP addresses)')
param ipRules array = []

@description('Network ACLs bypass setting')
@allowed(['None', 'Logging', 'Metrics', 'AzureServices'])
param networkAclsBypass string = 'AzureServices'

@description('Network ACLs default action')
@allowed(['Allow', 'Deny'])
param networkAclsDefaultAction string = 'Allow'

@description('Blob containers to create')
param blobContainers array = []

@description('File shares to create')
param fileShares array = []

@description('Enable blob soft delete')
param enableBlobSoftDelete bool = true

@description('Blob soft delete retention days')
param blobSoftDeleteRetentionDays int = 7

@description('Enable container soft delete')
param enableContainerSoftDelete bool = true

@description('Container soft delete retention days')
param containerSoftDeleteRetentionDays int = 7

@description('Enable blob versioning')
param enableBlobVersioning bool = false

@description('Enable blob change feed')
param enableBlobChangeFeed bool = false

@description('Blob change feed retention days')
param blobChangeFeedRetentionDays int = 7

@description('Enable point-in-time restore')
param enablePointInTimeRestore bool = false

@description('Point-in-time restore retention days')
param pointInTimeRestoreRetentionDays int = 6

@description('Enable file soft delete')
param enableFileSoftDelete bool = true

@description('File soft delete retention days')
param fileSoftDeleteRetentionDays int = 7

@description('Private endpoint configuration')
param privateEndpointConfig object = {
  enabled: false
  subnetId: ''
  vnetId: ''
  services: ['blob'] // Available: blob, dfs, file, queue, table
}

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Resource tags')
param tags object = {}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSku
  }
  kind: storageAccountKind
  properties: {
    accessTier: accessTier
    isHnsEnabled: enableHierarchicalNamespace
    isSftpEnabled: enableSftp
    isNfsV3Enabled: enableNfsV3
    isLocalUserEnabled: enableSftp
    minimumTlsVersion: minimumTlsVersion
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication: defaultToOAuthAuthentication
    publicNetworkAccess: publicNetworkAccess
    supportsHttpsTrafficOnly: true
    largeFileSharesState: enableLargeFileShares ? 'Enabled' : 'Disabled'
    networkAcls: {
      bypass: networkAclsBypass
      defaultAction: networkAclsDefaultAction
      virtualNetworkRules: [for rule in virtualNetworkRules: {
        id: rule.subnetId
        action: rule.action
        state: rule.?state ?? 'Succeeded'
      }]
      ipRules: [for rule in ipRules: {
        action: 'Allow'
        value: rule
      }]
    }
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
        queue: {
          keyType: 'Account'
          enabled: true
        }
        table: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: requireInfrastructureEncryption
    }
    allowCrossTenantReplication: allowCrossTenantReplication
    allowedCopyScope: allowCrossTenantReplication ? 'FromAnyAccount' : 'AAD'
  }
  tags: tags
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: enableBlobSoftDelete
      days: blobSoftDeleteRetentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: enableContainerSoftDelete
      days: containerSoftDeleteRetentionDays
    }
    isVersioningEnabled: enableBlobVersioning
    changeFeed: {
      enabled: enableBlobChangeFeed
      retentionInDays: enableBlobChangeFeed ? blobChangeFeedRetentionDays : null
    }
    restorePolicy: {
      enabled: enablePointInTimeRestore
      days: enablePointInTimeRestore ? pointInTimeRestoreRetentionDays : null
    }
    cors: {
      corsRules: []
    }
  }
}

// Blob Containers
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for container in blobContainers: {
  parent: blobService
  name: container.name
  properties: {
    publicAccess: container.?publicAccess ?? 'None'
    metadata: container.?metadata ?? {}
  }
}]

// File Service
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = if (length(fileShares) > 0 || enableFileSoftDelete) {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: enableFileSoftDelete
      days: fileSoftDeleteRetentionDays
    }
    cors: {
      corsRules: []
    }
  }
}

// File Shares
resource shares 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = [for share in fileShares: {
  parent: fileService
  name: share.name
  properties: {
    shareQuota: share.?quota ?? 5120
    enabledProtocols: share.?enabledProtocols ?? 'SMB'
    metadata: share.?metadata ?? {}
  }
}]

// Private Endpoints
resource privateEndpoints 'Microsoft.Network/privateEndpoints@2024-05-01' = [for service in privateEndpointConfig.services: if (privateEndpointConfig.enabled) {
  name: 'pe-${storageAccountName}-${service}'
  location: location
  properties: {
    subnet: {
      id: privateEndpointConfig.subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${service}-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [service]
        }
      }
    ]
  }
  tags: tags
}]

// Private DNS Zones
var privateDnsZoneNames = {
  blob: 'privatelink.blob.${az.environment().suffixes.storage}'
  dfs: 'privatelink.dfs.${az.environment().suffixes.storage}'
  file: 'privatelink.file.${az.environment().suffixes.storage}'
  queue: 'privatelink.queue.${az.environment().suffixes.storage}'
  table: 'privatelink.table.${az.environment().suffixes.storage}'
}

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for service in privateEndpointConfig.services: if (privateEndpointConfig.enabled) {
  name: privateDnsZoneNames[service]
  location: 'global'
  tags: tags
}]

// Link Private DNS Zones to VNet
resource privateDnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (service, i) in privateEndpointConfig.services: if (privateEndpointConfig.enabled) {
  parent: privateDnsZones[i]
  name: '${storageAccountName}-${service}-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: privateEndpointConfig.vnetId
    }
  }
}]

// DNS Zone Groups for Private Endpoints
resource privateEndpointDnsGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = [for (service, i) in privateEndpointConfig.services: if (privateEndpointConfig.enabled) {
  parent: privateEndpoints[i]
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateDnsZones[i].id
        }
      }
    ]
  }
}]

// Diagnostic Settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  scope: blobService
  name: 'StorageAccountDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
output primaryLocation string = storageAccount.properties.primaryLocation
output statusOfPrimary string = storageAccount.properties.statusOfPrimary

output blobServiceId string = blobService.id
output fileServiceId string = length(fileShares) > 0 || enableFileSoftDelete ? fileService.id : ''

output containerNames array = [for (container, i) in blobContainers: containers[i].name]
output shareNames array = [for (share, i) in fileShares: shares[i].name]

// Private endpoint and DNS zone outputs (conditional)
var privateEndpointIdArray = [for (service, i) in privateEndpointConfig.services: privateEndpoints[i].id]
var privateDnsZoneIdArray = [for (service, i) in privateEndpointConfig.services: privateDnsZones[i].id]

output privateEndpointIds array = privateEndpointConfig.enabled ? privateEndpointIdArray : []
output privateDnsZoneIds array = privateEndpointConfig.enabled ? privateDnsZoneIdArray : []

// Note: Storage account keys and connection strings are not included in outputs as they contain secrets.
// Use Azure Key Vault or secure application configuration to store these values.
// You can retrieve them programmatically using Azure SDK or Azure CLI:
// - Primary key: az storage account keys list --account-name <name>
// - Connection string: az storage account show-connection-string --name <name>
