/*
  Shared Spoke Virtual Network Module
  
  This module creates a spoke virtual network for hub-and-spoke topology.
  It includes configurable subnets and optional peering to hub VNet.
*/

@description('Spoke virtual network name')
param spokeVnetName string

@description('Location for the spoke virtual network')
param location string

@description('Spoke virtual network address space')
param spokeAddressPrefix string

@description('Spoke identifier (used in naming)')
param spokeName string

@description('Subnets configuration for the spoke VNet')
param subnets array = [
  {
    name: 'default'
    addressPrefix: ''
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
]

@description('Hub virtual network ID for peering')
param hubVnetId string = ''

@description('Enable VNet peering to hub')
param enablePeering bool = false

@description('Allow forwarded traffic from hub')
param allowForwardedTraffic bool = true

@description('Allow gateway transit from hub')
param allowGatewayTransit bool = false

@description('Use remote gateway in hub')
param useRemoteGateways bool = false

@description('Resource tags')
param tags object = {}

@description('Enable DDoS protection')
param enableDdosProtection bool = false

@description('DDoS protection plan resource ID')
param ddosProtectionPlanId string = ''

// Auto-calculate default subnet prefix if not provided
var processedSubnets = [for (subnet, i) in subnets: union(subnet, {
  addressPrefix: subnet.addressPrefix == '' && subnet.name == 'default' 
    ? replace(spokeAddressPrefix, '.0.0/22', '.1.0/24')
    : subnet.addressPrefix
})]

// Spoke Virtual Network
resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spokeVnetName
  location: location
  tags: union(tags, {
    NetworkType: 'Spoke'
    SpokeName: spokeName
  })
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeAddressPrefix
      ]
    }
    subnets: [for subnet in processedSubnets: {
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
  }
}

// VNet Peering to Hub (if enabled)
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = if (enablePeering && !empty(hubVnetId)) {
  parent: spokeVnet
  name: 'peer-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
    doNotVerifyRemoteGateways: false
  }
}

// Outputs
output spokeVnetName string = spokeVnet.name
output spokeVnetId string = spokeVnet.id
output spokeVnetResourceGroup string = resourceGroup().name
output spokeAddressPrefix string = spokeAddressPrefix
output spokeName string = spokeName

// Subnet outputs
output subnets array = [for (subnet, i) in processedSubnets: {
  name: subnet.name
  id: '${spokeVnet.id}/subnets/${subnet.name}'
  addressPrefix: subnet.addressPrefix
}]

// Individual subnet IDs for easier access
output subnetIds object = reduce(processedSubnets, {}, (cur, subnet) => union(cur, {
  '${subnet.name}': '${spokeVnet.id}/subnets/${subnet.name}'
}))

// Peering outputs
output peeringName string = enablePeering ? spokeToHubPeering.name : ''
output peeringId string = enablePeering ? spokeToHubPeering.id : ''
