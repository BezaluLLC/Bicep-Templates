# Azure Virtual Network Gateway Hub Infrastructure Template (Migrated to Shared Modules)

This Bicep template creates a comprehensive hub-and-spoke network infrastructure in Azure using Azure Virtual Network Manager (AVNM) for advanced connectivity management and network topologies.

**Migration Status**: ✅ **MIGRATED** to shared Bicep modules and parameterized for better configuration management.

## Architecture Overview

The template creates a modern hub-and-spoke network architecture with the following components:

### Core Infrastructure
- **Resource Group**: Configurable via parameters (e.g., `RG-Connectivity-Dev`, `RG-Connectivity-Prod`)
- **Hub Virtual Network**: Uses shared hub-vnet module (`../../shared/bicep-modules/networking/hub-vnet.bicep`)
- **Azure Virtual Network Manager**: Centralized network management and connectivity (workload-specific)
- **Network Groups**: Static or dynamic membership management for spoke networks (workload-specific)

### Shared vs Workload-Specific Modules

**Using Shared Modules**:
- Hub VNet creation → `shared/bicep-modules/networking/hub-vnet.bicep` (replaces `modules/hub.bicep`)

**Workload-Specific Modules** (kept due to specialized requirements):
- `modules/avnm.bicep` → Azure Virtual Network Manager specific functionality
- `modules/avnmDeploymentScript.bicep` → AVNM configuration deployment automation
- `modules/dynMemberPolicy.bicep` → Dynamic network group membership policies
- `modules/spoke.bicep` → Example spoke network (users should prefer `shared/bicep-modules/networking/spoke-vnet.bicep`)

### Migration Notes
- **Hub Network**: Now uses the shared hub-vnet module with standardized subnet layout and AVNM integration
- **AVNM Components**: Remain workload-specific due to specialized Azure Virtual Network Manager requirements
- **Parameter Files**: Added environment-specific parameter files for better configuration management
- **Spoke Networks**: While this template includes a spoke module for reference, new spoke networks should use the shared spoke-vnet module

### Parameter Files
- `parameters/dev.parameters.json` - Development environment (static membership, meshWithHubAndSpoke)
- `parameters/prod.parameters.json` - Production environment (dynamic membership, hubAndSpoke)

### Hub Network Components (via Shared Module)
- **Hub VNet**: `vnet-{location}-hub` (10.0.0.0/22 address space)
- **AzureBastionSubnet**: 10.0.1.0/26 - For Azure Bastion secure access
- **GatewaySubnet**: 10.0.2.0/27 - For VPN/ExpressRoute gateways
- **AzureFirewallSubnet**: 10.0.3.0/26 - For Azure Firewall
- **AzureFirewallManagementSubnet**: 10.0.3.64/26 - For Azure Firewall management
- **Default Subnet**: 10.0.3.128/25 - For general hub resources

### Connectivity Topologies

The template supports three different connectivity patterns:

#### 1. **Mesh** (`mesh`)
- All networks (hub and spokes) are connected in a mesh topology using AVNM Connected Groups
- ⚠️ **Important**: Connected Group connectivity does not propagate gateway routes from hub to spokes
- Requires User Defined Routes (UDRs) for gateway traffic routing

#### 2. **Hub and Spoke** (`hubAndSpoke`)
- Spokes connect to hub using traditional VNet peering
- Spoke-to-spoke connectivity requires routing through Network Virtual Appliance (NVA) in hub
- Requires UDRs and NVA deployment (not included in this template)

#### 3. **Mesh with Hub and Spoke** (`meshWithHubAndSpoke`) - **Default**
- Spokes connect to each other using AVNM Connected Group mesh
- Spokes connect to hub using traditional VNet peering
- Optimal balance of connectivity and gateway route propagation

### Network Group Membership

#### Static Membership (`static`) - **Default**
- Network group membership is explicitly defined
- Only specified VNet IDs are included in connectivity configurations
- Manual management of group members

#### Dynamic Membership (`dynamic`)
- Automatic network group membership using Azure Policy
- VNets are added/removed based on policy rules and tags
- Uses tag `_avnm_quickstart_deployment` for automatic discovery

## Prerequisites

- Azure CLI or Azure PowerShell
- Bicep CLI
- Azure subscription with the following permissions:
  - **Owner** or **Contributor** role on target subscription
  - **Network Contributor** role for AVNM operations
  - **Policy Contributor** role (for dynamic membership)

## Quick Start

### 1. Deploy the Hub Infrastructure

```bash
# Basic deployment with default settings
az deployment sub create \
  --template-file main.bicep \
  --location "East US" \
  --parameters location="eastus"
```

### 2. Deploy with Custom Configuration

```bash
# Deploy with specific topology and dynamic membership
az deployment sub create \
  --template-file main.bicep \
  --location "East US" \
  --parameters \
    location="eastus" \
    resourceGroupName="RG-NetworkHub" \
    connectivityTopology="hubAndSpoke" \
    networkGroupMembershipType="dynamic"
```

### 3. PowerShell Deployment

```powershell
# Deploy using PowerShell
New-AzDeployment `
  -TemplateFile "main.bicep" `
  -Location "East US" `
  -location "eastus" `
  -resourceGroupName "RG-NetworkHub"
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `resourceGroupName` | string | `RG-Connectivity` | Resource group name for AVNM and VNet resources |
| `location` | string | *required* | Azure region for deployment (minimum 6 characters) |
| `connectivityTopology` | string | `meshWithHubAndSpoke` | Connectivity pattern: `mesh`, `hubAndSpoke`, or `meshWithHubAndSpoke` |
| `networkGroupMembershipType` | string | `static` | Group membership type: `static` or `dynamic` |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `policyDefinitionId` | string | Azure Policy definition ID (dynamic membership only) |
| `policyAssignmentId` | string | Azure Policy assignment ID (dynamic membership only) |

## Adding Spoke Networks

### For Static Membership
1. Deploy spoke VNets using the included `spoke.bicep` module
2. Update the AVNM network group to include the new spoke VNet IDs
3. Commit the AVNM configuration changes

### For Dynamic Membership
1. Deploy spoke VNets with the tag `_avnm_quickstart_deployment: "spoke"`
2. The Azure Policy will automatically add them to the network group
3. AVNM will automatically apply connectivity configurations

### Example Spoke Deployment

```bash
# Deploy a spoke network
az deployment group create \
  --resource-group "RG-Connectivity" \
  --template-file "modules/spoke.bicep" \
  --parameters \
    location="eastus" \
    spokeName="WorkloadA" \
    spokeVnetPrefix="10.1.0.0/22"
```

## Network Addressing Scheme

- **Hub VNet**: 10.0.0.0/22
- **Spoke VNets**: 10.x.0.0/22 (where x = 1, 2, 3, etc.)
- **Subnet Pattern**: First /24 subnet within each spoke (e.g., 10.1.1.0/24)

## Security Considerations

### Network Security
- Network Security Groups (NSGs) should be applied to subnets based on requirements
- Azure Firewall can be deployed to the AzureFirewallSubnet for central traffic filtering
- User Defined Routes (UDRs) may be required depending on connectivity topology

### Access Control
- AVNM requires appropriate RBAC permissions
- Dynamic membership uses Azure Policy for automated group management
- Private endpoints should be used for PaaS services in the hub

### Monitoring
- Enable Network Watcher for network monitoring and diagnostics
- Configure diagnostic settings for AVNM and VNet resources
- Use Azure Monitor for network performance monitoring

## Advanced Configuration

### Custom Network Groups
The template can be extended to support multiple network groups for different connectivity requirements:

```bicep
// Example: Separate production and development network groups
resource networkGroupProd 'Microsoft.Network/networkManagers/networkGroups@2022-09-01' = {
  name: 'ng-production'
  parent: networkManager
  properties: {
    description: 'Production workloads network group'
  }
}
```

### Multiple Connectivity Configurations
Different connectivity configurations can be applied to different network groups:

```bicep
// Example: Different connectivity for different environments
resource connectivityConfigProd 'Microsoft.Network/networkManagers/connectivityConfigurations@2022-09-01' = {
  name: 'cc-production-hubandsOpoke'
  parent: networkManager
  properties: {
    connectivityTopology: 'HubAndSpoke'
    // Additional configuration...
  }
}
```

## Troubleshooting

### Common Issues

1. **Connectivity Configuration Not Applied**
   - Ensure AVNM deployment script completed successfully
   - Check that the configuration was committed via the Azure portal or API
   - Verify network group membership

2. **Dynamic Membership Not Working**
   - Verify Azure Policy is assigned and enabled
   - Check that spoke VNets have the correct tags
   - Review policy compliance in Azure Policy portal

3. **Gateway Routes Not Propagating**
   - This is expected behavior with mesh topology
   - Use hub-and-spoke or mesh-with-hub-and-spoke topology for gateway connectivity
   - Implement UDRs if using pure mesh topology

### Diagnostic Commands

```bash
# Check AVNM status
az network manager show --name "avnm-eastus" --resource-group "RG-Connectivity"

# List network groups
az network manager group list --network-manager-name "avnm-eastus" --resource-group "RG-Connectivity"

# Check connectivity configuration
az network manager connect-config list --network-manager-name "avnm-eastus" --resource-group "RG-Connectivity"
```

## Cleanup

When cleaning up the deployment, resources should be removed in the following order:

1. **AVNM Configurations**: Remove connectivity configurations first
2. **Network Groups**: Delete network group memberships
3. **Azure Policy**: Remove policy assignments and definitions (dynamic membership)
4. **AVNM**: Delete the Azure Virtual Network Manager
5. **VNets**: Remove spoke and hub virtual networks
6. **Resource Group**: Delete the resource group

```bash
# Example cleanup script
az deployment sub create \
  --template-uri "cleanup-template.bicep" \
  --location "East US" \
  --parameters resourceGroupName="RG-Connectivity"
```

## Related Documentation

- [Azure Virtual Network Manager Overview](https://docs.microsoft.com/azure/virtual-network-manager/overview)
- [Hub-spoke network topology in Azure](https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Networking Best Practices](https://docs.microsoft.com/azure/architecture/framework/security/design-network-segmentation)
- [Azure Virtual Network Manager Connectivity Configurations](https://docs.microsoft.com/azure/virtual-network-manager/concept-connectivity-configuration)

## Contributing

This template is part of the ARM template library. For contributions and improvements:

1. Follow the established bicep module patterns
2. Update parameter documentation
3. Test all connectivity topologies
4. Update this README with any changes

## License

This project is licensed under the MIT License - see the LICENSE file for details.
