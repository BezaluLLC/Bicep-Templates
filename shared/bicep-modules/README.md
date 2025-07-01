# Shared Bicep Modules

This directory contains reusable Bicep modules that can be shared across multiple workloads in the ARM template library. These modules follow Azure best practices for security, monitoring, and operational excellence.

## Module Categories

### 🔍 **Monitoring** (`monitoring/`)
- **Log Analytics**: Centralized logging and monitoring workspace
- **Application Insights**: Application performance monitoring (planned)

### 🔒 **Security** (`security/`)
- **Key Vault**: Secure secret and certificate management
- **Backup**: Recovery Services vault and backup policies
- **NSG Rules**: Common network security group rule templates (planned)

### 🌐 **Networking** (`networking/`)
- **VNet Basic**: Simple virtual network with configurable subnets (planned)
- **VNet Hub**: Hub virtual network for hub-spoke architectures (planned)
- **VNet Spoke**: Spoke virtual network with service-specific subnets (planned)
- **NSG**: Network security group creation and management (planned)
- **AVNM**: Azure Virtual Network Manager for advanced connectivity (planned)
- **Private Endpoints**: Private endpoint creation for Azure services (planned)

### 💾 **Storage** (`storage/`)
- **SQL Database**: Azure SQL Database server and database (planned)
- **PostgreSQL**: PostgreSQL Flexible Server (planned)
- **Cosmos DB**: Cosmos DB accounts and databases (planned)
- **Storage Account**: Storage accounts for data lakes and file storage (planned)
- **Synapse**: Synapse Analytics workspace (planned)

### 💻 **Compute** (`compute/`)
- **Virtual Machine**: Generalized VM deployment for Windows/Linux (planned)
- **Data Factory**: Data Factory instances for ETL pipelines (planned)

## Module Standards

### **Naming Conventions**
- Module files: `kebab-case.bicep` (e.g., `log-analytics.bicep`)
- Resources: Follow Azure naming conventions with prefixes
- Parameters: `camelCase` for consistency
- Variables: `camelCase` for internal use

### **Parameter Standards**
- **Required parameters**: Essential for module functionality
- **Optional parameters**: Provide sensible defaults
- **Parameter validation**: Use `@allowed`, `@minValue`, `@maxValue` where appropriate
- **Parameter descriptions**: Clear, concise descriptions for all parameters

### **Tagging Strategy**
All modules support a standard set of tags:
```bicep
@description('Resource tags for Azure resources')
param tags object = {}

// Standard tags applied to all resources
var standardTags = union(tags, {
  ModuleSource: 'shared/bicep-modules'
  ModuleVersion: '1.0.0'
  DeployedBy: 'ARM-Template-Library'
})
```

### **Security Standards**
- **Private endpoints**: Enabled by default for PaaS services
- **Network access**: Restricted to VNet by default
- **Encryption**: All data encrypted at rest and in transit
- **Access control**: RBAC and managed identity preferred
- **Monitoring**: Diagnostic settings enabled for all resources

### **Output Standards**
All modules provide consistent outputs:
- **Resource ID**: Full resource identifier for referencing
- **Resource name**: Name of the created resource
- **Principal outputs**: Key properties needed by consuming modules

## Usage Patterns

### **Module Reference**
```bicep
module logAnalytics '../shared/bicep-modules/monitoring/loganalytics.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    workspaceName: 'law-${uniqueString(resourceGroup().id)}'
    location: location
    sku: 'PerGB2018'
    retentionInDays: 30
    tags: resourceTags
  }
}
```

### **Cross-Module Dependencies**
```bicep
// Use outputs from one module as inputs to another
module keyVault '../shared/bicep-modules/security/keyvault.bicep' = {
  name: 'deploy-key-vault'
  params: {
    keyVaultName: 'kv-${uniqueString(resourceGroup().id)}'
    location: location
    vnetId: networking.outputs.vnetId
    subnetId: networking.outputs.servicesSubnetId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: resourceTags
  }
}
```

## Version Management

### **Semantic Versioning**
- **Major.Minor.Patch** format (e.g., 1.0.0)
- **Major**: Breaking changes to parameters or outputs
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes, no functional changes

### **Compatibility**
- Maintain backward compatibility within major versions
- Document breaking changes in module README files
- Provide migration guides for major version updates

## Testing Standards

### **Validation Requirements**
- [ ] Module deploys successfully in test environment
- [ ] All parameters properly validated
- [ ] Outputs provide expected values
- [ ] Security configurations properly applied
- [ ] Monitoring and diagnostic settings enabled

### **Test Environments**
- **Development**: Basic functionality testing
- **Staging**: Integration testing with other modules
- **Production**: Performance and security validation

## Contributing

### **Module Development Process**
1. **Analysis**: Review existing implementations and requirements
2. **Design**: Create module specification and parameter design
3. **Implementation**: Develop module following standards
4. **Testing**: Validate functionality and security
5. **Documentation**: Create comprehensive usage documentation
6. **Review**: Code review and approval process

### **Code Review Checklist**
- [ ] Follows naming conventions and standards
- [ ] Includes proper parameter validation
- [ ] Implements security best practices
- [ ] Provides comprehensive documentation
- [ ] Includes usage examples
- [ ] Tested in multiple scenarios

## Module Status

| Module | Status | Version | Last Updated |
|--------|---------|---------|--------------|
| monitoring/loganalytics | ✅ Available | 1.0.0 | 2025-06-20 |
| security/keyvault | 🚧 In Progress | - | - |
| security/backup | 📋 Planned | - | - |
| networking/* | 📋 Planned | - | - |
| storage/* | 📋 Planned | - | - |
| compute/* | 📋 Planned | - | - |

## Support

For questions, issues, or contributions related to shared modules:
- Review module-specific README files
- Check the implementation checklist in `cline_docs/`
- Follow the established development process

---

**Last Updated**: June 20, 2025  
**Documentation Version**: 1.0.0
