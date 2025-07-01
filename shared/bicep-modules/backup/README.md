# Backup Modules

This directory contains Bicep modules for Azure Backup and Recovery Services.

## Available Modules

### recovery-vault.bicep
Creates an Azure Recovery Services Vault with optional VM backup policy.

**Features:**
- Configurable Recovery Services Vault with security settings
- Optional VM backup policy with customizable retention
- Support for daily or weekly backup schedules
- Cross-region restore configuration
- Public/private network access control

**Parameters:**
- `vaultName`: Name of the Recovery Services Vault
- `location`: Azure region (defaults to resource group location)
- `tags`: Resource tags
- `skuName`: Vault SKU (RS0, Standard)
- `publicNetworkAccess`: Enable/disable public access
- `createBackupPolicy`: Whether to create a VM backup policy
- `backupPolicyName`: Name of the backup policy
- `backupFrequency`: Daily or Weekly backups
- `dailyRetentionDays`: How long to keep daily backups
- `weeklyRetentionWeeks`: How long to keep weekly backups
- `monthlyRetentionMonths`: How long to keep monthly backups

**Outputs:**
- `vaultName`: Recovery Services Vault name
- `vaultId`: Recovery Services Vault resource ID
- `backupPolicyName`: Backup policy name (if created)
- `backupPolicyId`: Backup policy resource ID (if created)

**Example Usage:**
```bicep
module backup '../../shared/bicep-modules/backup/recovery-vault.bicep' = {
  name: 'backup-deployment'
  params: {
    vaultName: 'rsv-myapp-prod'
    location: location
    createBackupPolicy: true
    backupPolicyName: 'vm-daily-policy'
    dailyRetentionDays: 30
    weeklyRetentionWeeks: 12
    tags: commonTags
  }
}
```
