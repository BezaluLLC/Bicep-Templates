# Azure Infrastructure Template Library

This repository serves as a **Template Library** containing Infrastructure as Code (IaC) templates for deploying various Azure workloads across multiple tenants and environments. The templates are designed for **programmatic consumption** by automation tools, CI/CD pipelines, or custom applications.

## 🎯 Purpose

This repository is a **reference library** that provides:

- **Discoverable Bicep templates** for common Azure workloads
- **Reusable modules** for infrastructure components
- **Standardized parameter schemas** for consistent deployments

## 🏗️ Repository Structure

```text
📦 azure-infrastructure/
├── 📁 workloads/                             # Individual workload deployments
│   ├── 📁 data-warehouse/                    # Data warehouse infrastructure
│   ├── 📁 universal-print-connector/         # Universal Print Connector infrastructure
│   └── 📁 hub-network-avm/       # Hub networking infrastructure
├── 📁 environments/                          # Environment-specific configurations
│   └── 📁 exampletenant/
│       ├── 📁 test/                              # Test environment configs
│       └── 📁 prod/                              # Production environment configs
└── 📁 docs/                                  # Documentation and guides
```

## 🎯 Design Principles

### 1. **Workload Isolation**

- Each workload is self-contained in its own folder
- Independent deployment capabilities

### 2. **Shared Components**

- Platform workloads for centralized dependencies
- Azure Verified Bicep modules for first-party support
- Standardized naming conventions
- Shared policy and RBAC definitions

### 3. **Multi-Tenant/Multi-Subscription Support**

- Environment-specific parameter files

## 📋 Available Workloads

| Workload | Description | Status |
|----------|-------------|--------|
| **data-warehouse** | Comprehensive data analytics platform | 🚧 Planned |
| **universal-print-connector** | Windows VM with Universal Print Connector | 🚧 Planned |
| **hub-network-avm** | Hub networking for hybrid connectivity | ✅ Ready |

## 📜 Documentation

- **[Quick Start Guide](docs/QUICKSTART.md)** - Fast track to using templates
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Comprehensive deployment instructions
- **[Multi-Tenant Strategy](docs/multi-tenant-strategy.md)** - Architecture for multiple environments

## 🔗 Integration Examples

### Terraform Integration

```hcl
# Use Bicep templates with Terraform AzAPI provider
resource "azapi_resource_action" "deploy_from_template" {
  type        = "Microsoft.Resources/deployments@2021-04-01"
  resource_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group}"
  method      = "PUT"
  
  body = jsonencode({
    properties = {
      mode       = "Incremental"
      templateUri = "https://raw.githubusercontent.com/yourorg/azure-infrastructure/main/workloads/data-warehouse/main.bicep"
      parameters = var.deployment_parameters
    }
  })
}
```

### PowerShell Integration

```powershell
# Download and deploy template
$templateUrl = "https://raw.githubusercontent.com/yourorg/azure-infrastructure/main/workloads/data-warehouse/main.bicep"
$templatePath = "./data-warehouse.bicep"

Invoke-WebRequest -Uri $templateUrl -OutFile $templatePath

New-AzResourceGroupDeployment `
  -ResourceGroupName "my-rg" `
  -TemplateFile $templatePath `
  -TemplateParameterFile "./my-parameters.json"
```

## 🤝 Contributing to the Template Library

1. **Fork** the repository for your changes
2. **Add new templates** following the established structure
3. **Update catalog.json** with new template metadata  
4. **Create pull request** with proper documentation
5. **Template validation** runs automatically
6. **Merge** adds templates to the library

## 📞 Support & Community

- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: GitHub Discussions for questions and ideas
- **Documentation**: All docs are in the `/docs` folder
