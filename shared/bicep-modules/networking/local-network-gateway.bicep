@description('Name of the local network gateway')
param localNetworkGatewayName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('IP address of the on-premises VPN gateway')
param gatewayIpAddress string

@description('Address prefixes for the on-premises network')
param addressPrefixes array

@description('BGP settings for the local network gateway')
param bgpSettings object = {}

@description('FQDN of the on-premises VPN gateway (alternative to gatewayIpAddress)')
param fqdn string = ''

@description('Optional. Diagnostic setting name')
param diagnosticSettingName string = ''

@description('Optional. Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Tags to apply to the local network gateway')
param tags object = {}

// Validate that either gatewayIpAddress or fqdn is provided
var hasIpAddress = !empty(gatewayIpAddress)
var hasFqdn = !empty(fqdn)

// Create local network gateway
resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2023-09-01' = {
  name: localNetworkGatewayName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: addressPrefixes
    }
    gatewayIpAddress: hasIpAddress ? gatewayIpAddress : null
    fqdn: hasFqdn ? fqdn : null
    bgpSettings: !empty(bgpSettings) ? {
      asn: bgpSettings.asn
      bgpPeeringAddress: bgpSettings.bgpPeeringAddress
      peerWeight: bgpSettings.?peerWeight ?? 0
    } : null
  }
  tags: tags
}

// Diagnostic settings
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  scope: localNetworkGateway
  name: !empty(diagnosticSettingName) ? diagnosticSettingName : 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Outputs
@description('The resource ID of the local network gateway')
output localNetworkGatewayId string = localNetworkGateway.id

@description('The name of the local network gateway')
output localNetworkGatewayName string = localNetworkGateway.name

@description('The configured gateway IP address')
output gatewayIpAddress string = hasIpAddress ? localNetworkGateway.properties.gatewayIpAddress : ''

@description('The configured FQDN')
output fqdn string = hasFqdn ? localNetworkGateway.properties.fqdn : ''
