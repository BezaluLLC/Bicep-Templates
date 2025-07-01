/*
  Shared Key Vault Module
  
  Creates an Azure Key Vault for secure storage of secrets, keys, and certificates
  with optional private endpoint, RBAC configuration, and monitoring integration.
  Follows Azure security best practices for secret management.
  
  Features:
  - Key Vault with configurable SKU (Standard/Premium)
  - Private endpoint support for network isolation
  - RBAC authorization for access control
  - Diagnostic settings integration
  - Soft delete and purge protection
  - Network access control configuration
  - Comprehensive tagging strategy
  
  Version: 1.0.0
  Last Updated: 2025-06-20
*/

// === PARAMETERS ===

@description('Key Vault name (must be globally unique)')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Azure region for deployment')
param location string

@description('Environment identifier')
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string = 'dev'

@description('Resource tags for Azure resources')
param tags object = {}

// === KEY VAULT CONFIGURATION ===

@description('Key Vault SKU')
@allowed(['standard', 'premium'])
param sku string = 'standard'

@description('Enable Azure Resource Manager for template deployment')
param enabledForTemplateDeployment bool = true

@description('Enable Azure Disk Encryption for VMs')
param enabledForDiskEncryption bool = false

@description('Enable Azure deployment access for VMs')
param enabledForDeployment bool = false

@description('Enable RBAC authorization (recommended over access policies)')
param enableRbacAuthorization bool = true

// === SOFT DELETE CONFIGURATION ===

@description('Enable soft delete protection')
param enableSoftDelete bool = true

@description('Soft delete retention period in days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = environment == 'prod' ? 90 : 7

@description('Enable purge protection (prevents permanent deletion)')
param enablePurgeProtection bool = environment == 'prod' ? true : false

// === NETWORK CONFIGURATION ===

@description('Public network access configuration')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'

@description('Deploy private endpoint for secure access')
param deployPrivateEndpoint bool = true

@description('Virtual network ID for private endpoint (required if deployPrivateEndpoint is true)')
param vnetId string = ''

@description('Subnet ID for private endpoint (required if deployPrivateEndpoint is true)')
param subnetId string = ''

@description('Network ACL bypass configuration')
@allowed(['AzureServices', 'None'])
param networkAclBypass string = 'AzureServices'

@description('Default network action when no rules match')
@allowed(['Allow', 'Deny'])
param networkAclDefaultAction string = deployPrivateEndpoint ? 'Deny' : 'Allow'

@description('IP address ranges allowed to access Key Vault (CIDR notation)')
param allowedIpRanges array = []

// === MONITORING CONFIGURATION ===

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string = ''

@description('Enable diagnostic settings')
param enableDiagnostics bool = logAnalyticsWorkspaceId != ''

@description('Diagnostic logs retention period in days')
@minValue(7)
@maxValue(365)
param diagnosticLogsRetentionDays int = 30

// === RBAC CONFIGURATION ===

@description('Principal IDs to grant Key Vault Administrator role')
param keyVaultAdministrators array = []

@description('Principal IDs to grant Key Vault Secrets User role')
param keyVaultSecretsUsers array = []

@description('Principal IDs to grant Key Vault Crypto User role')
param keyVaultCryptoUsers array = []

// === VARIABLES ===

var standardTags = union(tags, {
  ModuleSource: 'shared/bicep-modules/security'
  ModuleVersion: '1.0.0'
  Environment: environment
  Purpose: 'Secret Management'
})

var ipRules = [for ipRange in allowedIpRanges: {
  value: ipRange
}]

var keyVaultProperties = {
  sku: {
    family: 'A'
    name: sku
  }
  tenantId: tenant().tenantId
  enabledForDeployment: enabledForDeployment
  enabledForDiskEncryption: enabledForDiskEncryption
  enabledForTemplateDeployment: enabledForTemplateDeployment
  enableSoftDelete: enableSoftDelete
  softDeleteRetentionInDays: enableSoftDelete ? softDeleteRetentionInDays : null
  enablePurgeProtection: enablePurgeProtection ? enablePurgeProtection : null
  enableRbacAuthorization: enableRbacAuthorization
  publicNetworkAccess: publicNetworkAccess
  networkAcls: {
    bypass: networkAclBypass
    defaultAction: networkAclDefaultAction
    virtualNetworkRules: deployPrivateEndpoint && subnetId != '' ? [
      {
        id: subnetId
        ignoreMissingVnetServiceEndpoint: false
      }
    ] : []
    ipRules: ipRules
  }
}

var privateDnsZoneName = 'privatelink.vaultcore.azure.net'

// Built-in role definitions
var keyVaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var keyVaultCryptoUserRoleId = '12338af0-0e69-4776-bea7-57ae8d297424'

// === RESOURCES ===

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: keyVaultProperties
  tags: standardTags
}

// Private DNS Zone (create new or reference existing)
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployPrivateEndpoint) {
  name: privateDnsZoneName
  location: 'global'
  tags: standardTags
}

// Link Private DNS Zone to VNet
resource keyVaultPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployPrivateEndpoint && vnetId != '') {
  parent: keyVaultPrivateDnsZone
  name: '${keyVaultName}-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// Private Endpoint
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (deployPrivateEndpoint && subnetId != '') {
  name: 'pe-${keyVaultName}'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'keyvault-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
  tags: standardTags
}

// DNS Zone Group for Private Endpoint
resource keyVaultPrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (deployPrivateEndpoint && subnetId != '') {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

// RBAC Role Assignments
resource keyVaultAdministratorRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultAdministrators: {
  scope: keyVault
  name: guid(keyVault.id, principalId, keyVaultAdministratorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleId)
    principalId: principalId
    principalType: 'User'
  }
}]

resource keyVaultSecretsUserRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultSecretsUsers: {
  scope: keyVault
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: principalId
    principalType: 'User'
  }
}]

resource keyVaultCryptoUserRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultCryptoUsers: {
  scope: keyVault
  name: guid(keyVault.id, principalId, keyVaultCryptoUserRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultCryptoUserRoleId)
    principalId: principalId
    principalType: 'User'
  }
}]

// Diagnostic Settings
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  scope: keyVault
  name: 'KeyVaultDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticLogsRetentionDays
        }
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticLogsRetentionDays
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
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

@description('Key Vault name')
output keyVaultName string = keyVault.name

@description('Key Vault resource ID')
output keyVaultId string = keyVault.id

@description('Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Key Vault location')
output keyVaultLocation string = keyVault.location

@description('Private endpoint ID (if deployed)')
output privateEndpointId string = deployPrivateEndpoint && subnetId != '' ? keyVaultPrivateEndpoint.id : ''

@description('Private DNS zone ID (if deployed)')
output privateDnsZoneId string = deployPrivateEndpoint ? keyVaultPrivateDnsZone.id : ''

@description('Private endpoint deployed status')
output privateEndpointDeployed bool = deployPrivateEndpoint && subnetId != ''

@description('RBAC authorization enabled status')
output rbacAuthorizationEnabled bool = enableRbacAuthorization

@description('Soft delete enabled status')
output softDeleteEnabled bool = enableSoftDelete

@description('Purge protection enabled status')
output purgeProtectionEnabled bool = enablePurgeProtection
