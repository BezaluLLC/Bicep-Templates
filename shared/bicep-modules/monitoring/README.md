# Monitoring Modules

This directory contains Bicep modules for Azure monitoring and observability services.

## Available Modules

### 📊 **Log Analytics** (`loganalytics.bicep`)

Creates a Log Analytics workspace with optional Application Insights for centralized monitoring and logging across Azure workloads.

#### Features
- **Configurable SKU**: Support for all Log Analytics pricing tiers
- **Flexible Retention**: 7-730 days retention with environment-based defaults
- **Daily Quota**: Configurable ingestion limits to control costs
- **Application Insights**: Optional integration for application monitoring
- **Activity Log**: Automatic diagnostic settings for Azure Activity Log
- **Security**: Network access controls and authentication options
- **Tagging**: Comprehensive tagging strategy for governance

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `workspaceName` | string | *required* | Log Analytics workspace name (4-63 chars) |
| `location` | string | *required* | Azure region for deployment |
| `environment` | string | `dev` | Environment identifier (dev/test/staging/prod) |
| `tags` | object | `{}` | Resource tags |
| `sku` | string | `PerGB2018` | Log Analytics SKU |
| `retentionInDays` | int | 30 (90 for prod) | Data retention period |
| `dailyQuotaGb` | int | 1 (10 for prod) | Daily ingestion quota in GB |
| `deployApplicationInsights` | bool | `false` | Deploy Application Insights |
| `applicationInsightsType` | string | `web` | Application Insights type |
| `publicNetworkAccessForIngestion` | string | `Enabled` | Public network access for ingestion |
| `publicNetworkAccessForQuery` | string | `Enabled` | Public network access for queries |
| `disableLocalAuth` | bool | `false` | Disable local authentication |
| `deployActivityLogDiagnostics` | bool | `true` | Deploy Activity Log diagnostics |

#### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `workspaceName` | string | Log Analytics workspace name |
| `workspaceId` | string | Log Analytics workspace resource ID |
| `customerId` | string | Workspace customer ID for agents |
| `workspaceLocation` | string | Workspace location |
| `applicationInsightsName` | string | Application Insights name (if deployed) |
| `applicationInsightsId` | string | Application Insights resource ID (if deployed) |
| `applicationInsightsInstrumentationKey` | string | Instrumentation key (if deployed) |
| `applicationInsightsConnectionString` | string | Connection string (if deployed) |
| `applicationInsightsDeployed` | bool | Whether Application Insights was deployed |

#### Usage Examples

##### Basic Log Analytics Workspace
```bicep
module monitoring '../shared/bicep-modules/monitoring/loganalytics.bicep' = {
  name: 'deploy-monitoring'
  params: {
    workspaceName: 'law-${uniqueString(resourceGroup().id)}'
    location: location
    environment: 'dev'
    tags: {
      Project: 'MyProject'
      CostCenter: '12345'
    }
  }
}
```

##### Production Configuration with Application Insights
```bicep
module monitoring '../shared/bicep-modules/monitoring/loganalytics.bicep' = {
  name: 'deploy-monitoring'
  params: {
    workspaceName: 'law-prod-myapp'
    location: location
    environment: 'prod'
    sku: 'PerGB2018'
    retentionInDays: 180
    dailyQuotaGb: 50
    deployApplicationInsights: true
    applicationName: 'myapp'
    applicationInsightsType: 'web'
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
    disableLocalAuth: true
    tags: {
      Project: 'MyApp'
      Environment: 'Production'
      CostCenter: '12345'
    }
  }
}
```

##### Integration with Other Modules
```bicep
// Deploy Log Analytics first
module monitoring '../shared/bicep-modules/monitoring/loganalytics.bicep' = {
  name: 'deploy-monitoring'
  params: {
    workspaceName: 'law-${uniqueString(resourceGroup().id)}'
    location: location
    environment: environment
    tags: resourceTags
  }
}

// Use monitoring outputs in other modules
module keyVault '../shared/bicep-modules/security/keyvault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    keyVaultName: 'kv-${uniqueString(resourceGroup().id)}'
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: resourceTags
  }
}
```

#### Environment-Based Defaults

The module automatically adjusts settings based on the environment parameter:

| Setting | dev/test | staging | prod |
|---------|----------|---------|------|
| Retention Days | 30 | 60 | 90 |
| Daily Quota GB | 1 | 5 | 10 |
| Recommended SKU | PerGB2018 | PerGB2018 | PerGB2018 |

#### Security Considerations

##### Network Security
- **Public Access**: Can be disabled for production environments
- **Private Endpoints**: Consider using private endpoints for enhanced security
- **Firewall Rules**: Configure workspace firewall rules if needed

##### Authentication
- **Azure AD**: Enable `disableLocalAuth` for Azure AD-only access
- **RBAC**: Use Log Analytics Reader/Contributor roles
- **Managed Identity**: Preferred for application access

##### Data Protection
- **Encryption**: Data encrypted at rest and in transit by default
- **Retention**: Configure appropriate retention based on compliance requirements
- **Purge**: Consider data purge policies for sensitive information

#### Cost Optimization

##### SKU Selection
- **Free**: 500MB/day limit, 7-day retention (dev only)
- **PerGB2018**: Pay-per-GB ingestion (recommended)
- **PerNode**: Fixed cost per monitored node

##### Quota Management
- Set appropriate daily quotas to prevent cost overruns
- Monitor ingestion patterns and adjust quotas
- Use sampling for high-volume applications

##### Retention Optimization
- Shorter retention for development environments
- Longer retention for production and compliance
- Consider exporting old data to cheaper storage

#### Monitoring Integration

##### Common Data Sources
```bicep
// Example: Configure VM monitoring
resource vmDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: virtualMachine
  name: 'vm-diagnostics'
  properties: {
    workspaceId: monitoring.outputs.workspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
```

##### Query Examples
```kql
// Resource usage over time
AzureMetrics
| where TimeGenerated > ago(24h)
| where MetricName == "Percentage CPU"
| summarize avg(Average) by bin(TimeGenerated, 1h), Resource

// Application Insights traces
traces
| where timestamp > ago(1h)
| where severityLevel >= 2
| project timestamp, message, severityLevel, customDimensions
```

## Migration Guide

### From Data Warehouse Module
Replace the existing loganalytics module reference:

```bicep
// Old reference
module logAnalytics 'modules/loganalytics.bicep' = {
  // ... parameters
}

// New reference
module logAnalytics '../shared/bicep-modules/monitoring/loganalytics.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    workspaceName: logAnalyticsName
    location: location
    environment: environment
    deployApplicationInsights: true
    // ... other parameters
  }
}
```

### From Universal Print Connector Module
Replace the existing monitoring module reference:

```bicep
// Old reference
module monitoring 'modules/monitoring.bicep' = {
  // ... parameters
}

// New reference
module monitoring '../shared/bicep-modules/monitoring/loganalytics.bicep' = {
  name: 'deploy-monitoring'
  params: {
    workspaceName: workspaceName
    location: location
    environment: 'dev'
    retentionInDays: logRetentionDays
    tags: tags
  }
}
```

## Troubleshooting

### Common Issues

1. **Workspace Name Conflicts**
   - Workspace names must be unique within subscription
   - Use `uniqueString()` function for unique naming

2. **Quota Exceeded**
   - Monitor daily ingestion against quota
   - Adjust quota or implement data filtering

3. **Retention Limits**
   - Free tier limited to 7 days
   - Paid tiers support 7-730 days

### Validation

```bicep
// Test deployment
module test '../shared/bicep-modules/monitoring/loganalytics.bicep' = {
  name: 'test-monitoring'
  params: {
    workspaceName: 'law-test-${uniqueString(resourceGroup().id)}'
    location: 'eastus2'
    environment: 'dev'
  }
}

// Verify outputs
output testWorkspaceId string = test.outputs.workspaceId
output testCustomerId string = test.outputs.customerId
```

---

**Module Version**: 1.0.0  
**Last Updated**: June 20, 2025  
**Next Review**: July 20, 2025
