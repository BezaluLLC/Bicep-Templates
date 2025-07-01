/*
  Shared Hub Virtual Network Module
  
  This module creates a hub virtual network with predefined subnets for:
  - Azure Bastion
  - VPN/ExpressRoute Gateway 
  - Azure Firewall
  - Default workload subnet
  
  Based on common hub-and-spoke topology patterns.
*/

@description('Hub virtual network name')
param hubVnetName string

@description('Location for the hub virtual network')
param location string

@description('Hub virtual network address space')
param hubAddressPrefix string

@description('Enable Azure Bastion subnet')
param enableBastion bool = true

@description('Enable Gateway subnet for VPN/ExpressRoute')
param enableGateway bool = true

@description('Enable Azure Firewall subnets')
param enableFirewall bool = true

@description('Enable default workload subnet')
param enableDefaultSubnet bool = true

@description('Connectivity topology type (hub-spoke or mesh)')
@allowed(['hub-spoke', 'mesh'])
param connectivityTopology string = 'hub-spoke'

@description('Resource tags')
param tags object = {}

@description('Enable DDoS protection')
param enableDdosProtection bool = false

@description('DDoS protection plan resource ID')
param ddosProtectionPlanId string = ''

// Calculate subnet prefixes based on hub address space
// Assumes /22 (1024 IPs) hub network split into:
// - AzureBastionSubnet: /26 (64 IPs)
// - GatewaySubnet: /27 (32 IPs) 
// - AzureFirewallSubnet: /26 (64 IPs)
// - AzureFirewallManagementSubnet: /26 (64 IPs)
// - default: /25 (128 IPs)
var baseAddress = split(hubAddressPrefix, '/')[0]
var baseParts = split(baseAddress, '.')
var baseThirdOctet = int(baseParts[2])

var subnets = concat(
  enableBastion ? [
    {
      name: 'AzureBastionSubnet'
      addressPrefix: '${baseParts[0]}.${baseParts[1]}.${baseThirdOctet + 1}.0/26'
      serviceEndpoints: []
    }
  ] : [],
  enableGateway ? [
    {
      name: 'GatewaySubnet'
      addressPrefix: '${baseParts[0]}.${baseParts[1]}.${baseThirdOctet + 2}.0/27'
      serviceEndpoints: []
    }
  ] : [],
  enableFirewall ? [
    {
      name: 'AzureFirewallSubnet'
      addressPrefix: '${baseParts[0]}.${baseParts[1]}.${baseThirdOctet + 3}.0/26'
      serviceEndpoints: []
    }
    {
      name: 'AzureFirewallManagementSubnet'
      addressPrefix: '${baseParts[0]}.${baseParts[1]}.${baseThirdOctet + 3}.64/26'
      serviceEndpoints: []
    }
  ] : [],
  enableDefaultSubnet ? [
    {
      name: 'default'
      addressPrefix: '${baseParts[0]}.${baseParts[1]}.${baseThirdOctet + 3}.128/25'
      serviceEndpoints: [
        {
          service: 'Microsoft.Storage'
        }
        {
          service: 'Microsoft.KeyVault'
        }
      ]
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Disabled'
    }
  ] : []
)

// Hub Virtual Network
resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: hubVnetName
  location: location
  // Add special tag for AVNM mesh topology
  tags: union(tags, connectivityTopology == 'mesh' ? {
    _avnm_quickstart_deployment: 'hub'
  } : {})
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubAddressPrefix
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: union(
        {
          addressPrefix: subnet.addressPrefix
        },
        contains(subnet, 'serviceEndpoints') ? {
          serviceEndpoints: subnet.serviceEndpoints
        } : {},
        contains(subnet, 'privateEndpointNetworkPolicies') ? {
          privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
        } : {},
        contains(subnet, 'privateLinkServiceNetworkPolicies') ? {
          privateLinkServiceNetworkPolicies: subnet.privateLinkServiceNetworkPolicies
        } : {}
      )
    }]
    enableDdosProtection: enableDdosProtection
    ddosProtectionPlan: enableDdosProtection ? {
      id: ddosProtectionPlanId
    } : null
  }
}

// Outputs
output hubVnetName string = hubVnet.name
output hubVnetId string = hubVnet.id
output hubVnetResourceGroup string = resourceGroup().name
output hubAddressPrefix string = hubAddressPrefix

// Subnet outputs
output bastionSubnetId string = enableBastion ? '${hubVnet.id}/subnets/AzureBastionSubnet' : ''
output gatewaySubnetId string = enableGateway ? '${hubVnet.id}/subnets/GatewaySubnet' : ''
output firewallSubnetId string = enableFirewall ? '${hubVnet.id}/subnets/AzureFirewallSubnet' : ''
output firewallManagementSubnetId string = enableFirewall ? '${hubVnet.id}/subnets/AzureFirewallManagementSubnet' : ''
output defaultSubnetId string = enableDefaultSubnet ? '${hubVnet.id}/subnets/default' : ''

// All subnets for iteration
output subnets array = [for (subnet, i) in subnets: {
  name: subnet.name
  id: '${hubVnet.id}/subnets/${subnet.name}'
  addressPrefix: subnet.addressPrefix
}]
