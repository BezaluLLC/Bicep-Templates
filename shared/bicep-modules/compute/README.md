# Compute Modules

This directory contains reusable Bicep modules for Azure compute services including virtual machines and their related components.

## 📁 **Available Modules**

### **Virtual Machine Module**
- **File**: `virtual-machine.bicep`
- **Purpose**: Creates and configures Azure Virtual Machines with comprehensive options
- **Key Features**:
  - Support for both Windows and Linux VMs
  - Flexible availability options (None, AvailabilitySet, AvailabilityZone)
  - Configurable data disks and storage
  - Automatic Log Analytics agent installation
  - Extensible VM extensions support
  - SSH key and password authentication options
  - Boot diagnostics configuration

## 🚀 **Usage Examples**

### **Basic Windows VM**
```bicep
module windowsVM 'br/public:compute/virtual-machine:1.0' = {
  name: 'windows-web-server'
  params: {
    vmName: 'vm-web-prod-01'
    location: 'East US'
    vmSize: 'Standard_D2s_v3'
    osType: 'Windows'
    adminUsername: 'azureuser'
    adminPassword: adminPasswordSecret
    subnetId: spoke.outputs.subnetIds[0]
    imageConfig: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    enableMonitoring: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: {
      Environment: 'Production'
      Role: 'WebServer'
    }
  }
}
```

### **Linux VM with SSH Key Authentication**
```bicep
module linuxVM 'br/public:compute/virtual-machine:1.0' = {
  name: 'linux-app-server'
  params: {
    vmName: 'vm-app-prod-01'
    location: 'East US'
    vmSize: 'Standard_D4s_v3'
    osType: 'Linux'
    adminUsername: 'azureuser'
    sshPublicKey: sshPublicKeyValue
    disablePasswordAuthentication: true
    subnetId: spoke.outputs.subnetIds[1]
    imageConfig: {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-focal'
      sku: '20_04-lts-gen2'
      version: 'latest'
    }
    dataDisks: [
      {
        lun: 0
        sizeGB: 128
        storageAccountType: 'Premium_LRS'
        caching: 'ReadWrite'
      }
    ]
    enableMonitoring: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: {
      Environment: 'Production'
      Role: 'AppServer'
    }
  }
}
```

### **VM with Availability Zone**
```bicep
module haVM 'br/public:compute/virtual-machine:1.0' = {
  name: 'high-availability-vm'
  params: {
    vmName: 'vm-db-prod-01'
    location: 'East US'
    vmSize: 'Standard_E4s_v3'
    osType: 'Windows'
    adminUsername: 'azureuser'
    adminPassword: adminPasswordSecret
    subnetId: spoke.outputs.subnetIds[2]
    availabilityConfig: {
      type: 'AvailabilityZone'
      zone: 1
    }
    dataDisks: [
      {
        lun: 0
        sizeGB: 512
        storageAccountType: 'Premium_LRS'
        caching: 'ReadWrite'
      }
      {
        lun: 1
        sizeGB: 1024
        storageAccountType: 'Premium_LRS'
        caching: 'None'
      }
    ]
    enableBootDiagnostics: true
    bootDiagnosticsStorageAccountName: storageAccount.outputs.storageAccountName
    enableMonitoring: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    extensions: [
      {
        name: 'CustomScriptExtension'
        publisher: 'Microsoft.Compute'
        type: 'CustomScriptExtension'
        typeHandlerVersion: '1.10'
        settings: {
          fileUris: ['https://raw.githubusercontent.com/myorg/scripts/main/setup.ps1']
          commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File setup.ps1'
        }
      }
    ]
    tags: {
      Environment: 'Production'
      Role: 'DatabaseServer'
      BackupRequired: 'true'
    }
  }
}
```

### **VM with Availability Set**
```bicep
// First create an availability set
resource availabilitySet 'Microsoft.Compute/availabilitySets@2023-09-01' = {
  name: 'as-web-prod'
  location: location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
}

// Then create VMs in the availability set
module webVM1 'br/public:compute/virtual-machine:1.0' = {
  name: 'web-vm-1'
  params: {
    vmName: 'vm-web-prod-01'
    location: 'East US'
    vmSize: 'Standard_D2s_v3'
    osType: 'Windows'
    adminUsername: 'azureuser'
    adminPassword: adminPasswordSecret
    subnetId: spoke.outputs.subnetIds[0]
    availabilityConfig: {
      type: 'AvailabilitySet'
      availabilitySetId: availabilitySet.id
    }
    enableMonitoring: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: {
      Environment: 'Production'
      Role: 'WebServer'
      Instance: '1'
    }
  }
}
```

## 📋 **Module Parameters**

### **Virtual Machine Module Parameters**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `vmName` | string | Yes | - | Virtual machine name |
| `location` | string | No | `resourceGroup().location` | Azure region for deployment |
| `vmSize` | string | No | `'Standard_B2s'` | Virtual machine size |
| `osType` | string | No | `'Windows'` | Operating system type ('Windows' or 'Linux') |
| `adminUsername` | string | Yes | - | Administrator username |
| `adminPassword` | string (secure) | No | `''` | Administrator password |
| `sshPublicKey` | string | No | `''` | SSH public key for Linux VMs |
| `disablePasswordAuthentication` | bool | No | `false` | Disable password authentication for Linux VMs |
| `subnetId` | string | Yes | - | Subnet resource ID |
| `imageConfig` | object | No | Default Windows Server | Image configuration |
| `osDiskSizeGB` | int | No | `127` | OS disk size in GB |
| `osDiskType` | string | No | `'Premium_LRS'` | OS disk storage account type |
| `dataDisks` | array | No | `[]` | Data disks configuration |
| `availabilityConfig` | object | No | `{ type: 'None' }` | Availability configuration |
| `enableMonitoring` | bool | No | `true` | Enable monitoring with Log Analytics |
| `logAnalyticsWorkspaceId` | string | No | `''` | Log Analytics workspace resource ID |
| `enableBootDiagnostics` | bool | No | `true` | Enable boot diagnostics |
| `bootDiagnosticsStorageAccountName` | string | No | `''` | Boot diagnostics storage account name |
| `customData` | string | No | `''` | Custom data for VM initialization |
| `timeZone` | string | No | `'UTC'` | Time zone for Windows VMs |
| `licenseType` | string | No | `'None'` | License type for Windows VMs |
| `extensions` | array | No | `[]` | VM extensions to install |
| `tags` | object | No | `{}` | Resource tags |

### **Image Configuration**

The `imageConfig` parameter accepts:

```bicep
{
  publisher: 'string'    // Image publisher
  offer: 'string'        // Image offer
  sku: 'string'          // Image SKU
  version: 'string'      // Image version (or 'latest')
}
```

### **Data Disk Configuration**

Each data disk in the `dataDisks` array supports:

```bicep
{
  lun: int                      // Logical unit number
  sizeGB: int                   // Disk size in GB
  storageAccountType?: string   // Storage type (default: 'Premium_LRS')
  caching?: string             // Caching mode (default: 'ReadWrite')
}
```

### **Availability Configuration**

The `availabilityConfig` parameter supports:

```bicep
// No availability features
{
  type: 'None'
}

// Availability Set
{
  type: 'AvailabilitySet'
  availabilitySetId: 'string'   // Resource ID of availability set
}

// Availability Zone
{
  type: 'AvailabilityZone'
  zone: int                     // Zone number (1, 2, or 3)
}
```

### **VM Extensions**

Each extension in the `extensions` array supports:

```bicep
{
  name: 'string'                    // Extension name
  publisher: 'string'               // Extension publisher
  type: 'string'                    // Extension type
  typeHandlerVersion: 'string'      // Extension version
  autoUpgradeMinorVersion?: bool    // Auto upgrade minor version (default: true)
  settings?: object                 // Public settings
  protectedSettings?: object        // Protected settings
}
```

## 📤 **Module Outputs**

### **Virtual Machine Module Outputs**

| Output | Type | Description |
|--------|------|-------------|
| `vmId` | string | Resource ID of the virtual machine |
| `vmName` | string | Name of the virtual machine |
| `networkInterfaceId` | string | Resource ID of the network interface |
| `privateIPAddress` | string | Private IP address of the VM |
| `systemAssignedIdentityPrincipalId` | string | Principal ID of the system-assigned managed identity |
| `adminUsername` | string | Administrator username |

## 🔗 **Integration Patterns**

### **With Backup Services**
```bicep
// Create VM
module vm 'compute/virtual-machine.bicep' = {
  // ... configuration
}

// Configure backup
module backup 'security/backup.bicep' = {
  name: 'vm-backup'
  params: {
    vaultName: 'rsv-prod-backup'
    vmId: vm.outputs.vmId
    backupPolicyName: 'DailyBackupPolicy'
  }
}
```

### **With Load Balancer**
```bicep
// Create VMs in availability set
module webVMs 'compute/virtual-machine.bicep' = [for i in range(0, 2): {
  name: 'web-vm-${i}'
  params: {
    vmName: 'vm-web-prod-${i + 1}'
    // ... other configuration
    availabilityConfig: {
      type: 'AvailabilitySet'
      availabilitySetId: availabilitySet.id
    }
  }
}]

// Configure load balancer backend pool
resource loadBalancerBackendPool 'Microsoft.Network/loadBalancers/backendAddressPools@2023-09-01' = {
  parent: loadBalancer
  name: 'web-backend-pool'
}

// Add VMs to backend pool
resource backendPoolAssociation 'Microsoft.Network/networkInterfaces@2023-09-01' = [for i in range(0, 2): {
  name: '${webVMs[i].outputs.vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          loadBalancerBackendAddressPools: [
            {
              id: loadBalancerBackendPool.id
            }
          ]
        }
      }
    ]
  }
}]
```

## 🔒 **Security Considerations**

1. **Authentication**:
   - Use SSH keys for Linux VMs when possible
   - Implement strong password policies for Windows VMs
   - Consider Azure AD authentication

2. **Network Security**:
   - Place VMs in appropriate subnets with NSGs
   - Use private IP addresses
   - Implement just-in-time access for management

3. **Data Protection**:
   - Enable disk encryption
   - Configure backup policies
   - Use managed disks for better security

4. **Identity Management**:
   - Use system-assigned managed identities
   - Follow principle of least privilege
   - Regular access reviews

## 📚 **Best Practices**

1. **Naming Conventions**:
   - Use descriptive names: `vm-{role}-{environment}-{instance}`
   - Follow organizational naming standards

2. **Resource Organization**:
   - Group related VMs in same resource group
   - Use consistent tagging strategy
   - Consider proximity placement groups for performance

3. **Performance**:
   - Choose appropriate VM sizes for workloads
   - Use Premium SSD for production workloads
   - Consider accelerated networking for network-intensive workloads

4. **Monitoring**:
   - Enable monitoring and diagnostics
   - Configure alerting for key metrics
   - Use Azure Monitor for insights

5. **High Availability**:
   - Use availability sets or zones for critical workloads
   - Implement load balancing where appropriate
   - Plan for disaster recovery

---

## 📞 **Support**

For issues or questions regarding these compute modules:
1. Check the module documentation and examples
2. Review the parameter validation requirements
3. Verify all dependencies are properly configured
4. Contact the Azure Infrastructure team for assistance
