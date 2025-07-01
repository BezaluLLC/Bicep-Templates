/*
  Virtual Machine Module for Universal Print Connector
  
  This module creates:
  - Network Interface
  - Virtual Machine with Universal Print Connector
  - Optional monitoring agents
  - Optional backup configuration
*/

@description('Virtual Machine name')
param vmName string

@description('Network Interface name')
param networkInterfaceName string

@description('OS Disk name')
param osDiskName string

@description('Azure region for deployment')
param location string

@description('Virtual Machine size')
param vmSize string

@description('Administrator username')
param adminUsername string

@description('Administrator password')
@secure()
param adminPassword string

@description('Azure Compute Gallery resource ID')
param computeGalleryId string

@description('Universal Print application version')
param universalPrintVersion string

@description('Subnet resource ID')
param subnetId string

@description('Enable backup for the VM')
param enableBackup bool

@description('Recovery Vault resource ID')
param recoveryVaultId string

@description('Backup Policy resource ID')
param backupPolicyId string

@description('Enable monitoring for the VM')
param enableMonitoring bool

@description('Log Analytics Workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Resource tags')
param tags object

// Create Network Interface
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
  tags: tags
}

// Create Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    applicationProfile: {
      galleryApplications: [
        {
          order: -1
          packageReferenceId: '${computeGalleryId}/applications/universalprint/versions/${universalPrintVersion}'
          treatFailureAsDeploymentFailure: false
          enableAutomaticUpgrade: false
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
}

// Install Log Analytics Agent (if monitoring enabled)
resource logAnalyticsExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (enableMonitoring && !empty(logAnalyticsWorkspaceId)) {
  parent: virtualMachine
  name: 'MicrosoftMonitoringAgent'
  location: location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: enableMonitoring ? reference(logAnalyticsWorkspaceId, '2023-09-01').customerId : ''
    }
    protectedSettings: {
      workspaceKey: enableMonitoring ? listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey : ''
    }
  }
}

// Configure VM Backup (if backup enabled)
resource vmBackup 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2023-08-01' = if (enableBackup && !empty(recoveryVaultId)) {
  name: '${split(recoveryVaultId, '/')[8]}/Azure/iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${vmName}/vm;iaasvmcontainerv2;${resourceGroup().name};${vmName}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: backupPolicyId
    sourceResourceId: virtualMachine.id
  }
}

// Outputs
output vmName string = virtualMachine.name
output vmId string = virtualMachine.id
output privateIPAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress
output networkInterfaceId string = networkInterface.id
output systemAssignedIdentityPrincipalId string = virtualMachine.identity.principalId
