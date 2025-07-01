# Advanced Networking Modules

This directory contains advanced Bicep modules for specialized Azure networking scenarios.

## Available Modules

### avnm.bicep
Creates an Azure Virtual Network Manager (AVNM) with comprehensive connectivity configurations and automatic deployment capabilities.

**Features:**
- **Multiple Connectivity Topologies**: Mesh, Hub-and-Spoke, Mesh with Hub-and-Spoke
- **Dynamic and Static Network Groups**: Support for both static VNet membership and Azure Policy-based dynamic membership
- **Automatic Deployment**: Integrated deployment script for automatic AVNM configuration deployment
- **User-Assigned Identity**: Managed identity for secure deployment operations
- **Comprehensive Configuration**: Gateway transit, global mesh, peering management

**Topologies Supported:**
- **Mesh**: All networks connected in mesh topology using Connected Groups
- **Hub-and-Spoke**: Traditional hub-and-spoke with VNet peering
- **Mesh with Hub-and-Spoke**: Hybrid approach combining both patterns

**Parameters:**
- `location`: Azure region for AVNM deployment
- `avnmName`: Name of the AVNM instance
- `spokeVnetIds`: Array of spoke VNet resource IDs (for static membership)
- `hubVnetId`: Hub VNet resource ID
- `connectivityTopology`: Topology type (mesh/hubAndSpoke/meshWithHubAndSpoke)
- `networkGroupMembershipType`: Static or dynamic membership
- `autoDeployConfigurations`: Auto-deploy configurations using deployment script (default: true)
- `createManagedIdentity`: Create user-assigned identity for deployment operations (default: true)
- `targetLocations`: Target regions for AVNM deployment (default: [location])

**Outputs:**
- `networkManagerId`: AVNM resource ID
- `networkManagerName`: AVNM name
- `connectivityConfigurationId`: ID of the connectivity configuration
- `userAssignedIdentityId`: User-assigned identity resource ID
- `deploymentScriptId`: Deployment script resource ID (if auto-deploy enabled)
- `configurationSummary`: Configuration details object

**Example Usage:**
```bicep
module avnm '../../shared/bicep-modules/networking/advanced/avnm.bicep' = {
  name: 'avnm-deployment'
  params: {
    location: location
    hubVnetId: hubVnet.outputs.vnetId
    spokeVnetIds: [
      spokeVnet1.outputs.vnetId
      spokeVnet2.outputs.vnetId
    ]
    connectivityTopology: 'meshWithHubAndSpoke'
    networkGroupMembershipType: 'static'
    autoDeployConfigurations: true
    tags: commonTags
  }
}
```

### azure-firewall.bicep
Creates an Azure Firewall with configurable security policies and network rules.

**Features:**
- Standard and Premium SKU support
- Public IP configuration
- DNS settings and threat intelligence
- Network and application rule collections
- Diagnostic settings integration

**Example Usage:**
```bicep
module firewall '../../shared/bicep-modules/networking/advanced/azure-firewall.bicep' = {
  name: 'firewall-deployment'
  params: {
    firewallName: 'fw-hub-prod'
    location: location
    subnetId: hubVnet.outputs.subnetIds['AzureFirewallSubnet']
    skuTier: 'Standard'
    tags: commonTags
  }
}
```

## Design Principles

These advanced modules are designed for:
- **Complex networking scenarios** requiring specialized Azure services
- **Enterprise-grade connectivity** with centralized management
- **Automated deployment** and configuration management
- **Scalable architectures** supporting multiple VNets and regions
- **Security-focused** implementations with proper identity management

## Dependencies

AVNM module requires:
- Azure PowerShell modules for deployment scripts
- Network Contributor role assignments for managed identity
- Proper subscription-level permissions for AVNM operations
