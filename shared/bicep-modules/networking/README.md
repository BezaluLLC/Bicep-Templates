# Networking Shared Modules

This directory contains reusable Bicep modules for Azure networking components. These modules are designed to support common networking patterns including hub-and-spoke topologies, virtual network peering, and network security groups.

## Modules Overview

### Core Networking Modules

| Module | Description | Use Case |
|--------|-------------|----------|
| `vnet.bicep` | General-purpose virtual network with configurable subnets | Basic VNet creation with custom subnet configuration |
| `hub-vnet.bicep` | Hub virtual network for hub-and-spoke topology | Central hub with Bastion, Gateway, Firewall subnets |
| `spoke-vnet.bicep` | Spoke virtual network for hub-and-spoke topology | Workload-specific VNets that peer to hub |
| `nsg.bicep` | Network Security Group with rule templates | Security rules for subnet and NIC protection |
| `vnet-peering.bicep` | VNet peering configuration | Connect VNets for hub-spoke or mesh topologies |
| `public-ip.bicep` | Public IP address configuration | Public IPs for gateways, firewalls, and load balancers |
| `local-network-gateway.bicep` | Local network gateway for site-to-site VPN | On-premises network gateway definition |
| `vpn-connection.bicep` | VPN connection configuration | Site-to-site, VNet-to-VNet, or ExpressRoute connections |
| `private-endpoint.bicep` | Private endpoint for PaaS services | Secure private connectivity to Azure services |

### Advanced Networking Modules

| Module | Description | Use Case |
|--------|-------------|----------|
| `advanced/avnm.bicep` | Azure Virtual Network Manager | Centralized network management and connectivity |
| `advanced/azure-firewall.bicep` | Azure Firewall with Premium features | Network security and traffic filtering |

## Module Documentation

### vnet.bicep - General Virtual Network

A flexible VNet module that supports custom subnet configurations with NSGs, service endpoints, delegations, and private endpoint policies.

**Key Features:**
- Configurable address space and subnets
- NSG and route table associations
- Service endpoint configuration
- Subnet delegations for PaaS services
- Private endpoint and private link policies
- DDoS protection support

**Parameters:**
- `vnetName`: Virtual network name
- `location`: Azure region
- `addressPrefixes`: Array of CIDR blocks for VNet address space
- `subnets`: Array of subnet configurations
- `enableDdosProtection`: Enable DDoS protection plan
- `tags`: Resource tags

**Example Usage:**
```bicep
module vnet 'shared/bicep-modules/networking/vnet.bicep' = {
  name: 'workload-vnet'
  params: {
    vnetName: 'vnet-workload-prod'
    location: location
    addressPrefixes: ['10.1.0.0/22']
    subnets: [
      {
        name: 'web-subnet'
        addressPrefix: '10.1.1.0/24'
        networkSecurityGroupId: webNsg.outputs.nsgId
        serviceEndpoints: [
          { service: 'Microsoft.Storage' }
        ]
      }
      {
        name: 'data-subnet'
        addressPrefix: '10.1.2.0/24'
        networkSecurityGroupId: dataNsg.outputs.nsgId
        privateEndpointNetworkPolicies: 'Disabled'
      }
    ]
    tags: commonTags
  }
}
```

### hub-vnet.bicep - Hub Virtual Network

Creates a hub VNet with predefined subnets for common hub services like Azure Bastion, VPN Gateway, and Azure Firewall.

**Key Features:**
- Predefined subnet layout for hub services
- Automatic subnet CIDR calculation
- Optional service subnets (Bastion, Gateway, Firewall)
- AVNM mesh topology support
- DDoS protection support

**Parameters:**
- `hubVnetName`: Hub VNet name
- `location`: Azure region
- `hubAddressPrefix`: Hub address space (typically /22)
- `enableBastion`: Create AzureBastionSubnet
- `enableGateway`: Create GatewaySubnet
- `enableFirewall`: Create Azure Firewall subnets
- `connectivityTopology`: hub-spoke or mesh

**Example Usage:**
```bicep
module hubVnet 'shared/bicep-modules/networking/hub-vnet.bicep' = {
  name: 'hub-network'
  params: {
    hubVnetName: 'vnet-hub-prod'
    location: location
    hubAddressPrefix: '10.0.0.0/22'
    enableBastion: true
    enableGateway: true
    enableFirewall: true
    connectivityTopology: 'hub-spoke'
    tags: commonTags
  }
}
```

### spoke-vnet.bicep - Spoke Virtual Network

Creates a spoke VNet for workloads with optional peering to a hub VNet.

**Key Features:**
- Configurable subnet layout
- Automatic default subnet CIDR calculation
- Optional hub peering configuration
- Gateway transit and remote gateway support
- Service endpoint configuration

**Parameters:**
- `spokeVnetName`: Spoke VNet name
- `location`: Azure region
- `spokeAddressPrefix`: Spoke address space
- `spokeName`: Identifier for naming
- `subnets`: Array of subnet configurations
- `hubVnetId`: Hub VNet resource ID for peering
- `enablePeering`: Enable VNet peering to hub

**Example Usage:**
```bicep
module spokeVnet 'shared/bicep-modules/networking/spoke-vnet.bicep' = {
  name: 'spoke-network'
  params: {
    spokeVnetName: 'vnet-spoke-workload-prod'
    location: location
    spokeAddressPrefix: '10.1.0.0/22'
    spokeName: 'workload'
    hubVnetId: hubVnet.outputs.hubVnetId
    enablePeering: true
    useRemoteGateways: true
    tags: commonTags
  }
}
```

### nsg.bicep - Network Security Group

Creates NSGs with configurable security rules and predefined rule templates for common scenarios.

**Key Features:**
- Custom security rule configuration
- Predefined rule templates (HTTP/HTTPS, RDP, SSH, SQL, etc.)
- NSG flow logs support
- Traffic analytics integration

**Parameters:**
- `nsgName`: NSG name
- `location`: Azure region
- `securityRules`: Array of custom security rules
- `flowLogs`: Flow logs configuration
- `tags`: Resource tags

**Rule Templates Available:**
- `allowHttpHttps`: HTTP and HTTPS inbound rules
- `allowRdp`: RDP access rules
- `allowSsh`: SSH access rules
- `allowSqlServer`: SQL Server access rules
- `allowPostgreSQL`: PostgreSQL access rules
- `denyAllInbound`: Deny all inbound traffic
- `allowOutboundInternet`: Allow internet outbound
- `allowVNetInbound/Outbound`: Allow VNet internal traffic

**Example Usage:**
```bicep
module webNsg 'shared/bicep-modules/networking/nsg.bicep' = {
  name: 'web-nsg'
  params: {
    nsgName: 'nsg-web-subnet'
    location: location
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
    tags: commonTags
  }
}
```

### vnet-peering.bicep - VNet Peering

Creates VNet peering connections between virtual networks.

**Key Features:**
- Unidirectional peering (deploy twice for bidirectional)
- Gateway transit configuration
- Forwarded traffic settings
- Remote gateway usage

**Parameters:**
- `sourceVnetName`: Source VNet name (in current resource group)
- `targetVnetId`: Target VNet resource ID
- `targetVnetName`: Target VNet name for naming
- `allowGatewayTransit`: Allow gateway transit
- `useRemoteGateways`: Use remote gateways

**Example Usage:**
```bicep
// Hub to Spoke peering
module hubToSpokePeering 'shared/bicep-modules/networking/vnet-peering.bicep' = {
  name: 'hub-to-spoke-peering'
  params: {
    sourceVnetName: hubVnet.outputs.hubVnetName
    targetVnetId: spokeVnet.outputs.spokeVnetId
    targetVnetName: spokeVnet.outputs.spokeVnetName
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

// Spoke to Hub peering (in spoke resource group)
module spokeToHubPeering 'shared/bicep-modules/networking/vnet-peering.bicep' = {
  name: 'spoke-to-hub-peering'
  scope: resourceGroup(spokeResourceGroupName)
  params: {
    sourceVnetName: spokeVnet.outputs.spokeVnetName
    targetVnetId: hubVnet.outputs.hubVnetId
    targetVnetName: hubVnet.outputs.hubVnetName
    allowGatewayTransit: false
    useRemoteGateways: true
  }
}
```

## Common Patterns

### Hub-and-Spoke Topology

```bicep
// 1. Create hub VNet
module hubVnet 'shared/bicep-modules/networking/hub-vnet.bicep' = {
  name: 'hub-network'
  params: {
    hubVnetName: 'vnet-hub-${environment}'
    location: location
    hubAddressPrefix: '10.0.0.0/22'
    enableBastion: true
    enableGateway: true
    enableFirewall: true
    tags: commonTags
  }
}

// 2. Create spoke VNet with peering
module spokeVnet 'shared/bicep-modules/networking/spoke-vnet.bicep' = {
  name: 'spoke-network'
  params: {
    spokeVnetName: 'vnet-spoke-${workloadName}-${environment}'
    location: location
    spokeAddressPrefix: '10.1.0.0/22'
    spokeName: workloadName
    hubVnetId: hubVnet.outputs.hubVnetId
    enablePeering: true
    useRemoteGateways: true
    tags: commonTags
  }
}
```

### Database Subnet with Delegation

```bicep
module databaseVnet 'shared/bicep-modules/networking/vnet.bicep' = {
  name: 'database-vnet'
  params: {
    vnetName: 'vnet-database-${environment}'
    location: location
    addressPrefixes: ['10.2.0.0/22']
    subnets: [
      {
        name: 'postgresql-subnet'
        addressPrefix: '10.2.1.0/24'
        networkSecurityGroupId: postgresNsg.outputs.nsgId
        delegations: [
          {
            name: 'Microsoft.DBforPostgreSQL-flexibleServers'
            properties: {
              serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
            }
          }
        ]
        serviceEndpoints: [
          { service: 'Microsoft.Storage' }
        ]
      }
    ]
    tags: commonTags
  }
}
```

## Migration from Existing Modules

To migrate existing workloads to use these shared modules:

1. **Identify current networking components** in workload modules
2. **Map subnet configurations** to the shared module parameters
3. **Update workload main.bicep** to use shared modules instead of inline networking
4. **Test in development environment** before production deployment
5. **Update parameter files** to match new module structure

## Best Practices

1. **Use hub-and-spoke topology** for centralized connectivity and security
2. **Apply NSGs at subnet level** for network micro-segmentation
3. **Enable flow logs** for security monitoring and troubleshooting
4. **Use service endpoints** instead of public endpoints when possible
5. **Plan IP address space** carefully to avoid overlaps
6. **Tag all networking resources** for cost management and governance
7. **Use private endpoints** for PaaS service connectivity when available

## Support and Contributions

These modules are part of the shared infrastructure library. For questions, issues, or enhancement requests, please refer to the main project documentation and follow the established contribution guidelines.
