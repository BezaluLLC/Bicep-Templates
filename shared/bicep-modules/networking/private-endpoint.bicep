@description('Private endpoint name')
param privateEndpointName string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Target resource ID for the private endpoint')
param targetResourceId string

@description('Private link service connections configuration')
param privateLinkServiceConnections array = []

@description('Group IDs for the private endpoint')
param groupIds array

@description('Subnet resource ID for the private endpoint')
param subnetId string

@description('Virtual network resource ID for DNS zone linking')
param vnetId string

@description('Enable private DNS zone creation and linking')
param enableDnsZone bool = true

@description('Private DNS zone name (auto-generated if not specified)')
param privateDnsZoneName string = ''

@description('Custom DNS configurations (optional)')
param customDnsConfigs array = []

@description('Application security groups for the private endpoint')
param applicationSecurityGroups array = []

@description('Resource tags')
param tags object = {}

// Variables
var resourceName = split(targetResourceId, '/')[8]

// Use provided DNS zone name or generate default
var dnsZoneName = !empty(privateDnsZoneName) ? privateDnsZoneName : 'privatelink.${toLower(resourceName)}.azure.com'

// Create Private Endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: length(privateLinkServiceConnections) > 0 ? privateLinkServiceConnections : [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: groupIds
        }
      }
    ]
    customNetworkInterfaceName: '${privateEndpointName}-nic'
    customDnsConfigs: customDnsConfigs
    applicationSecurityGroups: applicationSecurityGroups
    ipConfigurations: []
  }
  tags: tags
}

// Create Private DNS Zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (enableDnsZone) {
  name: dnsZoneName
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to Virtual Network
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (enableDnsZone && !empty(vnetId)) {
  parent: privateDnsZone
  name: '${privateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
  tags: tags
}

// Create Private DNS Zone Group
resource privateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (enableDnsZone) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// Outputs
output privateEndpointId string = privateEndpoint.id
output privateEndpointName string = privateEndpoint.name
output networkInterfaceId string = privateEndpoint.properties.networkInterfaces[0].id
output privateDnsZoneId string = enableDnsZone ? privateDnsZone.id : ''
output privateDnsZoneName string = enableDnsZone ? privateDnsZone.name : ''
output customDnsConfigs array = privateEndpoint.properties.customDnsConfigs
