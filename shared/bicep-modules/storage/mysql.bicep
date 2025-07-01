/*
  Shared MySQL Flexible Server Module
  
  Creates an Azure Database for MySQL Flexible Server with comprehensive configuration options
  including networking, backup, high availability, and monitoring.
*/

@description('MySQL server name')
param serverName string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('MySQL version')
@allowed(['5.7', '8.0'])
param mysqlVersion string = '8.0'

@description('Administrator username')
param adminUsername string

@description('Administrator password')
@secure()
param adminPassword string

@description('Server SKU configuration')
param sku object = {
  name: 'Standard_B2s'
  tier: 'Burstable'
}

@description('Storage configuration in GB')
param storageSizeGB int = 20

@description('Enable storage auto-grow')
param enableStorageAutoGrow bool = true

@description('Backup retention days (7-35)')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Enable geo-redundant backup')
param enableGeoRedundantBackup bool = false

@description('High availability configuration')
param highAvailability object = {
  mode: 'Disabled' // 'Disabled', 'ZoneRedundant', 'SameZone'
  standbyAvailabilityZone: '1'
}

@description('Virtual network configuration')
param networkConfig object = {
  delegatedSubnetId: ''
  privateDnsZoneId: ''
}

@description('Enable public network access')
param enablePublicNetworkAccess bool = false

@description('Firewall rules for public access')
param firewallRules array = []

@description('MySQL configuration parameters')
param mysqlConfigurations object = {}

@description('Enable monitoring and diagnostics')
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
var isVNetIntegrated = !empty(networkConfig.delegatedSubnetId)
var haMode = highAvailability.mode
var enableHA = haMode != 'Disabled'

// Extract VNet ID from subnet ID
var vnetId = isVNetIntegrated ? substring(networkConfig.delegatedSubnetId, 0, lastIndexOf(networkConfig.delegatedSubnetId, '/subnets/')) : ''

// Create MySQL Flexible Server
resource mysqlServer 'Microsoft.DBforMySQL/flexibleServers@2023-12-30' = {
  name: serverName
  location: location
  sku: sku
  properties: {
    version: mysqlVersion
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    availabilityZone: enableHA ? '1' : null
    highAvailability: enableHA ? {
      mode: haMode
      standbyAvailabilityZone: highAvailability.standbyAvailabilityZone
    } : null
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: enableStorageAutoGrow ? 'Enabled' : 'Disabled'
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: enableGeoRedundantBackup ? 'Enabled' : 'Disabled'
    }
    network: isVNetIntegrated ? {
      delegatedSubnetResourceId: networkConfig.delegatedSubnetId
      privateDnsZoneResourceId: networkConfig.privateDnsZoneId
    } : null
    createMode: 'Default'
    dataEncryption: {
      type: 'SystemManaged'
    }
  }
  tags: tags
}

// Configure MySQL parameters
resource mysqlConfigurations_resource 'Microsoft.DBforMySQL/flexibleServers/configurations@2023-12-30' = [for configName in items(mysqlConfigurations): {
  parent: mysqlServer
  name: configName.key
  properties: {
    value: configName.value
    source: 'user-override'
  }
}]

// Create firewall rules for public access
resource firewallRules_resource 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2023-12-30' = [for rule in firewallRules: if (!isVNetIntegrated && enablePublicNetworkAccess) {
  parent: mysqlServer
  name: rule.name
  properties: {
    startIpAddress: rule.startIpAddress
    endIpAddress: rule.endIpAddress
  }
}]

// Create private DNS zone (if not provided and VNet integrated)
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (isVNetIntegrated && empty(networkConfig.privateDnsZoneId)) {
  name: 'privatelink.mysql.database.azure.com'
  location: 'global'
  tags: tags
}

// Link private DNS zone to VNet (if created here)
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (isVNetIntegrated && empty(networkConfig.privateDnsZoneId)) {
  parent: privateDnsZone
  name: '${serverName}-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
  tags: tags
}

// Diagnostic settings
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${serverName}-diagnostics'
  scope: mysqlServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: diagnosticSettings.logs
    metrics: diagnosticSettings.metrics
  }
}

// Outputs
output serverId string = mysqlServer.id
output serverName string = mysqlServer.name
output serverFqdn string = mysqlServer.properties.fullyQualifiedDomainName
output adminUsername string = adminUsername
output privateDnsZoneId string = isVNetIntegrated && empty(networkConfig.privateDnsZoneId) ? privateDnsZone.id : networkConfig.privateDnsZoneId
