@description('Name of the public IP address')
param publicIpName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Public IP allocation method')
@allowed(['Dynamic', 'Static'])
param allocationMethod string = 'Static'

@description('Public IP SKU')
@allowed(['Basic', 'Standard'])
param sku string = 'Standard'

@description('Public IP tier')
@allowed(['Regional', 'Global'])
param tier string = 'Regional'

@description('Idle timeout in minutes')
@minValue(4)
@maxValue(30)
param idleTimeoutInMinutes int = 4

@description('Domain name label for the public IP')
param domainNameLabel string = ''

@description('FQDN for reverse DNS record')
param reverseFqdn string = ''

@description('Availability zone(s) for the public IP')
param availabilityZones array = []

@description('Optional. Diagnostic setting name')
param diagnosticSettingName string = ''

@description('Optional. Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Tags to apply to the public IP')
param tags object = {}

// Create public IP address
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  zones: !empty(availabilityZones) ? availabilityZones : null
  sku: {
    name: sku
    tier: tier
  }
  properties: {
    publicIPAllocationMethod: allocationMethod
    idleTimeoutInMinutes: idleTimeoutInMinutes
    dnsSettings: !empty(domainNameLabel) ? {
      domainNameLabel: domainNameLabel
      reverseFqdn: !empty(reverseFqdn) ? reverseFqdn : null
    } : null
  }
  tags: tags
}

// Diagnostic settings
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  scope: publicIp
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
@description('The resource ID of the public IP address')
output publicIpId string = publicIp.id

@description('The name of the public IP address')
output publicIpName string = publicIp.name

@description('The IP address value')
output ipAddress string = publicIp.properties.ipAddress

@description('The FQDN of the public IP address')
output fqdn string = !empty(domainNameLabel) ? publicIp.properties.dnsSettings.fqdn : ''
