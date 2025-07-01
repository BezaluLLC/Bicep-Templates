/*
  Shared Network Security Group Module
  
  This module creates a Network Security Group with configurable security rules.
  It supports common predefined rule sets and custom rules.
*/

@description('Network Security Group name')
param nsgName string

@description('Location for the NSG')
param location string

@description('Security rules configuration')
param securityRules array = []

@description('Resource tags')
param tags object = {}

@description('Flow logs settings')
param flowLogs object = {}

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: securityRules
    flushConnection: false
  }
  tags: tags
}

// Flow logs (if configured)
resource nsgFlowLogs 'Microsoft.Network/networkWatchers/flowLogs@2024-05-01' = if (!empty(flowLogs)) {
  name: '${flowLogs.networkWatcherName}/${nsgName}-flowlogs'
  location: location
  properties: {
    targetResourceId: nsg.id
    storageId: flowLogs.storageAccountId
    enabled: flowLogs.enabled
    format: {
      type: flowLogs.?format ?? 'JSON'
      version: flowLogs.?version ?? 2
    }
    retentionPolicy: {
      days: flowLogs.?retentionDays ?? 7
      enabled: flowLogs.?retentionEnabled ?? true
    }
    flowAnalyticsConfiguration: contains(flowLogs, 'workspaceId') ? {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceId: flowLogs.workspaceId
        workspaceRegion: flowLogs.?workspaceRegion ?? location
        workspaceResourceId: flowLogs.workspaceResourceId
        trafficAnalyticsInterval: flowLogs.?trafficAnalyticsInterval ?? 60
      }
    } : null
  }
}

// Outputs
output nsgName string = nsg.name
output nsgId string = nsg.id
output nsgResourceGroup string = resourceGroup().name

// Predefined rule templates for common scenarios
var commonRuleTemplates = {
  allowHttpHttps: [
    {
      name: 'AllowHTTP'
      properties: {
        description: 'Allow HTTP inbound traffic'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '80'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
      }
    }
    {
      name: 'AllowHTTPS'
      properties: {
        description: 'Allow HTTPS inbound traffic'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1010
        direction: 'Inbound'
      }
    }
  ]
  allowRdp: [
    {
      name: 'AllowRDP'
      properties: {
        description: 'Allow RDP inbound traffic'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '3389'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
      }
    }
  ]
  allowSsh: [
    {
      name: 'AllowSSH'
      properties: {
        description: 'Allow SSH inbound traffic'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '22'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
      }
    }
  ]
  allowSqlServer: [
    {
      name: 'AllowSQLServer'
      properties: {
        description: 'Allow SQL Server inbound traffic'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '1433'
        sourceAddressPrefix: 'VirtualNetwork'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
      }
    }
  ]
  allowPostgreSQL: [
    {
      name: 'AllowPostgreSQL'
      properties: {
        description: 'Allow PostgreSQL inbound traffic'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '5432'
        sourceAddressPrefix: 'VirtualNetwork'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
      }
    }
  ]
  denyAllInbound: [
    {
      name: 'DenyAllInbound'
      properties: {
        description: 'Deny all inbound traffic'
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '*'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
        access: 'Deny'
        priority: 4096
        direction: 'Inbound'
      }
    }
  ]
  allowOutboundInternet: [
    {
      name: 'AllowOutboundInternet'
      properties: {
        description: 'Allow outbound internet access'
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '*'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: 'Internet'
        access: 'Allow'
        priority: 100
        direction: 'Outbound'
      }
    }
  ]
  allowVNetInbound: [
    {
      name: 'AllowVNetInbound'
      properties: {
        description: 'Allow traffic from VNet'
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '*'
        sourceAddressPrefix: 'VirtualNetwork'
        destinationAddressPrefix: 'VirtualNetwork'
        access: 'Allow'
        priority: 100
        direction: 'Inbound'
      }
    }
  ]
  allowVNetOutbound: [
    {
      name: 'AllowVNetOutbound'
      properties: {
        description: 'Allow traffic to VNet'
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '*'
        sourceAddressPrefix: 'VirtualNetwork'
        destinationAddressPrefix: 'VirtualNetwork'
        access: 'Allow'
        priority: 100
        direction: 'Outbound'
      }
    }
  ]
  allowAzureLoadBalancer: [
    {
      name: 'AllowAzureLoadBalancer'
      properties: {
        description: 'Allow Azure Load Balancer'
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '*'
        sourceAddressPrefix: 'AzureLoadBalancer'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 110
        direction: 'Inbound'
      }
    }
  ]
  allowKeyVault: [
    {
      name: 'AllowKeyVault'
      properties: {
        description: 'Allow Key Vault access'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: 'VirtualNetwork'
        destinationAddressPrefix: 'AzureKeyVault'
        access: 'Allow'
        priority: 1100
        direction: 'Outbound'
      }
    }
  ]
  allowStorage: [
    {
      name: 'AllowStorage'
      properties: {
        description: 'Allow Storage access'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: 'VirtualNetwork'
        destinationAddressPrefix: 'Storage'
        access: 'Allow'
        priority: 1200
        direction: 'Outbound'
      }
    }
  ]
}

output ruleTemplates object = commonRuleTemplates
