# Quick Start Guide

## 🚀 Getting Started with Multi-Workload Infrastructure

This repository contains multiple Azure workloads that can be deployed independently or together across different environments and tenants.

### 📋 Prerequisites

1. **Azure CLI**: [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **PowerShell**: 5.1 or later
3. **Azure Subscription**: With appropriate permissions
4. **Service Principal or User Account**: With deployment permissions

### ⚡ Quick Deploy - Any Workload

```powershell
# Clone the repository
git clone <repository-url>
cd azure-infrastructure

# Deploy data warehouse to development
.\deploy-workload.ps1 -WorkloadName "data-warehouse" -Environment "dev" -SubscriptionId "your-subscription-id" -TenantId "your-tenant-id"

# Deploy Universal Print Connector to production
.\deploy-workload.ps1 -WorkloadName "universal-print-connector" -Environment "prod" -SubscriptionId "your-subscription-id" -TenantId "your-tenant-id"
```

### 🎯 What You Get

| Workload | Time to Deploy | What's Included |
|----------|----------------|-----------------|
| **data-warehouse** | ~15-20 min | SQL DB, Data Lake, Synapse, Data Factory, Networking |
| **universal-print-connector** | ~10-15 min | Windows VM, Universal Print App, Monitoring, Backup |

### 🔧 Customization

1. **Edit Parameters**: Modify files in `environments/tenant1/{env}/`
2. **Update Templates**: Customize Bicep files in `workloads/{workload}/`
3. **Add Workloads**: Copy existing workload structure

### 🔄 CI/CD Setup

1. **Azure DevOps**: Run `.\setup-azdo-project.ps1`
2. **Service Connections**: Create for each environment
3. **Variable Groups**: Configure secrets and settings
4. **Pipelines**: Import from `pipelines/workload-pipelines/`

### 📚 Next Steps

- [Detailed Deployment Guide](DEPLOYMENT.md)
- [Repository Structure](README.md)
- [Multi-Tenant Strategy](docs/multi-tenant-strategy.md)
- [Workload Documentation](workloads/)

### 💡 Pro Tips

```powershell
# Preview changes before deployment
.\deploy-workload.ps1 -WorkloadName "data-warehouse" -Environment "dev" -SubscriptionId "your-sub-id" -TenantId "your-tenant-id" -WhatIf

# Force deployment without confirmation
.\deploy-workload.ps1 -WorkloadName "data-warehouse" -Environment "dev" -SubscriptionId "your-sub-id" -TenantId "your-tenant-id" -Force

# Deploy to different tenant
.\deploy-workload.ps1 -WorkloadName "data-warehouse" -Environment "prod" -Tenant "tenant2" -SubscriptionId "tenant2-sub-id" -TenantId "tenant2-id"
```
