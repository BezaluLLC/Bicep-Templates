/*
  Shared Log Analytics Workspace Module
  
  Creates a Log Analytics workspace with optional Application Insights for centralized 
  monitoring and logging across Azure workloads. Follows Azure monitoring best practices
  with configurable security, retention, and alerting capabilities.
  
  Features:
  - Log Analytics workspace with configurable SKU and retention
  - Optional Application Insights integration
  - Configurable daily quota limits based on environment
  - Diagnostic settings for Azure Activity Log
  - Network access controls
  - Comprehensive tagging strategy
  
  Version: 1.0.0
  Last Updated: 2025-06-20
*/

// === PARAMETERS ===

@description('Log Analytics workspace name (must be unique within subscription)')
@minLength(4)
@maxLength(63)
param workspaceName string

@description('Azure region for deployment')
param location string

@description('Environment identifier (affects default quota and retention settings)')
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string = 'dev'

@description('Resource tags for Azure resources')
param tags object = {}

// === WORKSPACE CONFIGURATION ===

@description('Log Analytics workspace SKU')
@allowed(['Free', 'Standard', 'Premium', 'PerNode', 'PerGB2018', 'Standalone'])
param sku string = 'PerGB2018'

@description('Data retention period in days')
@minValue(7)
@maxValue(730)
param retentionInDays int = environment == 'prod' ? 90 : 30

@description('Daily ingestion quota in GB (0 = unlimited)')
@minValue(0)
@maxValue(1000)
param dailyQuotaGb int = environment == 'prod' ? 10 : 1

// === APPLICATION INSIGHTS CONFIGURATION ===

@description('Deploy Application Insights component')
param deployApplicationInsights bool = false

@description('Application Insights application type')
@allowed(['web', 'other'])
param applicationInsightsType string = 'web'

@description('Application name for Application Insights (defaults to workspace name)')
param applicationName string = workspaceName

// === SECURITY CONFIGURATION ===

@description('Public network access for log ingestion')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccessForIngestion string = 'Enabled'

@description('Public network access for query access')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccessForQuery string = 'Enabled'

@description('Disable local authentication (Azure AD only)')
param disableLocalAuth bool = false

// === MONITORING CONFIGURATION ===

@description('Deploy diagnostic settings for Activity Log')
param deployActivityLogDiagnostics bool = true

@description('Enable log access using only resource permissions')
param enableLogAccessUsingOnlyResourcePermissions bool = true

// === VARIABLES ===

var standardTags = union(tags, {
  ModuleSource: 'shared/bicep-modules/monitoring'
  ModuleVersion: '1.0.0'
  Environment: environment
  Purpose: 'Monitoring'
})

var workspaceProperties = {
  sku: {
    name: sku
  }
  retentionInDays: retentionInDays
  features: {
    enableLogAccessUsingOnlyResourcePermissions: enableLogAccessUsingOnlyResourcePermissions
    disableLocalAuth: disableLocalAuth
  }
  workspaceCapping: dailyQuotaGb > 0 ? {
    dailyQuotaGb: dailyQuotaGb
  } : null
  publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
  publicNetworkAccessForQuery: publicNetworkAccessForQuery
}

// === RESOURCES ===

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: workspaceProperties
  tags: standardTags
}

// Application Insights (conditional deployment)
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = if (deployApplicationInsights) {
  name: 'appi-${applicationName}'
  location: location
  kind: applicationInsightsType
  properties: {
    Application_Type: applicationInsightsType
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
  }
  tags: union(standardTags, {
    Purpose: 'Application Monitoring'
  })
}

// Activity Log Diagnostic Settings (conditional deployment)
resource activityLogDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployActivityLogDiagnostics) {
  scope: resourceGroup()
  name: 'ActivityLog-${workspaceName}'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'Administrative'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
      {
        category: 'Security'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
      {
        category: 'Alert'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
      {
        category: 'Policy'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
      {
        category: 'Autoscale'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
    ]
  }
}

// === OUTPUTS ===

@description('Log Analytics workspace name')
output workspaceName string = logAnalyticsWorkspace.name

@description('Log Analytics workspace resource ID')
output workspaceId string = logAnalyticsWorkspace.id

@description('Log Analytics workspace customer ID (for agent configuration)')
output customerId string = logAnalyticsWorkspace.properties.customerId

@description('Log Analytics workspace location')
output workspaceLocation string = logAnalyticsWorkspace.location

@description('Application Insights name (if deployed)')
output applicationInsightsName string = deployApplicationInsights ? applicationInsights.name : ''

@description('Application Insights resource ID (if deployed)')
output applicationInsightsId string = deployApplicationInsights ? applicationInsights.id : ''

@description('Application Insights instrumentation key (if deployed)')
output applicationInsightsInstrumentationKey string = deployApplicationInsights ? applicationInsights.properties.InstrumentationKey : ''

@description('Application Insights connection string (if deployed)')
output applicationInsightsConnectionString string = deployApplicationInsights ? applicationInsights.properties.ConnectionString : ''

@description('Application Insights deployed status')
output applicationInsightsDeployed bool = deployApplicationInsights
