/*
  Shared Virtual Network Module
  
  This module creates a virtual network with configurable subnets.
  It supports both simple and complex subnet configurations including:
  - NSG associations
  - Service endpoints
  - Delegations
  - Private endpoint policies
*/

@description('Virtual network name')
param vnetName string

@description('Location for the virtual network')
param location string

@description('Virtual network address space')
@minLength(1)
param addressPrefixes array

@description('Subnets configuration')
param subnets array = []

@description('Enable DDoS protection (requires Standard plan)')
param enableDdosProtection bool = false

@description('DDoS protection plan resource ID (required if enableDdosProtection is true)')
param ddosProtectionPlanId string = ''

@description('Resource tags')
param tags object = {}

@description('Enable VM protection')
param enableVmProtection bool = false

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: union(
        {
          addressPrefix: subnet.addressPrefix
        },
        contains(subnet, 'networkSecurityGroupId') ? {
          networkSecurityGroup: {
            id: subnet.networkSecurityGroupId
          }
        } : {},
        contains(subnet, 'routeTableId') ? {
          routeTable: {
            id: subnet.routeTableId
          }
        } : {},
        contains(subnet, 'serviceEndpoints') ? {
          serviceEndpoints: subnet.serviceEndpoints
        } : {},
        contains(subnet, 'delegations') ? {
          delegations: subnet.delegations
        } : {},
        contains(subnet, 'privateEndpointNetworkPolicies') ? {
          privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
        } : {},
        contains(subnet, 'privateLinkServiceNetworkPolicies') ? {
          privateLinkServiceNetworkPolicies: subnet.privateLinkServiceNetworkPolicies
        } : {},
        contains(subnet, 'natGatewayId') ? {
          natGateway: {
            id: subnet.natGatewayId
          }
        } : {}
      )
    }]
    enableDdosProtection: enableDdosProtection
    ddosProtectionPlan: enableDdosProtection ? {
      id: ddosProtectionPlanId
    } : null
    enableVmProtection: enableVmProtection
  }
  tags: tags
}

// Outputs
output vnetName string = vnet.name
output vnetId string = vnet.id
output vnetResourceGroup string = resourceGroup().name
output addressPrefixes array = vnet.properties.addressSpace.addressPrefixes

output subnets array = [for (subnet, i) in subnets: {
  name: subnet.name
  id: '${vnet.id}/subnets/${subnet.name}'
  addressPrefix: subnet.addressPrefix
  properties: vnet.properties.subnets[i].properties
}]

// Individual subnet outputs for easier access
output subnetIds object = reduce(subnets, {}, (cur, subnet) => union(cur, {
  '${subnet.name}': '${vnet.id}/subnets/${subnet.name}'
}))

output subnetNames array = [for subnet in subnets: subnet.name]
