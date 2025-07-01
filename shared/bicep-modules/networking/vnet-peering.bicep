/*
  Shared VNet Peering Module
  
  This module creates VNet peering from one virtual network to another.
  For bidirectional peering, deploy this module twice with reversed parameters.
*/

@description('Source virtual network name')
param sourceVnetName string

@description('Target virtual network resource ID')
param targetVnetId string

@description('Target virtual network name (for naming the peering)')
param targetVnetName string

@description('Allow virtual network access')
param allowVirtualNetworkAccess bool = true

@description('Allow forwarded traffic')
param allowForwardedTraffic bool = true

@description('Allow gateway transit (only one side should have this enabled)')
param allowGatewayTransit bool = false

@description('Use remote gateways (only one side should have this enabled)')
param useRemoteGateways bool = false

@description('Do not verify remote gateways')
param doNotVerifyRemoteGateways bool = false

// Reference to source VNet (must be in same resource group)
resource sourceVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: sourceVnetName
}

// Peering from source to target
resource sourceToTargetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: sourceVnet
  name: 'peer-to-${targetVnetName}'
  properties: {
    remoteVirtualNetwork: {
      id: targetVnetId
    }
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
    doNotVerifyRemoteGateways: doNotVerifyRemoteGateways
  }
}

// Outputs
output peeringName string = sourceToTargetPeering.name
output peeringId string = sourceToTargetPeering.id
output peeringState string = sourceToTargetPeering.properties.peeringState
output sourceVnetId string = sourceVnet.id
output targetVnetId string = targetVnetId
