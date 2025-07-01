# Integration Modules

This directory contains reusable Bicep modules for Azure integration services and data processing components.

## 📁 **Available Modules**

### **Data Factory Module**
- **File**: `data-factory.bicep`
- **Purpose**: Creates and configures Azure Data Factory instances for ETL/ELT data processing
- **Key Features**:
  - Managed virtual network integration
  - Configurable integration runtimes (AutoResolve, Azure, SelfHosted)
  - Git repository integration support
  - Global parameters configuration
  - Diagnostic settings integration

## 🚀 **Usage Examples**

### **Basic Data Factory**
```bicep
module dataFactory 'br/public:integration/data-factory:1.0' = {
  name: 'basic-data-factory'
  params: {
    dataFactoryName: 'df-myproject-prod'
    location: 'East US'
    enableManagedVNet: true
    publicNetworkAccess: 'Disabled'
    enableDiagnostics: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: {
      Environment: 'Production'
      Project: 'MyProject'
    }
  }
}
```

### **Data Factory with Custom Integration Runtimes**
```bicep
module dataFactory 'br/public:integration/data-factory:1.0' = {
  name: 'advanced-data-factory'
  params: {
    dataFactoryName: 'df-advanced-prod'
    location: 'East US'
    enableManagedVNet: true
    publicNetworkAccess: 'Disabled'
    integrationRuntimes: [
      {
        name: 'AutoResolveIntegrationRuntime'
        type: 'AutoResolve'
        computeType: 'General'
        coreCount: 8
        timeToLive: 10
      }
      {
        name: 'AzureIR-EastUS'
        type: 'Azure'
        location: 'East US'
        computeType: 'MemoryOptimized'
        coreCount: 16
        timeToLive: 15
      }
    ]
    globalParameters: {
      environment: {
        type: 'string'
        value: 'production'
      }
      batchSize: {
        type: 'int'
        value: 1000
      }
    }
    enableDiagnostics: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: {
      Environment: 'Production'
      Project: 'MyProject'
      CostCenter: 'DataPlatform'
    }
  }
}
```

### **Data Factory with Git Integration**
```bicep
module dataFactory 'br/public:integration/data-factory:1.0' = {
  name: 'git-integrated-data-factory'
  params: {
    dataFactoryName: 'df-gitops-prod'
    location: 'East US'
    enableManagedVNet: true
    publicNetworkAccess: 'Disabled'
    gitRepoConfig: {
      type: 'FactoryGitHubConfiguration'
      accountName: 'myorganization'
      repositoryName: 'data-factory-pipelines'
      collaborationBranch: 'main'
      rootFolder: '/datafactory'
    }
    enableDiagnostics: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: {
      Environment: 'Production'
      Project: 'DataPlatform'
    }
  }
}
```

## 📋 **Module Parameters**

### **Data Factory Module Parameters**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `dataFactoryName` | string | Yes | - | Name of the Data Factory |
| `location` | string | No | `resourceGroup().location` | Azure region for deployment |
| `enableManagedVNet` | bool | No | `true` | Enable managed virtual network |
| `publicNetworkAccess` | string | No | `'Disabled'` | Public network access setting |
| `gitRepoConfig` | object | No | `{}` | Git repository configuration |
| `globalParameters` | object | No | `{}` | Global parameters for Data Factory |
| `integrationRuntimes` | array | No | Default array | Integration runtime configurations |
| `enableDiagnostics` | bool | No | `true` | Enable diagnostic settings |
| `logAnalyticsWorkspaceId` | string | No | `''` | Log Analytics workspace resource ID |
| `diagnosticSettings` | object | No | Default object | Diagnostic settings configuration |
| `tags` | object | No | `{}` | Resource tags |

### **Integration Runtime Configuration**

Each integration runtime in the `integrationRuntimes` array supports:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | Name of the integration runtime |
| `type` | string | Yes | Type: 'AutoResolve', 'Azure', or 'SelfHosted' |
| `location` | string | No | Azure region (for Azure type) |
| `computeType` | string | No | Compute type: 'General', 'MemoryOptimized', 'ComputeOptimized' |
| `coreCount` | int | No | Number of cores (4, 8, 16, 32, 48, 80, 144, 272) |
| `timeToLive` | int | No | Time to live in minutes |
| `description` | string | No | Description (for SelfHosted type) |

## 📤 **Module Outputs**

### **Data Factory Module Outputs**

| Output | Type | Description |
|--------|------|-------------|
| `dataFactoryId` | string | Resource ID of the Data Factory |
| `dataFactoryName` | string | Name of the Data Factory |
| `systemAssignedIdentityPrincipalId` | string | Principal ID of the system-assigned managed identity |
| `managedVirtualNetworkName` | string | Name of the managed virtual network |
| `integrationRuntimeNames` | array | Names of all created integration runtimes |

## 🔗 **Integration Patterns**

### **With Storage Account**
```bicep
// Create Data Factory
module dataFactory 'integration/data-factory.bicep' = {
  // ... configuration
}

// Grant Data Factory access to storage
module storageRoleAssignment 'security/role-assignment.bicep' = {
  name: 'df-storage-access'
  params: {
    principalId: dataFactory.outputs.systemAssignedIdentityPrincipalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    targetResourceId: storageAccount.outputs.storageAccountId
  }
}
```

### **With Key Vault**
```bicep
// Grant Data Factory access to Key Vault
module keyVaultRoleAssignment 'security/role-assignment.bicep' = {
  name: 'df-keyvault-access'
  params: {
    principalId: dataFactory.outputs.systemAssignedIdentityPrincipalId
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
    targetResourceId: keyVault.outputs.keyVaultId
  }
}
```

## 🔒 **Security Considerations**

1. **Network Security**:
   - Use managed VNet when possible
   - Disable public network access for production
   - Configure private endpoints for data sources

2. **Identity and Access**:
   - Use system-assigned managed identity
   - Follow principle of least privilege
   - Grant specific permissions to data sources

3. **Data Protection**:
   - Enable diagnostic logging
   - Use Key Vault for connection strings
   - Implement data classification and governance

## 📚 **Best Practices**

1. **Naming Conventions**:
   - Use descriptive names: `df-{project}-{environment}`
   - Follow organizational naming standards

2. **Resource Organization**:
   - Group related resources in same resource group
   - Use consistent tagging strategy

3. **Monitoring**:
   - Enable diagnostic settings
   - Monitor pipeline execution and failures
   - Set up alerting for critical pipelines

4. **Development Lifecycle**:
   - Use Git integration for source control
   - Implement CI/CD for pipeline deployment
   - Use multiple environments (dev, test, prod)

---

## 📞 **Support**

For issues or questions regarding these integration modules:
1. Check the module documentation and examples
2. Review the parameter validation requirements
3. Verify all dependencies are properly configured
4. Contact the Azure Infrastructure team for assistance
