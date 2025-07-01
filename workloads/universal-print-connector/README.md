# Universal Print Connector Workload (Migrated to Shared Modules)

## Overview

The Universal Print Connector workload deploys a Windows Server 2025 virtual machine with the Universal Print Connector application pre-installed from Azure Compute Gallery. This infrastructure enables organizations to connect on-premises printers to Microsoft Universal Print service.

**Migration Status**: ✅ **MIGRATED** to shared Bicep modules for improved standardization and maintainability.

## Architecture

### Components
- **Virtual Machine**: Windows Server 2025 with Universal Print Connector application (workload-specific module)
- **Networking**: Virtual Network using shared VNet module (`../../shared/bicep-modules/networking/vnet.bicep`)
- **Monitoring**: Log Analytics workspace using shared module (`../../shared/bicep-modules/monitoring/loganalytics.bicep`)
- **Backup**: Recovery Services Vault using shared module (`../../shared/bicep-modules/backup/recovery-vault.bicep`) (optional)
- **Security**: Network Security Group with RDP access control (inline resource)

### Shared vs Workload-Specific Modules

**Using Shared Modules**:
- VNet and subnet creation → `shared/bicep-modules/networking/vnet.bicep`
- Log Analytics workspace → `shared/bicep-modules/monitoring/loganalytics.bicep`
- Recovery Services Vault → `shared/bicep-modules/backup/recovery-vault.bicep`

**Workload-Specific Modules** (kept due to specialized requirements):
- `modules/virtualmachine.bicep` → Contains Universal Print specific application deployment from Compute Gallery

### Network Security
- NSG rules allow RDP access from specified IP ranges only
- Option to disable RDP access entirely
- Outbound internet access for Universal Print service connectivity

## Deployment

### Prerequisites
- Azure subscription with appropriate permissions
- Azure Compute Gallery with Universal Print Connector application
- Key Vault for storing VM administrator password
- Service connection configured in Azure DevOps

### Parameter Files
The workload now uses environment-specific parameter files instead of default values:
- `parameters/dev.parameters.json` - Development environment settings
- `parameters/prod.parameters.json` - Production environment settings

### Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `connectorName` | Name identifier for the connector (3-15 chars) | - | Yes |
| `environment` | Environment identifier (dev/test/prod) | dev | Yes |
| `location` | Azure region for deployment | resourceGroup().location | No |
| `adminUsername` | VM administrator username | azureuser | No |
| `adminPassword` | VM administrator password | - | Yes |
| `vmSize` | Virtual machine size | Standard_B2als_v2 | No |
| `vnetAddressPrefix` | Virtual network address space | 10.50.0.0/24 | No |
| `subnetPrefix` | Subnet address prefix | 10.50.0.0/24 | No |
| `computeGalleryId` | Azure Compute Gallery resource ID | - | Yes |
| `universalPrintVersion` | Universal Print app version | 1.9036.32141 | No |
| `deployBackup` | Enable VM backup | false | No |
| `deployMonitoring` | Enable Log Analytics monitoring | true | No |
| `allowRdpFromInternet` | Allow RDP from internet | false | No |
| `allowedRdpSources` | Allowed RDP source IP ranges | [] | No |
| `existingVnetId` | Use existing VNet (resource ID) | "" | No |
| `existingSubnetName` | Existing subnet name | "" | No |
| `tags` | Resource tags | {} | No |

### Deployment Options

#### Option 1: Azure DevOps Pipeline
```yaml
# Use the workload-specific pipeline
pipelines/workload-pipelines/universal-print-connector.yml
```

#### Option 2: PowerShell Script
```powershell
# Deploy to development environment
.\deploy-universal-print-connector.ps1 -Environment dev -SubscriptionId "your-subscription-id" -TenantId "your-tenant-id"

# Run What-If analysis
.\deploy-universal-print-connector.ps1 -Environment dev -SubscriptionId "your-subscription-id" -TenantId "your-tenant-id" -WhatIf
```

#### Option 3: Azure CLI
```bash
# Create resource group
az group create --name "rg-up-connector-dev" --location "East US"

# Deploy template
az deployment group create \
  --resource-group "rg-up-connector-dev" \
  --template-file "workloads/universal-print-connector/main.bicep" \
  --parameters "@environments/tenant1/dev/universal-print-connector.parameters.json"
```

## Configuration

### Environment-Specific Settings

#### Development Environment
- VM Size: Standard_B2als_v2 (cost-optimized)
- Backup: Disabled
- RDP: Restricted to private IP ranges
- Monitoring: Enabled

#### Test Environment
- VM Size: Standard_B2as_v2 (performance testing)
- Backup: Enabled
- RDP: Restricted to corporate IP ranges
- Monitoring: Enabled

#### Production Environment
- VM Size: Standard_D2as_v5 (production performance)
- Backup: Enabled with extended retention
- RDP: Highly restricted access
- Monitoring: Enhanced logging enabled

### Post-Deployment Configuration

1. **Connect to VM**:
   ```powershell
   # Using Azure Bastion (recommended)
   az network bastion rdp --name "bastion-name" --resource-group "rg-name" --target-resource-id "/subscriptions/.../virtualMachines/vm-name"
   
   # Using RDP (if allowed)
   mstsc /v:vm-private-ip-address
   ```

2. **Configure Universal Print Connector**:
   - Launch Universal Print Connector application
   - Sign in with Microsoft 365 admin account
   - Register printers to Universal Print service
   - Configure printer sharing and permissions

3. **Verify Connectivity**:
   - Test print from Universal Print client
   - Monitor print queue in Microsoft 365 admin center
   - Check Azure Monitor for VM performance metrics

## Security Considerations

### Network Security
- Default configuration blocks RDP from internet
- Use Azure Bastion for secure VM access
- Configure NSG rules for minimum required access
- Consider using Azure Private Link for enhanced security

### Identity and Access
- VM uses system-assigned managed identity
- Administrator password stored in Azure Key Vault
- Regular password rotation recommended
- Follow principle of least privilege for access

### Monitoring and Compliance
- All VM activities logged to Log Analytics
- Security events monitored through Azure Security Center
- Backup policies ensure data protection compliance
- Regular security assessments and patching

## Troubleshooting

### Common Issues

#### 1. VM Deployment Failures
```bash
# Check deployment status
az deployment group show --resource-group "rg-name" --name "deployment-name"

# Review deployment errors
az deployment group show --resource-group "rg-name" --name "deployment-name" --query "properties.error"
```

#### 2. Network Connectivity Issues
```powershell
# Test network connectivity from VM
Test-NetConnection -ComputerName "printservice.microsoft.com" -Port 443

# Check NSG rules
az network nsg show --resource-group "rg-name" --name "nsg-name" --query "securityRules"
```

#### 3. Universal Print Connector Issues
- Verify internet connectivity from VM
- Check Microsoft 365 service health
- Review Universal Print Connector logs in Event Viewer
- Ensure firewall allows Universal Print service endpoints

### Support Resources
- [Universal Print documentation](https://docs.microsoft.com/en-us/universal-print/)
- [Azure Virtual Machines troubleshooting](https://docs.microsoft.com/en-us/azure/virtual-machines/troubleshooting/)
- [Azure Network Security Groups](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)

## Cost Optimization

### Recommendations
1. **VM Sizing**: Use B-series for development, upgrade to D-series for production
2. **Storage**: Use Premium SSD for OS disk, Standard SSD for data disks
3. **Backup**: Configure retention policies based on business requirements
4. **Monitoring**: Use built-in metrics, add custom metrics only when needed
5. **Shutdown Scheduling**: Implement auto-shutdown for development environments

### Cost Monitoring
```bash
# View resource costs
az consumption usage list --subscription "subscription-id" --start-date "2024-01-01" --end-date "2024-01-31"

# Set up budget alerts
az consumption budget create --amount 500 --budget-name "up-connector-budget" --time-grain "Monthly"
```

## Maintenance

### Regular Tasks
1. **Monthly**: Review and apply Windows updates
2. **Quarterly**: Review NSG rules and access permissions
3. **Bi-annually**: Update Universal Print Connector application
4. **Annually**: Review backup and disaster recovery procedures

### Automation
- Use Azure Update Management for automated patching
- Configure auto-shutdown/start schedules
- Set up alerting for resource health and performance
