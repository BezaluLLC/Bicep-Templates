/*
  Shared Recovery Services Vault Module
  
  This module creates:
  - Recovery Services Vault with configurable settings
  - VM Backup Policy with configurable retention
  - Support for both public and private access
*/

@description('Recovery Services Vault name')
param vaultName string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

@description('SKU for the Recovery Services Vault')
@allowed(['RS0', 'Standard'])
param skuName string = 'RS0'

@description('SKU tier for the Recovery Services Vault')
@allowed(['Standard'])
param skuTier string = 'Standard'

@description('Public network access setting')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'

@description('Cross-region restore setting')
param crossRegionRestore bool = false

// Backup Policy Parameters
@description('Create default VM backup policy')
param createBackupPolicy bool = true

@description('Backup policy name')
param backupPolicyName string = 'DefaultVMPolicy'

@description('Backup frequency')
@allowed(['Daily', 'Weekly'])
param backupFrequency string = 'Daily'

@description('Backup time (ISO 8601 format)')
param backupTime string = '22:00:00.000Z'

@description('Daily retention period in days')
@minValue(7)
@maxValue(9999)
param dailyRetentionDays int = 30

@description('Weekly retention period in weeks')
@minValue(1)
@maxValue(5163)
param weeklyRetentionWeeks int = 12

@description('Monthly retention period in months')
@minValue(1)
@maxValue(1188)
param monthlyRetentionMonths int = 12

@description('Days of the week for weekly backup (only used if frequency is Weekly)')
param weeklyBackupDays array = ['Sunday']

@description('Time zone for backup schedule')
param timeZone string = 'UTC'

// Create Recovery Services Vault
resource recoveryVault 'Microsoft.RecoveryServices/vaults@2023-08-01' = {
  name: vaultName
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
    restoreSettings: {
      crossSubscriptionRestoreSettings: {
        crossSubscriptionRestoreState: 'Disabled'
      }
    }
    redundancySettings: {
      crossRegionRestore: crossRegionRestore ? 'Enabled' : 'Disabled'
      standardTierStorageRedundancy: 'LocallyRedundant'
    }
  }
  tags: tags
}

// Create VM Backup Policy
resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-08-01' = if (createBackupPolicy) {
  parent: recoveryVault
  name: backupPolicyName
  properties: {
    backupManagementType: 'AzureIaasVM'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: backupFrequency
      scheduleRunTimes: [
        '2024-01-01T${backupTime}'
      ]
      scheduleRunDays: backupFrequency == 'Weekly' ? weeklyBackupDays : null
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2024-01-01T${backupTime}'
        ]
        retentionDuration: {
          count: dailyRetentionDays
          durationType: 'Days'
        }
      }
      weeklySchedule: {
        daysOfTheWeek: weeklyBackupDays
        retentionTimes: [
          '2024-01-01T${backupTime}'
        ]
        retentionDuration: {
          count: weeklyRetentionWeeks
          durationType: 'Weeks'
        }
      }
      monthlySchedule: {
        retentionScheduleFormatType: 'Weekly'
        retentionScheduleWeekly: {
          daysOfTheWeek: weeklyBackupDays
          weeksOfTheMonth: [
            'First'
          ]
        }
        retentionTimes: [
          '2024-01-01T${backupTime}'
        ]
        retentionDuration: {
          count: monthlyRetentionMonths
          durationType: 'Months'
        }
      }
    }
    timeZone: timeZone
  }
}

// Outputs
output vaultName string = recoveryVault.name
output vaultId string = recoveryVault.id
output backupPolicyName string = createBackupPolicy ? backupPolicy.name : ''
output backupPolicyId string = createBackupPolicy ? backupPolicy.id : ''
