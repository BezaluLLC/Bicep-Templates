@description('Name of the VPN connection')
param connectionName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Resource ID of the virtual network gateway')
param virtualNetworkGatewayId string

@description('Resource ID of the local network gateway')
param localNetworkGatewayId string = ''

@description('Resource ID of the second virtual network gateway (for VNet-to-VNet connections)')
param virtualNetworkGateway2Id string = ''

@description('Connection type')
@allowed(['IPsec', 'Vnet2Vnet', 'ExpressRoute', 'VPNClient'])
param connectionType string = 'IPsec'

@description('Shared key for the connection (required for IPsec and VNet2VNet)')
@secure()
param sharedKey string = ''

@description('Connection protocol to use')
@allowed(['IKEv1', 'IKEv2'])
param connectionProtocol string = 'IKEv2'

@description('Enable BGP for this connection')
param enableBgp bool = false

@description('Express Route circuit ID (for ExpressRoute connections)')
param expressRouteCircuitId string = ''

@description('Routing weight for the connection')
@minValue(0)
@maxValue(32000)
param routingWeight int = 0

@description('DPD timeout in seconds')
@minValue(9)
@maxValue(3600)
param dpdTimeoutSeconds int = 45

@description('Use policy-based traffic selectors')
param usePolicyBasedTrafficSelectors bool = false

@description('IPSec policies for the connection')
param ipsecPolicies array = []

@description('Optional. Diagnostic setting name')
param diagnosticSettingName string = ''

@description('Optional. Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Tags to apply to the VPN connection')
param tags object = {}

// Validate required parameters based on connection type
var requiresSharedKey = connectionType == 'IPsec' || connectionType == 'Vnet2Vnet'
var requiresLocalGateway = connectionType == 'IPsec'
var requiresSecondVnetGateway = connectionType == 'Vnet2Vnet'
var requiresExpressRouteCircuit = connectionType == 'ExpressRoute'

// Create VPN connection
resource vpnConnection 'Microsoft.Network/connections@2023-09-01' = {
  name: connectionName
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: virtualNetworkGatewayId
      properties: {}
    }
    localNetworkGateway2: requiresLocalGateway ? {
      id: localNetworkGatewayId
      properties: {}
    } : null
    virtualNetworkGateway2: requiresSecondVnetGateway ? {
      id: virtualNetworkGateway2Id
      properties: {}
    } : null
    connectionType: connectionType
    connectionProtocol: connectionType == 'IPsec' || connectionType == 'Vnet2Vnet' ? connectionProtocol : null
    routingWeight: routingWeight
    sharedKey: requiresSharedKey ? sharedKey : null
    enableBgp: enableBgp
    usePolicyBasedTrafficSelectors: usePolicyBasedTrafficSelectors
    dpdTimeoutSeconds: connectionType == 'IPsec' ? dpdTimeoutSeconds : null
    expressRouteGatewayBypass: connectionType == 'ExpressRoute' ? false : null
    peer: requiresExpressRouteCircuit ? {
      id: expressRouteCircuitId
    } : null
    ipsecPolicies: !empty(ipsecPolicies) ? ipsecPolicies : null
  }
  tags: tags
}

// Diagnostic settings
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  scope: vpnConnection
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
@description('The resource ID of the VPN connection')
output connectionId string = vpnConnection.id

@description('The name of the VPN connection')
output connectionName string = vpnConnection.name

@description('The connection status')
output connectionStatus string = vpnConnection.properties.connectionStatus

@description('The tunnel connection status')
output tunnelConnectionStatus array = vpnConnection.properties.tunnelConnectionStatus
