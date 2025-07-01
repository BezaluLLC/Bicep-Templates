/*
  Shared SQL Database Module
  
  Creates an Azure SQL Database server and database with security configurations,
  private endpoints, monitoring, and best practices applied.
*/

@description('SQL Server name')
param sqlServerName string

@description('SQL Database name (can be array for multiple databases)')
param databaseNames array = []

@description('Location for the SQL resources')
param location string

@description('SQL Server administrator username')
param adminUsername string

@secure()
@description('SQL Server administrator password')
param adminPassword string

@description('Virtual network ID for private endpoint')
param vnetId string = ''

@description('Subnet ID for private endpoint')
param subnetId string = ''

@description('Enable private endpoint')
param enablePrivateEndpoint bool = true

@description('SQL Database SKU')
param databaseSku object = {
  name: 'GP_S_Gen5'
  tier: 'GeneralPurpose'
  family: 'Gen5'
  capacity: 1
}

@description('SQL Database max size in bytes')
param maxSizeBytes int = 34359738368 // 32 GB

@description('Enable Azure Active Directory authentication')
param enableAadAuth bool = true

@description('Azure AD admin object ID')
param aadAdminObjectId string = ''

@description('Azure AD admin login name')
param aadAdminLogin string = ''

@description('Enable auditing')
param enableAuditing bool = true

@description('Enable threat detection')
param enableThreatDetection bool = true

@description('Enable vulnerability assessment')
param enableVulnerabilityAssessment bool = true

@description('Storage account ID for vulnerability assessment (optional)')
param vulnerabilityAssessmentStorageId string = ''

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Backup storage redundancy')
@allowed(['Local', 'Zone', 'Geo', 'GeoZone'])
param backupStorageRedundancy string = 'Local'

@description('Zone redundant database')
param zoneRedundant bool = false

@description('Resource tags')
param tags object = {}

@description('Firewall rules (array of objects with name, startIpAddress, endIpAddress)')
param firewallRules array = []

@description('Allow Azure services access')
param allowAzureServices bool = true

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
  tags: tags

  // Azure AD Administrator (if enabled)
  resource aadAdmin 'administrators@2023-08-01-preview' = if (enableAadAuth && !empty(aadAdminObjectId)) {
    name: 'ActiveDirectory'
    properties: {
      administratorType: 'ActiveDirectory'
      login: aadAdminLogin
      sid: aadAdminObjectId
      tenantId: tenant().tenantId
    }
  }

  // Firewall rules
  resource allowAzureIps 'firewallRules@2023-08-01-preview' = if (allowAzureServices) {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }

  // Custom firewall rules
  resource customFirewallRules 'firewallRules@2023-08-01-preview' = [for rule in firewallRules: {
    name: rule.name
    properties: {
      startIpAddress: rule.startIpAddress
      endIpAddress: rule.endIpAddress
    }
  }]

  // Security configurations
  resource securityAlertPolicy 'securityAlertPolicies@2023-08-01-preview' = if (enableThreatDetection) {
    name: 'Default'
    properties: {
      state: 'Enabled'
      disabledAlerts: []
      emailAddresses: []
      emailAccountAdmins: true
      retentionDays: 30
    }
  }

  resource vulnerabilityAssessment 'vulnerabilityAssessments@2023-08-01-preview' = if (enableVulnerabilityAssessment && !empty(vulnerabilityAssessmentStorageId)) {
    name: 'Default'
    properties: {
      storageContainerPath: '${vulnerabilityAssessmentStorageId}/vulnerability-assessment'
      recurringScans: {
        isEnabled: true
        emailSubscriptionAdmins: true
        emails: []
      }
    }
    dependsOn: [
      securityAlertPolicy
    ]
  }

  resource auditingSettings 'auditingSettings@2023-08-01-preview' = if (enableAuditing) {
    name: 'default'
    properties: {
      state: 'Enabled'
      retentionDays: 30
      auditActionsAndGroups: [
        'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
        'FAILED_DATABASE_AUTHENTICATION_GROUP'
        'BATCH_COMPLETED_GROUP'
      ]
      isStorageSecondaryKeyInUse: false
      isAzureMonitorTargetEnabled: !empty(logAnalyticsWorkspaceId)
    }
  }
}

// SQL Databases
resource databases 'Microsoft.Sql/servers/databases@2023-08-01-preview' = [for dbName in databaseNames: {
  parent: sqlServer
  name: dbName
  location: location
  sku: databaseSku
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: maxSizeBytes
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: zoneRedundant
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: backupStorageRedundancy
    isLedgerOn: false
    maintenanceConfigurationId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Maintenance/publicMaintenanceConfigurations/SQL_Default'
  }
  tags: union(tags, {
    DatabaseName: dbName
  })
}]

// Private Endpoint (if enabled)
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (enablePrivateEndpoint && !empty(subnetId)) {
  name: 'pe-${sqlServerName}'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'sql-connection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
  tags: tags
}

// Private DNS Zone for SQL Server (if private endpoint enabled)
resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (enablePrivateEndpoint && !empty(vnetId)) {
  name: 'privatelink${az.environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to VNet (if private endpoint enabled)
resource sqlPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (enablePrivateEndpoint && !empty(vnetId)) {
  parent: sqlPrivateDnsZone
  name: '${sqlServerName}-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// DNS Zone Group for Private Endpoint (if private endpoint enabled)
resource sqlPrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (enablePrivateEndpoint && !empty(subnetId)) {
  parent: sqlPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZone.id
        }
      }
    ]
  }
}

// Diagnostic Settings for SQL Databases (if Log Analytics workspace provided)
resource databaseDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (dbName, i) in databaseNames: if (!empty(logAnalyticsWorkspaceId)) {
  scope: databases[i]
  name: '${dbName}-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLInsights'
        enabled: true
      }
      {
        category: 'AutomaticTuning'
        enabled: true
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: true
      }
      {
        category: 'Errors'
        enabled: true
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled: true
      }
      {
        category: 'Timeouts'
        enabled: true
      }
      {
        category: 'Blocks'
        enabled: true
      }
      {
        category: 'Deadlocks'
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
}]

// Outputs
output sqlServerName string = sqlServer.name
output sqlServerId string = sqlServer.id
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

output databaseNames array = [for (dbName, i) in databaseNames: {
  name: dbName
  id: databases[i].id
}]

output privateEndpointId string = enablePrivateEndpoint ? sqlPrivateEndpoint.id : ''
output privateDnsZoneId string = enablePrivateEndpoint ? sqlPrivateDnsZone.id : ''

// Connection strings (examples)
output connectionStringTemplate object = {
  adonet: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog={DatabaseName};Persist Security Info=False;User ID=${adminUsername};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
  odbc: 'Driver={ODBC Driver 18 for SQL Server};Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database={DatabaseName};Uid=${adminUsername};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;'
  jdbc: 'jdbc:sqlserver://${sqlServer.properties.fullyQualifiedDomainName}:1433;database={DatabaseName};user=${adminUsername};encrypt=true;trustServerCertificate=false;loginTimeout=30;'
}
