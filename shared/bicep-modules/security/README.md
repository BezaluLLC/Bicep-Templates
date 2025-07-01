# Security Modules

This directory contains Bicep modules for Azure security and compliance services.

## Available Modules

### 🔐 **Key Vault** (`keyvault.bicep`)

Creates an Azure Key Vault for secure storage of secrets, keys, and certificates with optional private endpoint and RBAC configuration.

#### Features
- **Configurable SKU**: Standard or Premium (HSM support)
- **Private Endpoint**: Network isolation for secure access
- **RBAC Authorization**: Role-based access control (recommended)
- **Soft Delete & Purge Protection**: Data protection and compliance
- **Network ACLs**: IP restrictions and VNet integration
- **Diagnostic Settings**: Integration with Log Analytics
- **Built-in Role Assignments**: Administrator, Secrets User, Crypto User

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `keyVaultName` | string | *required* | Key Vault name (3-24 chars, globally unique) |
| `location` | string | *required* | Azure region for deployment |
| `environment` | string | `dev` | Environment identifier |
| `tags` | object | `{}` | Resource tags |
| `sku` | string | `standard` | Key Vault SKU (standard/premium) |
| `enableRbacAuthorization` | bool | `true` | Enable RBAC authorization |
| `enableSoftDelete` | bool | `true` | Enable soft delete protection |
| `softDeleteRetentionInDays` | int | 7 (90 for prod) | Soft delete retention period |
| `enablePurgeProtection` | bool | false (true for prod) | Enable purge protection |
| `publicNetworkAccess` | string | `Disabled` | Public network access |
| `deployPrivateEndpoint` | bool | `true` | Deploy private endpoint |
| `vnetId` | string | `''` | Virtual network ID (required for private endpoint) |
| `subnetId` | string | `''` | Subnet ID (required for private endpoint) |
| `logAnalyticsWorkspaceId` | string | `''` | Log Analytics workspace for diagnostics |

#### Usage Example
```bicep
module keyVault '../shared/bicep-modules/security/keyvault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    keyVaultName: 'kv-${uniqueString(resourceGroup().id)}'
    location: location
    environment: 'prod'
    vnetId: networking.outputs.vnetId
    subnetId: networking.outputs.servicesSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    keyVaultAdministrators: [
      '00000000-0000-0000-0000-000000000000' // Replace with actual principal IDs
    ]
    tags: {
      Project: 'MyProject'
      Environment: 'Production'
    }
  }
}
```

### 🛡️ **Backup** (`backup.bicep`)

Creates an Azure Recovery Services Vault with configurable backup policies for VMs, SQL databases, and file shares.

#### Features
- **Recovery Services Vault**: Secure backup storage
- **Multiple Policy Types**: VM, SQL Database, File Share backup policies
- **Environment-based Retention**: Automatic retention adjustment by environment
- **Enhanced Security**: Soft delete and encryption enabled
- **Diagnostic Integration**: Comprehensive backup monitoring
- **Flexible Scheduling**: Daily/weekly backup schedules

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `recoveryVaultName` | string | *required* | Recovery Services Vault name |
| `location` | string | *required* | Azure region for deployment |
| `environment` | string | `dev` | Environment identifier |
| `tags` | object | `{}` | Resource tags |
| `publicNetworkAccess` | string | `Disabled` | Public network access |
| `deployVmBackupPolicy` | bool | `true` | Deploy VM backup policy |
| `vmBackupFrequency` | string | `Daily` | Backup frequency (Daily/Weekly) |
| `vmBackupTime` | string | `22:00` | Backup time (UTC, HH:mm format) |
| `vmDailyRetentionDays` | int | 7 (30 for prod) | Daily retention period |
| `deploySqlBackupPolicy` | bool | `false` | Deploy SQL backup policy |
| `deployFileShareBackupPolicy` | bool | `false` | Deploy File Share backup policy |

#### Environment-Based Defaults

| Setting | dev/test | staging | prod |
|---------|----------|---------|------|
| Daily Retention | 7 days | 14 days | 30 days |
| Weekly Retention | 4 weeks | 8 weeks | 12 weeks |
| Monthly Retention | 3 months | 6 months | 12 months |
| Cross-Region Restore | Disabled | Disabled | Enabled |

#### Usage Example
```bicep
module backup '../shared/bicep-modules/security/backup.bicep' = {
  name: 'deploy-backup'
  params: {
    recoveryVaultName: 'rsv-${uniqueString(resourceGroup().id)}'
    location: location
    environment: 'prod'
    deployVmBackupPolicy: true
    deploySqlBackupPolicy: true
    vmBackupTime: '02:00'
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: {
      Project: 'MyProject'
      Purpose: 'Data Protection'
    }
  }
}

// Enable backup for a VM
resource vmBackupProtection 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2023-08-01' = {
  name: '${backup.outputs.recoveryVaultName}/Azure/iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${vmName}/vm;iaasvmcontainerv2;${resourceGroup().name};${vmName}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: backup.outputs.vmBackupPolicyId
    sourceResourceId: virtualMachine.id
  }
}
```

## Security Best Practices

### Key Vault Security
- **RBAC Over Access Policies**: Use RBAC for granular access control
- **Private Endpoints**: Isolate Key Vault from public internet
- **Purge Protection**: Enable for production environments
- **Soft Delete**: Always enabled for data protection
- **Network ACLs**: Restrict access to specific networks/IPs
- **Monitoring**: Enable diagnostic settings for audit trails

### Backup Security
- **Soft Delete**: Protects against accidental deletion
- **Encryption**: All backup data encrypted at rest
- **Cross-Region Restore**: Enable for disaster recovery
- **Access Control**: Use RBAC for backup operations
- **Monitoring**: Track backup jobs and failures
- **Retention Policies**: Align with compliance requirements

### Network Security
- **Private Endpoints**: Use for all security services
- **Network Segmentation**: Isolate security services in dedicated subnets
- **Firewall Rules**: Implement allow-listing for IP access
- **DNS Resolution**: Use private DNS zones for private endpoints

## Integration Patterns

### With Monitoring
```bicep
// Deploy monitoring first
module monitoring '../shared/bicep-modules/monitoring/loganalytics.bicep' = {
  name: 'deploy-monitoring'
  params: {
    workspaceName: 'law-${uniqueString(resourceGroup().id)}'
    location: location
    environment: environment
  }
}

// Use monitoring workspace in security modules
module keyVault '../shared/bicep-modules/security/keyvault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    keyVaultName: 'kv-${uniqueString(resourceGroup().id)}'
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    // ... other parameters
  }
}
```

### With Networking
```bicep
// Deploy networking infrastructure
module networking '../shared/bicep-modules/networking/vnet-basic.bicep' = {
  name: 'deploy-networking'
  params: {
    vnetName: 'vnet-${uniqueString(resourceGroup().id)}'
    location: location
    // ... other parameters
  }
}

// Use network outputs in security modules
module keyVault '../shared/bicep-modules/security/keyvault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    keyVaultName: 'kv-${uniqueString(resourceGroup().id)}'
    location: location
    vnetId: networking.outputs.vnetId
    subnetId: networking.outputs.servicesSubnetId
    // ... other parameters
  }
}
```

## Compliance Considerations

### Key Vault Compliance
- **FIPS 140-2 Level 2**: Use Premium SKU for HSM-backed keys
- **Data Residency**: Key Vault stores data in the selected region
- **Audit Trails**: Enable diagnostic settings for compliance logging
- **Access Reviews**: Regular review of RBAC assignments

### Backup Compliance
- **Retention Policies**: Configure based on regulatory requirements
- **Geographic Redundancy**: Enable cross-region restore for DR
- **Immutable Backups**: Protects against ransomware and corruption
- **Compliance Reports**: Use backup reports for auditing

## Cost Optimization

### Key Vault Costs
- **Standard vs Premium**: Use Standard unless HSM is required
- **Transaction Costs**: Monitor API calls and optimize usage
- **Private Endpoints**: Additional cost but necessary for security
- **Soft Delete Storage**: Minimal cost for data protection

### Backup Costs
- **Policy Optimization**: Align retention with business needs
- **Storage Tiers**: Use standard storage for most scenarios
- **Cross-Region Restore**: Additional cost for disaster recovery
- **Monitoring**: Track backup storage consumption

## Troubleshooting

### Common Key Vault Issues
1. **Access Denied**: Check RBAC assignments and network access
2. **Private Endpoint DNS**: Verify private DNS zone configuration
3. **Soft Delete Conflicts**: Check for soft-deleted objects with same name
4. **Network Access**: Verify VNet integration and firewall rules

### Common Backup Issues
1. **Policy Assignment Failures**: Check VM state and permissions
2. **Backup Failures**: Review diagnostic logs for errors
3. **Restore Issues**: Verify backup retention and restore permissions
4. **Cross-Region Restore**: Ensure feature is enabled and supported

---

**Module Version**: 1.0.0  
**Last Updated**: June 20, 2025  
**Next Review**: July 20, 2025
