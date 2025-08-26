# Azure Infrastructure Template Library

This repository serves as a **Template Library** containing Infrastructure as Code (IaC) templates for deploying various Azure workloads across multiple tenants and environments. The templates are designed for **programmatic consumption** by automation tools, CI/CD pipelines, or custom applications.

## 🎯 Purpose

This repository is a **reference library** that provides:
- **Discoverable Bicep templates** for common Azure workloads
- **Reusable modules** for infrastructure components
- **Standardized parameter schemas** for consistent deployments

## 🏗️ Repository Structure

```
📦 azure-infrastructure/
├── 📁 workloads/                             # Individual workload deployments
│   ├── 📁 data-warehouse/                    # Data warehouse infrastructure
│   ├── 📁 universal-print-connector/         # Universal Print Connector infrastructure
│   ├── 📁 web-application/                   # Web application hosting
│   ├── 📁 analytics-platform/                # Analytics and reporting
│   └── 📁 virtual-network-gateway-hub/       # Hub networking infrastructure
├── 📁 shared/                                # Shared modules and templates
│   ├── 📁 bicep-modules/                     # Reusable Bicep modules
│   ├── 📁 policy-definitions/                # Azure Policy definitions
│   └── 📁 rbac-definitions/                  # Custom RBAC role definitions
├── 📁 environments/                          # Environment-specific configurations
│   ├── 📁 dev/                               # Development environment configs
│   ├── 📁 test/                              # Test environment configs
│   └── 📁 prod/                              # Production environment configs
└── 📁 docs/                                  # Documentation and guides
```

## 🎯 Design Principles

### 1. **Workload Isolation**
- Each workload is self-contained in its own folder
- Independent deployment capabilities
- Workload-specific parameter files and configurations

### 2. **Shared Components**
- Common Bicep modules for reusability
- Standardized naming conventions
- Shared policy and RBAC definitions

### 3. **Multi-Tenant/Multi-Subscription Support**
- Environment-specific parameter files
- Tenant and subscription abstraction
- Service connection management per environment

### 4. **Azure DevOps Integration**
- YAML pipeline definitions
- Service connections per tenant/subscription
- Variable groups for environment configuration

## 🚀 Consumption Patterns

### 1. Direct File Access
Access templates directly from the repository:

```bash
# Download template via raw GitHub URL
curl https://raw.githubusercontent.com/yourorg/azure-infrastructure/main/workloads/data-warehouse/main.bicep

# Download parameter schema
curl https://raw.githubusercontent.com/yourorg/azure-infrastructure/main/workloads/data-warehouse/parameters.schema.json
```

### 2. GitHub API Access
Use GitHub API for programmatic discovery:

```bash
# List all workloads
curl https://api.github.com/repos/yourorg/azure-infrastructure/contents/workloads

# Get specific template
curl https://api.github.com/repos/yourorg/azure-infrastructure/contents/workloads/data-warehouse/main.bicep
```

## 📋 Available Workloads

| Workload | Description | Status |
|----------|-------------|--------|
| **data-warehouse** | Comprehensive data analytics platform | ✅ Ready |
| **universal-print-connector** | Windows VM with Universal Print Connector | ✅ Ready |
| **web-application** | Scalable web application hosting | 🚧 Planned |
| **analytics-platform** | Business intelligence and reporting | 🚧 Planned |
| **network-hub** | Hub networking for hybrid connectivity | 🚧 Planned |

## � Documentation

- **[Template Catalog](catalog.json)** - Machine-readable manifest of all templates
- **[OpenAPI Specification](api/openapi.json)** - REST API for template discovery
- **[Consumption Guide](CONSUMPTION.md)** - Detailed examples for using templates in automation
- **[Quick Start Guide](QUICKSTART.md)** - Fast track to using templates
- **[Deployment Guide](DEPLOYMENT.md)** - Comprehensive deployment instructions
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
