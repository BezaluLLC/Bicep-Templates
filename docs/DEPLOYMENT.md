# Multi-Workload Infrastructure - Deployment Guide

## 🚀 Quick Start

### Prerequisites
- Azure CLI installed and logged in
- PowerShell 5.1 or later
- Azure subscription with appropriate permissions

### 1. Deploy Any Workload

```powershell
# Navigate to the project directory
cd "c:\Users\LoganCook\OneDrive - Bezalu LLC\Dev\Scratch\ARM"

# Deploy data warehouse to development
.\deploy-workload.ps1 -WorkloadName "data-warehouse" -Environment "dev" -SubscriptionId "your-subscription-id" -TenantId "your-tenant-id"

# Deploy Universal Print Connector to production
.\deploy-workload.ps1 -WorkloadName "universal-print-connector" -Environment "prod" -SubscriptionId "your-subscription-id" -TenantId "your-tenant-id"

# Run What-If analysis before deployment
.\deploy-workload.ps1 -WorkloadName "data-warehouse" -Environment "dev" -SubscriptionId "your-subscription-id" -TenantId "your-tenant-id" -WhatIf
```

### 2. Alternative: Azure CLI Commands

```powershell
# Set your subscription context
az account set --subscription "your-subscription-id"

# Create resource group
az group create --name "rg-data-warehouse-dev" --location "East US"

# Deploy template directly
az deployment group create \
  --resource-group "rg-data-warehouse-dev" \
  --template-file "workloads/data-warehouse/main.bicep" \
  --parameters @"environments/tenant1/dev/data-warehouse.parameters.json"
```

## 📦 Available Workloads

| Workload | Path | Description |
|----------|------|-------------|
| **data-warehouse** | `workloads/data-warehouse/` | Complete data analytics platform |
| **universal-print-connector** | `workloads/universal-print-connector/` | Windows VM with Universal Print Connector |

## 📋 What Gets Deployed

### Data Warehouse Workload
Based on the parameter configuration, the following resources will be created:

#### Core Infrastructure (Always Deployed)
- ✅ Resource Group: `rg-{warehouseName}`
- ✅ Virtual Network: `vnet-{warehouseName}` (10.0.0.0/16)
- ✅ Network Security Groups
- ✅ Log Analytics Workspace
- ✅ Key Vault with private endpoint
- ✅ Data Lake Storage Account

#### Optional Database Services
- 🔘 Azure SQL Database (if `deploySqlDatabase = true`)
- 🔘 PostgreSQL Flexible Server (if `deployPostgreSQL = true`)
- 🔘 Cosmos DB (if `deployCosmosDB = true`)
- 🔘 Synapse Analytics (if `deploySynapse = true`)
- 🔘 Data Factory (if `deployDataFactory = true`)

### Universal Print Connector Workload
Based on the parameter configuration, the following resources will be created:

#### Core Infrastructure (Always Deployed)
- ✅ Resource Group: `rg-up-connector-{environment}`
- ✅ Virtual Network: `vnet-up-{connectorName}-{environment}` (10.50.0.0/24)
- ✅ Network Security Group with RDP access controls
- ✅ Windows Server 2025 Virtual Machine
- ✅ Universal Print Connector application (from Azure Compute Gallery)

#### Optional Services
- 🔘 Log Analytics Workspace (if `deployMonitoring = true`)
- 🔘 Recovery Services Vault with backup (if `deployBackup = true`)

## 🌐 Environment-Specific Configurations

### Development Environment
- Smaller VM sizes for cost optimization
- RDP access from corporate network only
- Basic monitoring enabled
- Backup typically disabled

### Production Environment
- Production-grade VM sizes
- Highly restricted network access
- Enhanced monitoring and alerting
- Backup enabled with extended retention

## ⚙️ Configuration

### Data Warehouse Parameters
Edit `environments/tenant1/{environment}/data-warehouse.parameters.json` to customize:

```json
{
  "parameters": {
    "warehouseName": {
      "value": "mydatawarehouse"  // Change this to your warehouse name
    },
    "deploySqlDatabase": {
      "value": true              // Enable SQL Database
    },
    "deploySynapse": {
      "value": true              // Enable Synapse Analytics
    },
    "deployDataFactory": {
      "value": true              // Enable Data Factory
    }
  }
}
```

### Universal Print Connector Parameters
Edit `environments/tenant1/{environment}/universal-print-connector.parameters.json` to customize:

```json
{
  "parameters": {
    "connectorName": {
      "value": "dev-upc01"       // Change this to your connector name
    },
    "vmSize": {
      "value": "Standard_B2als_v2"  // VM size for the connector
    },
    "allowRdpFromInternet": {
      "value": false             // Security: disable internet RDP
    },
    "allowedRdpSources": {
      "value": ["10.0.0.0/8"]    // Allowed IP ranges for RDP
    }
  }
}
```

## 🔐 Security Features

### Data Warehouse Security
- **Private Endpoints**: All database services use private endpoints
- **Network Security Groups**: Restrictive network rules
- **Key Vault**: Centralized secrets management
- **Managed Identity**: Service-to-service authentication
- **Private DNS**: Secure name resolution

### Universal Print Connector Security
- **Network Isolation**: Dedicated VNet with NSG controls
- **RDP Access Control**: Configurable IP restrictions
- **System Managed Identity**: Secure Azure resource access
- **Password Management**: Key Vault integration for admin passwords

## 🏗️ Multi-Tenant Deployment

Deploy to different tenants/subscriptions:

```powershell
# Deploy to Tenant 1 Development
.\deploy-workload.ps1 -WorkloadName "data-warehouse" -Environment "dev" -Tenant "tenant1" -SubscriptionId "tenant1-dev-sub-id" -TenantId "tenant1-id"

# Deploy to Tenant 2 Production
.\deploy-workload.ps1 -WorkloadName "universal-print-connector" -Environment "prod" -Tenant "tenant2" -SubscriptionId "tenant2-prod-sub-id" -TenantId "tenant2-id"
```

## 🧹 Cleanup

To remove workload resources:

```powershell
# Remove specific workload resource group
az group delete --name "rg-data-warehouse-dev" --yes --no-wait

# Or remove all resources for an environment
az group list --query "[?contains(name, '-dev')].name" -o tsv | ForEach-Object { az group delete --name $_ --yes --no-wait }
```

## 📞 Support

- Check deployment logs in Azure Portal
- Review workload-specific README.md files for detailed documentation
- Use `az deployment group show` for troubleshooting failed deployments
- Check Azure DevOps pipeline logs for CI/CD issues
