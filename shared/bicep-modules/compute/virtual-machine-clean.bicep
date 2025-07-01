@description('Virtual machine name')
param vmName string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Virtual machine size')
param vmSize string = 'Standard_B2s'

@description('Operating system type')
@allowed(['Windows', 'Linux'])
param osType string = 'Windows'

@description('Administrator username')
param adminUsername string

@description('Administrator password (required for Windows VMs and Linux VMs without SSH key)')
@secure()
param adminPassword string = ''

@description('SSH public key for Linux VMs (when using SSH key authentication)')
param sshPublicKey string = ''

@description('Disable password authentication for Linux VMs')
param disablePasswordAuthentication bool = false

@description('Subnet resource ID for VM network interface')
param subnetId string

@description('Image configuration')
param imageConfig object = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2022-datacenter-azure-edition'
  version: 'latest'
}

@description('OS disk size in GB')
param osDiskSizeGB int = 127

@description('OS disk storage account type')
@allowed(['Standard_LRS', 'StandardSSD_LRS', 'Premium_LRS', 'StandardSSD_ZRS', 'Premium_ZRS'])
param osDiskType string = 'Premium_LRS'

@description('Data disks configuration')
param dataDisks array = []

@description('Availability configuration')
param availabilityConfig object = {
  type: 'None' // 'None', 'AvailabilitySet', 'AvailabilityZone'
  // availabilitySetId: '/subscriptions/.../availabilitySets/myAS' (for AvailabilitySet)
  // zone: 1 (for AvailabilityZone)
}

@description('Enable monitoring with Log Analytics')
param enableMonitoring bool = true

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string = ''

@description('Enable boot diagnostics')
param enableBootDiagnostics bool = true

@description('Boot diagnostics storage account name')
param bootDiagnosticsStorageAccountName string = ''

@description('Custom data for VM initialization')
param customData string = ''

@description('Time zone for Windows VMs')
param timeZone string = 'UTC'

@description('License type for Windows VMs')
@allowed(['None', 'Windows_Server', 'Windows_Client'])
param licenseType string = 'None'

@description('VM extensions to install')
param extensions array = []

@description('Resource tags')
param tags object = {}

// Variables
var networkInterfaceName = 'nic-${vmName}'
var osDiskName = 'osdisk-${vmName}'

var identityConfig = {
  type: 'SystemAssigned'
}

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

var dataDisksArray = [for (disk, i) in dataDisks: {
  name: '${vmName}-datadisk-${i}'
  lun: disk.lun
  diskSizeGB: disk.sizeGB
  caching: disk.?caching ?? 'ReadWrite'
  createOption: 'Empty'
  managedDisk: {
    storageAccountType: disk.?storageAccountType ?? 'Premium_LRS'
  }
  deleteOption: 'Delete'
}]

var storageProfileConfig = {
  imageReference: imageConfig
  osDisk: {
    name: osDiskName
    caching: 'ReadWrite'
    createOption: 'FromImage'
    diskSizeGB: osDiskSizeGB
    managedDisk: {
      storageAccountType: osDiskType
    }
    deleteOption: 'Delete'
  }
  dataDisks: dataDisksArray
}

// Create Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  zones: availabilityConfig.type == 'AvailabilityZone' ? [string(availabilityConfig.zone)] : null
  properties: union({
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: osType == 'Windows' ? {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: !empty(customData) ? base64(customData) : null
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        timeZone: timeZone
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    } : {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: !disablePasswordAuthentication ? adminPassword : null
      customData: !empty(customData) ? base64(customData) : null
      linuxConfiguration: {
        disablePasswordAuthentication: disablePasswordAuthentication
        ssh: disablePasswordAuthentication && !empty(sshPublicKey) ? {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        } : null
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          assessmentMode: 'AutomaticByPlatform'
        }
      }
    }
    storageProfile: storageProfileConfig
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
        enabled: enableBootDiagnostics
        storageUri: enableBootDiagnostics && !empty(bootDiagnosticsStorageAccountName) ? 'https://${bootDiagnosticsStorageAccountName}.blob.${environment().suffixes.storage}' : null
      }
    }
    licenseType: osType == 'Windows' && licenseType != 'None' ? licenseType : null
  }, availabilityConfig.type == 'AvailabilitySet' ? {
    availabilitySet: {
      id: availabilityConfig.availabilitySetId
    }
  } : {})
  identity: identityConfig
  tags: tags
}

// Install Log Analytics Agent for Windows
resource logAnalyticsExtensionWindows 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (enableMonitoring && !empty(logAnalyticsWorkspaceId) && osType == 'Windows') {
  parent: virtualMachine
  name: 'MicrosoftMonitoringAgent'
  location: location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
    }
    protectedSettings: {
      workspaceKey: listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey
    }
  }
}

// Install Log Analytics Agent for Linux
resource logAnalyticsExtensionLinux 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (enableMonitoring && !empty(logAnalyticsWorkspaceId) && osType == 'Linux') {
  parent: virtualMachine
  name: 'OmsAgentForLinux'
  location: location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'OmsAgentForLinux'
    typeHandlerVersion: '1.14'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
    }
    protectedSettings: {
      workspaceKey: listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey
    }
  }
}

// Install custom extensions
resource vmExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for (ext, i) in extensions: if (!empty(extensions)) {
  parent: virtualMachine
  name: ext.name
  location: location
  properties: {
    publisher: ext.publisher
    type: ext.type
    typeHandlerVersion: ext.typeHandlerVersion
    autoUpgradeMinorVersion: ext.?autoUpgradeMinorVersion ?? true
    settings: ext.?settings ?? {}
    protectedSettings: ext.?protectedSettings ?? {}
  }
  dependsOn: [
    logAnalyticsExtensionWindows
    logAnalyticsExtensionLinux
  ]
}]

// Outputs
output vmId string = virtualMachine.id
output vmName string = virtualMachine.name
output networkInterfaceId string = networkInterface.id
output privateIPAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress
output systemAssignedIdentityPrincipalId string = virtualMachine.identity.principalId
output adminUsername string = adminUsername
