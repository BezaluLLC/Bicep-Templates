/*
  Universal Print Connector Infrastructure Template (Spoke Workload)
  
  This template creates a Universal Print Connector infrastructure as a spoke workload
  that connects to a hub network infrastructure for hybrid connectivity:
  - Spoke Virtual Network connected to hub via AVNM or peering
  - Windows Virtual Machine with Universal Print Connector application (workload-specific)
  - Network Security Groups with appropriate rules (using shared module)
  - Optional monitoring and backup configurations (using shared modules)
  - Integration with hub networking for on-premises connectivity
  
  Design Decisions:
  - Uses Windows Server 2025 Datacenter for the VM
  - Deploys Universal Print Connector from Azure Compute Gallery
  - Follows Azure naming conventions and best practices
  - Designed as spoke workload requiring hub network infrastructure
  - Leverages shared Bicep modules for standardization
  - Supports hybrid connectivity through hub network gateway
*/

targetScope = 'resourceGroup'

// Parameters for Universal Print Connector configuration
@minLength(3)
@maxLength(15)
@description('The name of the Universal Print Connector (used in resource naming)')
param connectorName string

@description('The Azure region for the deployment')
param location string

@description('Environment identifier (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string

@description('Administrator username for the Virtual Machine')
param adminUsername string

@description('Administrator password for the Virtual Machine')
@secure()
param adminPassword string

@description('Size of the Virtual Machine')
@allowed([
  'Standard_B2als_v2'
  'Standard_B2as_v2'
  'Standard_D2ads_v6'
  'Standard_D2ads_v5'
  'Standard_D2as_v6'
  'Standard_D2as_v5'
])
param vmSize string

@description('Address prefix for the Spoke Virtual Network')
param spokeVnetAddressPrefix string

@description('Subnet prefix for the spoke subnet')
param spokeSubnetPrefix string

@description('Hub VNet resource ID for spoke connectivity')
param hubVnetId string

@description('Hub resource group name')
param hubResourceGroupName string

@description('AVNM Network Manager resource ID for automatic spoke registration')
param avnmNetworkManagerId string = ''

@description('Use AVNM for connectivity (true) or traditional VNet peering (false)')
param useAvnmConnectivity bool = true

@description('Azure Compute Gallery resource ID for Universal Print application')
param computeGalleryId string

@description('Universal Print application version')
param universalPrintVersion string

@description('Deploy Azure Backup for the VM')
param deployBackup bool

@description('Deploy Log Analytics monitoring')
param deployMonitoring bool

@description('Allow RDP access from internet (not recommended for production)')
param allowRdpFromInternet bool

@description('Allowed RDP source IP addresses or ranges (if RDP is enabled)')
param allowedRdpSources array

@description('Tags to apply to all resources')
param tags object

// Variables for resource naming
var vmName = 'vm-up-${connectorName}-${environment}'
var networkInterfaceName = 'nic-up-${connectorName}-${environment}'
var spokeVnetName = 'vnet-up-${connectorName}-${environment}'
var networkSecurityGroupName = 'nsg-up-${connectorName}-${environment}'
var subnetName = 'snet-default'
var osDiskName = 'disk-${vmName}-os'
var recoveryVaultName = 'rsv-up-${connectorName}-${environment}'
var backupPolicyName = 'backup-policy-vm-daily'
var logAnalyticsWorkspaceName = 'law-up-${connectorName}-${environment}'
var logAnalyticsWorkspaceName = 'law-up-${connectorName}-${environment}'

// Common tags
var commonTags = union(tags, {
  Environment: environment
  Project: 'UniversalPrint'
  ConnectorName: connectorName
  ManagedBy: 'Bicep'
})

// Create Network Security Group with RDP rules (needed before VNet deployment)
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-09-01' = if (empty(existingVnetId)) {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: allowRdpFromInternet ? [
      {
        name: 'AllowOutboundInternet'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: empty(allowedRdpSources) ? '*' : allowedRdpSources[0]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ] : [
      {
        name: 'AllowOutboundInternet'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyRDPInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 300
          direction: 'Inbound'
        }
      }    ]
  }
  tags: commonTags
}

// Deploy networking (if not using existing VNet) - Using Shared Module
module networking '../../shared/bicep-modules/networking/vnet.bicep' = if (empty(existingVnetId)) {
  name: 'networking-deployment'
  params: {
    vnetName: virtualNetworkName
    location: location
    addressPrefixes: [vnetAddressPrefix]
    subnets: [
      {
        name: subnetName
        addressPrefix: subnetPrefix
        networkSecurityGroup: {
          id: networkSecurityGroup.id
        }
      }
    ]
    tags: commonTags
  }
}

// Deploy Log Analytics (if monitoring enabled) - Using Shared Module
module monitoring '../../shared/bicep-modules/monitoring/loganalytics.bicep' = if (deployMonitoring) {
  name: 'monitoring-deployment'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
    tags: commonTags
  }
}

// Deploy Recovery Services Vault (if backup enabled) - Using Shared Module
module backup '../../shared/bicep-modules/backup/recovery-vault.bicep' = if (deployBackup) {
  name: 'backup-deployment'
  params: {
    vaultName: recoveryVaultName
    location: location
    createBackupPolicy: true
    backupPolicyName: backupPolicyName
    tags: commonTags
  }
}

// Deploy Virtual Machine - Using Workload-Specific Module (Universal Print specific)
module virtualMachine 'modules/virtualmachine.bicep' = {
  name: 'virtualmachine-deployment'
  params: {
    vmName: vmName
    networkInterfaceName: networkInterfaceName
    osDiskName: osDiskName
    location: location
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    computeGalleryId: computeGalleryId
    universalPrintVersion: universalPrintVersion
      // Network configuration
    subnetId: empty(existingVnetId) ? networking.outputs.subnetIds[subnetName] : resourceId('Microsoft.Network/virtualNetworks/subnets', split(existingVnetId, '/')[8], existingSubnetName)
    
    // Optional configurations
    enableBackup: deployBackup
    recoveryVaultId: deployBackup ? backup.outputs.vaultId : ''
    backupPolicyId: deployBackup ? backup.outputs.backupPolicyId : ''
    
    enableMonitoring: deployMonitoring
    logAnalyticsWorkspaceId: deployMonitoring ? monitoring.outputs.workspaceId : ''
    
    tags: commonTags
  }
}

// Outputs
output resourceGroupName string = resourceGroup().name
output virtualMachineName string = virtualMachine.outputs.vmName
output virtualMachineId string = virtualMachine.outputs.vmId
output privateIPAddress string = virtualMachine.outputs.privateIPAddress
output networkInterfaceId string = virtualMachine.outputs.networkInterfaceId

output virtualNetworkName string = empty(existingVnetId) ? networking.outputs.vnetName : split(existingVnetId, '/')[8]
output virtualNetworkId string = empty(existingVnetId) ? networking.outputs.vnetId : existingVnetId
output subnetId string = empty(existingVnetId) ? networking.outputs.subnetIds[subnetName] : resourceId('Microsoft.Network/virtualNetworks/subnets', split(existingVnetId, '/')[8], existingSubnetName)

output adminUsername string = adminUsername

output logAnalyticsWorkspaceName string = deployMonitoring ? monitoring.outputs.workspaceName : ''
output logAnalyticsWorkspaceId string = deployMonitoring ? monitoring.outputs.workspaceId : ''

output recoveryVaultName string = deployBackup ? backup.outputs.vaultName : ''
output recoveryVaultId string = deployBackup ? backup.outputs.vaultId : ''
