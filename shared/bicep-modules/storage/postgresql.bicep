/*
  Shared PostgreSQL Flexible Server Module
  
  Creates an Azure Database for PostgreSQL Flexible Server with VNet integration,
  security configurations, monitoring, and optimized performance settings.
*/

@description('PostgreSQL server name')
param postgresServerName string

@description('Location for the PostgreSQL server')
param location string

@description('PostgreSQL administrator username')
param adminUsername string

@secure()
@description('PostgreSQL administrator password')
param adminPassword string

@description('Virtual network ID for private DNS zone')
param vnetId string = ''

@description('Subnet ID for PostgreSQL (must be delegated)')
param subnetId string = ''

@description('PostgreSQL version')
@allowed(['11', '12', '13', '14', '15', '16'])
param postgresVersion string = '15'

@description('PostgreSQL SKU')
param sku object = {
  name: 'Standard_B1ms'
  tier: 'Burstable'
}

@description('Storage size in GB')
@minValue(32)
@maxValue(16384)
param storageSizeGB int = 128

@description('Storage type')
@allowed(['Premium_LRS', 'PremiumV2_LRS'])
param storageType string = 'Premium_LRS'

@description('Auto-grow storage')
param storageAutoGrow bool = true

@description('Backup retention days')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Geo-redundant backup')
param geoRedundantBackup bool = false

@description('Enable high availability')
param enableHighAvailability bool = false

@description('High availability mode')
@allowed(['Disabled', 'ZoneRedundant', 'SameZone'])
param highAvailabilityMode string = 'Disabled'

@description('Enable Azure Active Directory authentication')
param enableAadAuth bool = false

@description('Database names to create')
param databaseNames array = []

@description('Custom database configurations')
param customConfigurations array = []

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Resource tags')
param tags object = {}

@description('Maintenance window configuration')
param maintenanceWindow object = {
  customWindow: 'Disabled'
  dayOfWeek: 0
  startHour: 0
  startMinute: 0
}

@description('Performance tier for storage')
@allowed(['P4', 'P6', 'P10', 'P15', 'P20', 'P30', 'P40', 'P50'])
param storageTier string = 'P4'

// Create Private DNS Zone for PostgreSQL
resource postgresPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(vnetId)) {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to VNet
resource postgresPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(vnetId)) {
  parent: postgresPrivateDnsZone
  name: '${postgresServerName}-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: postgresServerName
  location: location
  sku: sku
  properties: {
    version: postgresVersion
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    authConfig: {
      activeDirectoryAuth: enableAadAuth ? 'Enabled' : 'Disabled'
      passwordAuth: 'Enabled'
      tenantId: enableAadAuth ? tenant().tenantId : null
    }
    storage: {
      storageSizeGB: storageSizeGB
      type: storageType
      tier: storageTier
      autoGrow: storageAutoGrow ? 'Enabled' : 'Disabled'
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup ? 'Enabled' : 'Disabled'
    }
    network: !empty(subnetId) ? {
      delegatedSubnetResourceId: subnetId
      privateDnsZoneArmResourceId: postgresPrivateDnsZone.id
      publicNetworkAccess: 'Disabled'
    } : {
      publicNetworkAccess: 'Enabled'
    }
    highAvailability: {
      mode: enableHighAvailability ? highAvailabilityMode : 'Disabled'
    }
    maintenanceWindow: maintenanceWindow
    dataEncryption: {
      type: 'SystemManaged'
    }
  }
  tags: tags
  dependsOn: !empty(vnetId) ? [
    postgresPrivateDnsZoneLink
  ] : []
}

// Default performance configurations for various workload types
var defaultConfigurations = [
  // Memory settings
  {
    name: 'shared_buffers'
    value: storageSizeGB >= 512 ? '512MB' : storageSizeGB >= 256 ? '256MB' : '128MB'
    source: 'user-override'
  }
  {
    name: 'effective_cache_size'
    value: storageSizeGB >= 1024 ? '4GB' : storageSizeGB >= 512 ? '2GB' : '1GB'
    source: 'user-override'
  }
  {
    name: 'maintenance_work_mem'
    value: '64MB'
    source: 'user-override'
  }
  {
    name: 'work_mem'
    value: '4MB'
    source: 'user-override'
  }
  // WAL settings
  {
    name: 'wal_buffers'
    value: '16MB'
    source: 'user-override'
  }
  {
    name: 'checkpoint_completion_target'
    value: '0.9'
    source: 'user-override'
  }
  // Query planner settings
  {
    name: 'random_page_cost'
    value: storageType == 'PremiumV2_LRS' ? '1.0' : '1.1'
    source: 'user-override'
  }
  {
    name: 'seq_page_cost'
    value: '1.0'
    source: 'user-override'
  }
  // Connection settings
  {
    name: 'max_connections'
    value: sku.tier == 'Burstable' ? '50' : '100'
    source: 'user-override'
  }
  // Logging settings
  {
    name: 'log_statement'
    value: 'ddl'
    source: 'user-override'
  }
  {
    name: 'log_min_duration_statement'
    value: '1000'
    source: 'user-override'
  }
]

// Apply default configurations
resource postgresConfigurations 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = [for config in defaultConfigurations: {
  parent: postgresServer
  name: config.name
  properties: {
    value: config.value
    source: config.source
  }
}]

// Apply custom configurations
resource postgresCustomConfigurations 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = [for config in customConfigurations: {
  parent: postgresServer
  name: config.name
  properties: {
    value: config.value
    source: config.?source ?? 'user-override'
  }
  dependsOn: [
    postgresConfigurations
  ]
}]

// Create databases
resource postgresDatabases 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = [for dbName in databaseNames: {
  parent: postgresServer
  name: dbName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}]

// Firewall rule to allow connections from Azure services (if public access enabled)
resource postgresFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = if (empty(subnetId)) {
  parent: postgresServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Diagnostic Settings for PostgreSQL (if Log Analytics workspace provided)
resource postgresDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  scope: postgresServer
  name: 'PostgresDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'PostgreSQLLogs'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexDatabaseXacts'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexQueryStoreRuntime'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexQueryStoreWaitStats'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexSessions'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexTableStats'
        enabled: true
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
output postgresServerName string = postgresServer.name
output postgresServerId string = postgresServer.id
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName

output databaseNames array = [for (dbName, i) in databaseNames: {
  name: dbName
  id: postgresDatabases[i].id
}]

output privateDnsZoneId string = !empty(vnetId) ? postgresPrivateDnsZone.id : ''

// Connection strings (templates)
output connectionStringTemplates object = {
  psql: 'postgresql://${adminUsername}@${postgresServer.properties.fullyQualifiedDomainName}:5432/{DatabaseName}?sslmode=require'
  jdbc: 'jdbc:postgresql://${postgresServer.properties.fullyQualifiedDomainName}:5432/{DatabaseName}?user=${adminUsername}&ssl=true&sslmode=require'
  dotnet: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database={DatabaseName};Username=${adminUsername};SSL Mode=Require;'
  python: 'postgresql://${adminUsername}@${postgresServer.properties.fullyQualifiedDomainName}:5432/{DatabaseName}?sslmode=require'
  nodejs: 'postgresql://${adminUsername}@${postgresServer.properties.fullyQualifiedDomainName}:5432/{DatabaseName}?ssl=true'
}

// Performance configuration summary
output appliedConfigurations object = {
  shared_buffers: storageSizeGB >= 512 ? '512MB' : storageSizeGB >= 256 ? '256MB' : '128MB'
  effective_cache_size: storageSizeGB >= 1024 ? '4GB' : storageSizeGB >= 512 ? '2GB' : '1GB'
  max_connections: sku.tier == 'Burstable' ? '50' : '100'
  storage_optimization: storageType == 'PremiumV2_LRS' ? 'Premium SSD v2' : 'Premium SSD'
}
