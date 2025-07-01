@description('Name of the Azure Firewall')
param firewallName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Azure Firewall SKU tier')
@allowed(['Standard', 'Premium'])
param skuTier string = 'Standard'

@description('Azure Firewall SKU name')
@allowed(['AZFW_VNet', 'AZFW_Hub'])
param skuName string = 'AZFW_VNet'

@description('Resource ID of the subnet where Azure Firewall will be deployed (AzureFirewallSubnet)')
param subnetId string

@description('Resource ID of the management subnet (required for forced tunneling)')
param managementSubnetId string = ''

@description('Resource ID of the public IP address for the firewall')
param publicIpId string

@description('Resource ID of the management public IP address (required for forced tunneling)')
param managementPublicIpId string = ''

@description('Enable DNS proxy on Azure Firewall')
param enableDnsProxy bool = true

@description('Array of DNS servers for Azure Firewall to use')
param dnsServers array = []

@description('Threat intelligence mode')
@allowed(['Alert', 'Deny', 'Off'])
param threatIntelMode string = 'Alert'

@description('Enable intrusion detection and prevention capabilities (Premium SKU only)')
param enableIdps bool = false

@description('IDPS mode (Premium SKU only)')
@allowed(['Alert', 'Deny', 'Off'])
param idpsMode string = 'Alert'

@description('Firewall policy resource ID (recommended for management)')
param firewallPolicyId string = ''

@description('Availability zones for the firewall')
param availabilityZones array = []

@description('Virtual hub ID for Azure Firewall in Virtual WAN')
param virtualHubId string = ''

@description('Hub IP addresses for Virtual WAN deployment')
param hubIpAddresses object = {}

@description('Optional. Diagnostic setting name')
param diagnosticSettingName string = ''

@description('Optional. Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Tags to apply to the Azure Firewall')
param tags object = {}

// Determine if this is a forced tunneling scenario
var isForcedTunneling = !empty(managementSubnetId) && !empty(managementPublicIpId)

// Determine if this is a Virtual WAN deployment
var isVirtualWan = !empty(virtualHubId)

// IP configurations for standard VNet deployment
var ipConfigurations = isVirtualWan ? [] : [
  {
    name: 'IpConf'
    properties: {
      subnet: {
        id: subnetId
      }
      publicIPAddress: {
        id: publicIpId
      }
    }
  }
]

// Management IP configuration for forced tunneling
var managementIpConfiguration = isForcedTunneling ? {
  name: 'ManagementIpConf'
  properties: {
    subnet: {
      id: managementSubnetId
    }
    publicIPAddress: {
      id: managementPublicIpId
    }
  }
} : null

// Create Azure Firewall
resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-09-01' = {
  name: firewallName
  location: location
  zones: !empty(availabilityZones) ? availabilityZones : null
  properties: {
    sku: {
      name: skuName
      tier: skuTier
    }
    ipConfigurations: ipConfigurations
    managementIpConfiguration: managementIpConfiguration
    firewallPolicy: !empty(firewallPolicyId) ? {
      id: firewallPolicyId
    } : null
    threatIntelMode: threatIntelMode
    additionalProperties: skuTier == 'Premium' ? {
      'Network.DNS.EnableProxy': enableDnsProxy ? 'true' : 'false'
      'Network.DNS.Servers': !empty(dnsServers) ? join(dnsServers, ',') : ''
      'Network.IDPS.Mode': enableIdps ? idpsMode : 'Off'
    } : {
      'Network.DNS.EnableProxy': enableDnsProxy ? 'true' : 'false'
      'Network.DNS.Servers': !empty(dnsServers) ? join(dnsServers, ',') : ''
    }
    virtualHub: isVirtualWan ? {
      id: virtualHubId
    } : null
    hubIPAddresses: isVirtualWan ? hubIpAddresses : null
  }
  tags: tags
}

// Diagnostic settings
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  scope: azureFirewall
  name: !empty(diagnosticSettingName) ? diagnosticSettingName : 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AZFWNetworkRule'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AZFWApplicationRule'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AZFWNatRule'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AZFWThreatIntel'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AZFWIdpsSignature'
        enabled: skuTier == 'Premium'
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AZFWDnsQuery'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AZFWFqdnResolveFailure'
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
@description('The resource ID of the Azure Firewall')
output firewallId string = azureFirewall.id

@description('The name of the Azure Firewall')
output firewallName string = azureFirewall.name

@description('The private IP address of the Azure Firewall')
output privateIpAddress string = !isVirtualWan ? azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress : ''

@description('The public IP address of the Azure Firewall')
output publicIpAddress string = !isVirtualWan ? reference(publicIpId, '2023-09-01').ipAddress : ''

@description('The hub IP addresses (Virtual WAN deployment)')
output hubIpAddresses object = isVirtualWan ? azureFirewall.properties.hubIPAddresses : {}
