// deployment uses a 'subscription' target scope in order to create resource group and policy
targetScope = 'subscription'

/*** PARAMETERS ***/

@description('The resource group name where the AVNM and VNET resources will be created')
param resourceGroupName string

@description('The location of this regional hub. All resources, including spoke resources, will be deployed to this region.')
@minLength(6)
param location string

// Connectivity Topology Options:
//
// Mesh: connects both the spokes and hub VNETs using a Connected Group mesh. WARNING: connected group connectivity does not propagate gateway routes from the hub to spokes, requiring route tables with UDRs!
// Hub and Spoke: connected the spokes to the hub using VNET Peering. Spoke-to-spoke connectivity will need to be routed throug an NVA in the hub, requiring UDRs and an NVA (not part of this sample)
// Mesh with Hub and Spoke: connects spoke VNETs to eachover with a connected group mesh; connects spokes to the hub with traditional peering. 
//
@description('Defines how spokes will connect to each other and how spokes will connect the hub. Valid values: "mesh", "hubAndSpoke", "meshWithHubAndSpoke"')
@allowed(['mesh','hubAndSpoke','meshWithHubAndSpoke'])
param connectivityTopology string

@description('Connectivity group membership type. Valid values: "static", "dynamic"')
@allowed(['static','dynamic'])
param networkGroupMembershipType string

/*** RESOURCE GROUP ***/
resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
}

/*** RESOURCES (HUB) ***/

module hub '../../shared/bicep-modules/networking/hub-vnet.bicep' = {
  name: 'vNET-Hub'
  scope: resourceGroup
  params: {
    hubVnetName: 'vnet-${location}-hub'
    location: location
    hubAddressPrefix: '10.0.0.0/22'
    connectivityTopology: connectivityTopology == 'mesh' ? 'mesh' : 'hub-spoke'
    enableBastion: true
    enableGateway: true
    enableFirewall: true
    enableDefaultSubnet: true
    tags: (connectivityTopology == 'mesh') ? {
      _avnm_quickstart_deployment: 'hub'
    } : {}
  }
}

/*** Dynamic Membership Policy ***/
module policy 'modules/dynMemberPolicy.bicep' = if (networkGroupMembershipType == 'dynamic') {
  name: 'policy'
  scope: subscription()
  params: {
    networkGroupId: avnm.outputs.networkGroupId
    resourceGroupName: resourceGroupName
  }
}

/*** AZURE VIRTUAL NETWORK MANAGER RESOURCES ***/
module avnm '../../shared/bicep-modules/networking/advanced/avnm.bicep' = {
  name: 'avnm'
  scope: resourceGroup
  params: {
    location: location
    hubVnetId: hub.outputs.hubVnetId
    spokeVnetIds: []
    connectivityTopology: connectivityTopology
    networkGroupMembershipType: networkGroupMembershipType
  }
}

//
// AVNM deployment is now handled automatically by the shared AVNM module
// when autoDeployConfigurations is enabled (default: true)
//

/*** OUTPUTS ***/

// Resource Group outputs
output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id
output location string = location

// Hub VNet outputs
output hubVnetName string = hub.outputs.hubVnetName
output hubVnetId string = hub.outputs.hubVnetId
output hubAddressPrefix string = hub.outputs.hubAddressPrefix
output gatewaySubnetId string = hub.outputs.gatewaySubnetId
output bastionSubnetId string = hub.outputs.bastionSubnetId
output firewallSubnetId string = hub.outputs.firewallSubnetId
output defaultSubnetId string = hub.outputs.defaultSubnetId

// AVNM outputs
output avnmNetworkManagerId string = avnm.outputs.networkManagerId
output avnmNetworkGroupId string = avnm.outputs.networkGroupId
output connectivityTopology string = connectivityTopology
output networkGroupMembershipType string = networkGroupMembershipType

// Policy outputs (for dynamic membership)
output policyDefinitionId string = (networkGroupMembershipType == 'dynamic') ? policy.outputs.policyDefinitionId : 'not_deployed'
output policyAssignmentId string = (networkGroupMembershipType == 'dynamic') ? policy.outputs.policyAssignmentId : 'not_deployed'
