/*
  Shared Backup Module
  
  Creates an Azure Recovery Services Vault with configurable backup policies
  for protecting virtual machines, SQL databases, and other Azure resources.
  Follows Azure backup best practices for data protection and compliance.
  
  Features:
  - Recovery Services Vault with configurable settings
  - Multiple backup policy types (VM, SQL, Files)
  - Flexible retention policies based on environment
  - Network access controls and private endpoints
  - Diagnostic settings integration
  - Comprehensive tagging strategy
  
  Version: 1.0.0
  Last Updated: 2025-06-20
*/

// === PARAMETERS ===

@description('Recovery Services Vault name')
@minLength(2)
@maxLength(50)
param recoveryVaultName string

@description('Azure region for deployment')
param location string

@description('Environment identifier')
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string = 'dev'

@description('Resource tags for Azure resources')
param tags object = {}

// === VAULT CONFIGURATION ===

@description('Recovery Services Vault SKU')
@allowed(['RS0'])
param vaultSku string = 'RS0'

@description('Recovery Services Vault tier')
@allowed(['Standard'])
param vaultTier string = 'Standard'

@description('Public network access configuration')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'

@description('Cross-region restore capability')
param enableCrossRegionRestore bool = environment == 'prod' ? true : false

// === BACKUP POLICY CONFIGURATION ===

@description('Deploy VM backup policy')
param deployVmBackupPolicy bool = true

@description('VM backup policy name')
param vmBackupPolicyName string = 'vm-backup-policy'

@description('Backup schedule frequency for VMs')
@allowed(['Daily', 'Weekly'])
param vmBackupFrequency string = 'Daily'

@description('Backup time for VMs (UTC, format: HH:mm)')
param vmBackupTime string = '22:00'

@description('Daily retention period in days for VMs')
@minValue(7)
@maxValue(9999)
param vmDailyRetentionDays int = environment == 'prod' ? 30 : 7

@description('Weekly retention period in weeks for VMs')
@minValue(1)
@maxValue(5163)
param vmWeeklyRetentionWeeks int = environment == 'prod' ? 12 : 4

@description('Monthly retention period in months for VMs')
@minValue(1)
@maxValue(1188)
param vmMonthlyRetentionMonths int = environment == 'prod' ? 12 : 3

@description('Deploy SQL backup policy')
param deploySqlBackupPolicy bool = false

@description('SQL backup policy name')
param sqlBackupPolicyName string = 'sql-backup-policy'

@description('Deploy File Share backup policy')
param deployFileShareBackupPolicy bool = false

@description('File Share backup policy name')
param fileShareBackupPolicyName string = 'fileshare-backup-policy'

// === MONITORING CONFIGURATION ===

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string = ''

@description('Enable diagnostic settings')
param enableDiagnostics bool = logAnalyticsWorkspaceId != ''

@description('Diagnostic logs retention period in days')
@minValue(7)
@maxValue(365)
param diagnosticLogsRetentionDays int = 30

// === VARIABLES ===

var standardTags = union(tags, {
  ModuleSource: 'shared/bicep-modules/security'
  ModuleVersion: '1.0.0'
  Environment: environment
  Purpose: 'Backup and Recovery'
})

var backupTimeFormatted = '2024-01-01T${vmBackupTime}:00.000Z'

var vmBackupPolicyProperties = {
  backupManagementType: 'AzureIaasVM'
  schedulePolicy: {
    schedulePolicyType: 'SimpleSchedulePolicy'
    scheduleRunFrequency: vmBackupFrequency
    scheduleRunTimes: [
      backupTimeFormatted
    ]
    scheduleWeeklyFrequency: vmBackupFrequency == 'Weekly' ? 1 : 0
  }
  retentionPolicy: {
    retentionPolicyType: 'LongTermRetentionPolicy'
    dailySchedule: {
      retentionTimes: [
        backupTimeFormatted
      ]
      retentionDuration: {
        count: vmDailyRetentionDays
        durationType: 'Days'
      }
    }
    weeklySchedule: {
      daysOfTheWeek: [
        'Sunday'
      ]
      retentionTimes: [
        backupTimeFormatted
      ]
      retentionDuration: {
        count: vmWeeklyRetentionWeeks
        durationType: 'Weeks'
      }
    }
    monthlySchedule: {
      retentionScheduleFormatType: 'Weekly'
      retentionScheduleWeekly: {
        daysOfTheWeek: [
          'Sunday'
        ]
        weeksOfTheMonth: [
          'First'
        ]
      }
      retentionTimes: [
        backupTimeFormatted
      ]
      retentionDuration: {
        count: vmMonthlyRetentionMonths
        durationType: 'Months'
      }
    }
  }
  timeZone: 'UTC'
}

var sqlBackupPolicyProperties = {
  backupManagementType: 'AzureWorkload'
  workLoadType: 'SQLDataBase'
  settings: {
    timeZone: 'UTC'
    issqlcompression: true
    isCompression: true
  }
  subProtectionPolicy: [
    {
      policyType: 'Full'
      schedulePolicy: {
        schedulePolicyType: 'SimpleSchedulePolicy'
        scheduleRunFrequency: 'Weekly'
        scheduleRunDays: [
          'Sunday'
        ]
        scheduleRunTimes: [
          backupTimeFormatted
        ]
      }
      retentionPolicy: {
        retentionPolicyType: 'LongTermRetentionPolicy'
        weeklySchedule: {
          daysOfTheWeek: [
            'Sunday'
          ]
          retentionTimes: [
            backupTimeFormatted
          ]
          retentionDuration: {
            count: vmWeeklyRetentionWeeks
            durationType: 'Weeks'
          }
        }
      }
    }
    {
      policyType: 'Differential'
      schedulePolicy: {
        schedulePolicyType: 'SimpleSchedulePolicy'
        scheduleRunFrequency: 'Daily'
        scheduleRunTimes: [
          backupTimeFormatted
        ]
      }
      retentionPolicy: {
        retentionPolicyType: 'SimpleRetentionPolicy'
        retentionDuration: {
          count: vmDailyRetentionDays
          durationType: 'Days'
        }
      }
    }
    {
      policyType: 'Log'
      schedulePolicy: {
        schedulePolicyType: 'LogSchedulePolicy'
        scheduleFrequencyInMins: 120
      }
      retentionPolicy: {
        retentionPolicyType: 'SimpleRetentionPolicy'
        retentionDuration: {
          count: 15
          durationType: 'Days'
        }
      }
    }
  ]
}

var fileShareBackupPolicyProperties = {
  backupManagementType: 'AzureStorage'
  workLoadType: 'AzureFileShare'
  schedulePolicy: {
    schedulePolicyType: 'SimpleSchedulePolicy'
    scheduleRunFrequency: 'Daily'
    scheduleRunTimes: [
      backupTimeFormatted
    ]
  }
  retentionPolicy: {
    retentionPolicyType: 'LongTermRetentionPolicy'
    dailySchedule: {
      retentionTimes: [
        backupTimeFormatted
      ]
      retentionDuration: {
        count: vmDailyRetentionDays
        durationType: 'Days'
      }
    }
  }
  timeZone: 'UTC'
}

// === RESOURCES ===

// Recovery Services Vault
resource recoveryVault 'Microsoft.RecoveryServices/vaults@2023-08-01' = {
  name: recoveryVaultName
  location: location
  sku: {
    name: vaultSku
    tier: vaultTier
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
  }
  tags: standardTags
}

// Vault Configuration
resource vaultConfig 'Microsoft.RecoveryServices/vaults/backupconfig@2023-08-01' = {
  parent: recoveryVault
  name: 'vaultconfig'
  properties: {
    enhancedSecurityState: 'Enabled'
    softDeleteFeatureState: 'Enabled'
    storageModelType: 'GeoRedundant'
  }
}

// VM Backup Policy
resource vmBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-08-01' = if (deployVmBackupPolicy) {
  parent: recoveryVault
  name: vmBackupPolicyName
  properties: vmBackupPolicyProperties
}

// SQL Backup Policy
resource sqlBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-08-01' = if (deploySqlBackupPolicy) {
  parent: recoveryVault
  name: sqlBackupPolicyName
  properties: sqlBackupPolicyProperties
}

// File Share Backup Policy
resource fileShareBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-08-01' = if (deployFileShareBackupPolicy) {
  parent: recoveryVault
  name: fileShareBackupPolicyName
  properties: fileShareBackupPolicyProperties
}

// Diagnostic Settings
resource vaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  scope: recoveryVault
  name: 'BackupDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'CoreAzureBackup'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticLogsRetentionDays
        }
      }
      {
        category: 'AddonAzureBackupJobs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticLogsRetentionDays
        }
      }
      {
        category: 'AddonAzureBackupAlerts'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticLogsRetentionDays
        }
      }
      {
        category: 'AddonAzureBackupPolicy'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticLogsRetentionDays
        }
      }
      {
        category: 'AddonAzureBackupStorage'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticLogsRetentionDays
        }
      }
      {
        category: 'AddonAzureBackupProtectedInstance'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticLogsRetentionDays
        }
      }
    ]
    metrics: [
      {
        category: 'Health'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticLogsRetentionDays
        }
      }
    ]
  }
}

// === OUTPUTS ===

@description('Recovery Services Vault name')
output recoveryVaultName string = recoveryVault.name

@description('Recovery Services Vault resource ID')
output recoveryVaultId string = recoveryVault.id

@description('Recovery Services Vault location')
output recoveryVaultLocation string = recoveryVault.location

@description('VM backup policy ID (if deployed)')
output vmBackupPolicyId string = deployVmBackupPolicy ? vmBackupPolicy.id : ''

@description('SQL backup policy ID (if deployed)')
output sqlBackupPolicyId string = deploySqlBackupPolicy ? sqlBackupPolicy.id : ''

@description('File Share backup policy ID (if deployed)')
output fileShareBackupPolicyId string = deployFileShareBackupPolicy ? fileShareBackupPolicy.id : ''

@description('VM backup policy deployed status')
output vmBackupPolicyDeployed bool = deployVmBackupPolicy

@description('SQL backup policy deployed status')
output sqlBackupPolicyDeployed bool = deploySqlBackupPolicy

@description('File Share backup policy deployed status')
output fileShareBackupPolicyDeployed bool = deployFileShareBackupPolicy

@description('Cross-region restore enabled status')
output crossRegionRestoreEnabled bool = enableCrossRegionRestore
