targetScope = 'subscription'

@description('Name of the Universal Print connector resource group to create.')
param resourceGroupName string

@description('Azure region for the Universal Print workload resources.')
param location string = deployment().location

@description('Tags applied to all resources in this workload.')
param tags object = {}

@description('Prefix used for naming workload resources.')
param workloadNamePrefix string = 'up'

@description('Environment or stage suffix applied to workload resources.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Administrator username for the Universal Print connector virtual machine.')
param adminUsername string = 'azureuser'

@description('Administrator password for the Universal Print connector virtual machine.')
@secure()
param adminPassword string

@description('VM size for the Universal Print connector.')
@allowed([
  'Standard_B2als_v2'
  'Standard_B2as_v2'
  'Standard_D2ads_v6'
  'Standard_D2ads_v5'
  'Standard_D2as_v6'
  'Standard_D2as_v5'
])
param vmSize string = 'Standard_B2als_v2'

@description('Address prefix for the Universal Print virtual network.')
param vnetAddressPrefix string = '10.50.0.0/24'

@description('Subnet prefix for the Universal Print connector subnet.')
param subnetAddressPrefix string = '10.50.0.0/24'

@description('Enable hub networking integration (creates VNet peering to the hub).')
param enableHubNetworking bool = true

@description('Resource ID of the hub virtual network to peer with when hub networking is enabled.')
param hubVirtualNetworkId string = ''

@description('Azure Compute Gallery application package reference ID for the Universal Print connector.')
param universalPrintPackageReferenceId string

@description('Allow inbound RDP from the internet (not recommended for production).')
param allowRdpFromInternet bool = false

@description('CIDR ranges allowed for RDP when internet access is enabled.')
param allowedRdpSources array = []

var nameSuffix = '${workloadNamePrefix}-${environment}'
var workloadTags = union(tags, {
  Workload: 'UniversalPrintConnector'
  Environment: environment
  ManagedBy: 'Bicep'
})
var subnetName = 'connector'
var vmName = 'vm-${nameSuffix}'
var vnetName = 'vnet-${nameSuffix}'
var nsgName = 'nsg-${nameSuffix}'
var nicSuffix = '-nic01'

var baseSecurityRules = [
  {
    name: 'AllowOutboundInternet'
    properties: {
      access: 'Allow'
      direction: 'Outbound'
      priority: 100
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'Internet'
    }
  }
]

var rdpAllowedSources = empty(allowedRdpSources) ? [ '*' ] : allowedRdpSources

var rdpRule = allowRdpFromInternet
  ? [
      {
        name: 'AllowRdpInbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 300
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefixes: rdpAllowedSources
          destinationAddressPrefix: '*'
        }
      }
    ]
  : [
      {
        name: 'DenyRdpInbound'
        properties: {
          access: 'Deny'
          direction: 'Inbound'
          priority: 300
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]

var nsgSecurityRules = concat(baseSecurityRules, rdpRule)

var hubIntegrationEnabled = enableHubNetworking && !empty(hubVirtualNetworkId)
var hubPeeringName = 'peer-${vnetName}-to-hub'
var spokePeeringName = 'peer-hub-to-${vnetName}'

module workloadResourceGroup 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'resourceGroup'
  params: {
    name: resourceGroupName
    location: location
    tags: workloadTags
  }
}

module workloadNetworkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'networkSecurityGroup'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: nsgName
    location: location
    securityRules: nsgSecurityRules
    tags: workloadTags
  }
  dependsOn: [
    workloadResourceGroup
  ]
}

module workloadVirtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'virtualNetwork'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: vnetName
    location: location
    addressPrefixes: [
      vnetAddressPrefix
    ]
    subnets: [
      {
        name: subnetName
        addressPrefix: subnetAddressPrefix
        networkSecurityGroupResourceId: workloadNetworkSecurityGroup.outputs.resourceId
      }
    ]
    peerings: hubIntegrationEnabled
      ? [
          {
            name: hubPeeringName
            remoteVirtualNetworkResourceId: hubVirtualNetworkId
            allowForwardedTraffic: true
            allowGatewayTransit: false
            allowVirtualNetworkAccess: true
            useRemoteGateways: true
            remotePeeringEnabled: true
            remotePeeringName: spokePeeringName
            remotePeeringAllowForwardedTraffic: true
            remotePeeringAllowGatewayTransit: true
            remotePeeringAllowVirtualNetworkAccess: true
            remotePeeringUseRemoteGateways: false
          }
        ]
      : null
    tags: workloadTags
  }
  dependsOn: [
    workloadResourceGroup
  ]
}

var connectorSubnetIndex = indexOf(workloadVirtualNetwork.outputs.subnetNames, subnetName)
var resolvedSubnetIndex = connectorSubnetIndex >= 0 ? connectorSubnetIndex : 0
var subnetResourceId = workloadVirtualNetwork.outputs.subnetResourceIds[resolvedSubnetIndex]

module workloadVirtualMachine 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: 'virtualMachine'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: vmName
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    availabilityZone: -1
    vmSize: vmSize
    osType: 'Windows'
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2025-datacenter'
      version: 'latest'
    }
    osDisk: {
      createOption: 'FromImage'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    nicConfigurations: [
      {
        nicSuffix: nicSuffix
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: subnetResourceId
            privateIPAllocationMethod: 'Dynamic'
          }
        ]
      }
    ]
    galleryApplications: [
      {
        packageReferenceId: universalPrintPackageReferenceId
        order: 1
        enableAutomaticUpgrade: false
        treatFailureAsDeploymentFailure: false
      }
    ]
    tags: workloadTags
  }
}

var hubPeeringResourceId = hubIntegrationEnabled ? resourceId(resourceGroupName, 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings', vnetName, hubPeeringName) : ''
var hubReversePeeringResourceId = hubIntegrationEnabled ? '${hubVirtualNetworkId}/virtualNetworkPeerings/${spokePeeringName}' : ''

output workloadResourceGroupName string = resourceGroupName
output virtualNetworkName string = workloadVirtualNetwork.outputs.name
output virtualNetworkId string = workloadVirtualNetwork.outputs.resourceId
output subnetId string = subnetResourceId
output networkSecurityGroupId string = workloadNetworkSecurityGroup.outputs.resourceId
output virtualMachineName string = workloadVirtualMachine.outputs.name
output virtualMachineId string = workloadVirtualMachine.outputs.resourceId
output hubPeeringId string = hubIntegrationEnabled ? hubPeeringResourceId : ''
output hubReversePeeringId string = hubIntegrationEnabled ? hubReversePeeringResourceId : ''
