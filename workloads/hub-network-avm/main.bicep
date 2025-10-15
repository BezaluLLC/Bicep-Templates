targetScope = 'subscription'

@description('Name of the hub resource group to create.')
param resourceGroupName string

@description('Azure region for the hub resources.')
param location string = deployment().location

@description('Tags applied to all resources in this workload.')
param tags object = {}

@description('Address space for the hub virtual network. Defaults to site 250 in the 10.0.0.0/8 IPAM scheme.')
param hubAddressPrefix string = '10.250.0.0/23'

@description('CIDR prefixes for hub subnets; defaults align with the 10.250.0.0/23 allocation.')
type HubSubnetPrefixes = {
  gateway: string
  firewall: string
  bastion: string
  management: string
  shared: string
}
param subnetPrefixes HubSubnetPrefixes = {
  gateway: '10.250.0.0/27'
  firewall: '10.250.0.64/26'
  bastion: '10.250.0.128/26'
  management: '10.250.0.192/26'
  shared: '10.250.1.0/24'
}

@description('Base name prefix applied to hub resources.')
param hubNamePrefix string = 'hub'

@description('SKU to use for the VPN gateway.')
@allowed([
  'Basic'
  'VpnGw1'
  'VpnGw1AZ'
  'VpnGw2'
  'VpnGw2AZ'
  'VpnGw3'
  'VpnGw3AZ'
  'VpnGw4'
  'VpnGw4AZ'
  'VpnGw5'
  'VpnGw5AZ'
])
param vpnGatewaySku string = 'Basic'

@description('Enable BGP for the VPN gateway. Leave false to run without BGP.')
param enableBgp bool = false

@description('Enable active-active mode for the VPN gateway. Leave false for active-passive.')
param enableActiveActive bool = false

@description('Availability zones to use for the VPN gateway public IPs.')
@allowed([
  [ ]
  [1]
  [2]
  [3]
  [1, 2, 3]
])
param publicIpAvailabilityZones array = []

@description('Subscription resource IDs the Azure Virtual Network Manager will manage.')
param networkManagerScopeSubscriptions array = [
  subscription().id
]

var hubVnetName = '${hubNamePrefix}-vnet'
var vpnGatewayName = '${hubNamePrefix}-vpngw'
var networkManagerName = '${hubNamePrefix}-avnm'
var hubNetworkGroupName = '${hubNamePrefix}-hub'
var spokesNetworkGroupName = '${hubNamePrefix}-spokes'

var vpnClusterSettings = enableActiveActive ? (enableBgp ? {clusterMode: 'activeActiveBgp'} : {clusterMode: 'activeActiveNoBgp'}) : (enableBgp ? {clusterMode: 'activePassiveBgp'} : {clusterMode: 'activePassiveNoBgp'})

module hubResourceGroup 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'resourceGroup'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

module managementSubnetNsg 'br/public:avm/res/network/network-security-group:0.3.0' = {
  name: 'managementSubnetNsg'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${hubNamePrefix}-mgmt-nsg'
    location: location
    tags: tags
  }
  dependsOn: [
    hubResourceGroup
  ]
}

module sharedServicesSubnetNsg 'br/public:avm/res/network/network-security-group:0.3.0' = {
  name: 'sharedServicesSubnetNsg'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${hubNamePrefix}-shared-nsg'
    location: location
    tags: tags
  }
  dependsOn: [
    hubResourceGroup
  ]
}

module hubVirtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'virtualNetwork'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: hubVnetName
    location: location
    addressPrefixes: [
      hubAddressPrefix
    ]
    subnets: [
      {
        name: 'GatewaySubnet'
        addressPrefix: subnetPrefixes.gateway
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: subnetPrefixes.firewall
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: subnetPrefixes.bastion
      }
      {
        name: 'ManagementSubnet'
        addressPrefix: subnetPrefixes.management
        networkSecurityGroupResourceId: managementSubnetNsg.outputs.resourceId
      }
      {
        name: 'SharedServices'
        addressPrefix: subnetPrefixes.shared
        networkSecurityGroupResourceId: sharedServicesSubnetNsg.outputs.resourceId
      }
    ]
    tags: tags
  }
  dependsOn: [
    hubResourceGroup
    managementSubnetNsg
    sharedServicesSubnetNsg
  ]
}

module hubVpnGateway 'br/public:avm/res/network/virtual-network-gateway:0.10.0' = {
  name: 'vpnGateway'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: vpnGatewayName
    location: location
    gatewayType: 'Vpn'
    virtualNetworkResourceId: hubVirtualNetwork.outputs.resourceId
    clusterSettings: vpnClusterSettings
    skuName: vpnGatewaySku
    vpnType: 'RouteBased'
    allowRemoteVnetTraffic: true
    publicIpAvailabilityZones: publicIpAvailabilityZones
    tags: tags
  }
  dependsOn: [
    hubResourceGroup
    hubVirtualNetwork
  ]
}

module hubNetworkManager 'br/public:avm/res/network/network-manager:0.5.3' = {
  name: 'networkManager'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: networkManagerName
    location: location
    tags: tags
    networkManagerScopes: {
      subscriptions: networkManagerScopeSubscriptions
    }
    networkManagerScopeAccesses: [
      'Connectivity'
    ]
    networkGroups: [
      {
        name: hubNetworkGroupName
        memberType: 'VirtualNetwork'
        staticMembers: [
          {
            name: hubVirtualNetwork.outputs.name
            resourceId: hubVirtualNetwork.outputs.resourceId
          }
        ]
      }
      {
        name: spokesNetworkGroupName
        memberType: 'VirtualNetwork'
      }
    ]
    connectivityConfigurations: [
      {
        name: '${hubNamePrefix}-hubspoke'
        connectivityTopology: 'HubAndSpoke'
        description: 'Hub-and-spoke connectivity with hub virtual network ${hubVnetName}.'
        hubs: [
          {
            resourceId: hubVirtualNetwork.outputs.resourceId
            resourceType: 'Microsoft.Network/virtualNetworks'
          }
        ]
        appliesToGroups: [
          {
            groupConnectivity: 'DirectlyConnected'
            networkGroupResourceId: resourceId(subscription().subscriptionId, resourceGroupName, 'Microsoft.Network/networkManagers/networkGroups', networkManagerName, spokesNetworkGroupName)
            useHubGateway: true
          }
        ]
      }
    ]
  }
  dependsOn: [
    hubResourceGroup
    hubVirtualNetwork
    hubVpnGateway
  ]
}

output hubResourceGroupName string = resourceGroupName
output hubResourceGroupId string = subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroupName)
output hubVirtualNetworkId string = hubVirtualNetwork.outputs.resourceId
output hubSubnetResourceIds array = hubVirtualNetwork.outputs.subnetResourceIds
output vpnGatewayId string = hubVpnGateway.outputs.resourceId
output networkManagerId string = hubNetworkManager.outputs.resourceId
output spokesNetworkGroupId string = resourceId('Microsoft.Network/networkManagers/networkGroups', networkManagerName, spokesNetworkGroupName)
output managementSubnetNsgId string = managementSubnetNsg.outputs.resourceId
output sharedServicesSubnetNsgId string = sharedServicesSubnetNsg.outputs.resourceId
