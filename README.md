# Azure Infrastructure Template Library

This repository serves as a **Template Library** containing Infrastructure as Code (IaC) templates for deploying various Azure workloads across multiple tenants and environments. The templates are designed for **programmatic consumption** by automation tools, CI/CD pipelines, or custom applications.

## 🎯 Purpose

This repository is a **reference library** that provides:
- **Discoverable Bicep templates** for common Azure workloads
- **Reusable modules** for infrastructure components
- **Standardized parameter schemas** for consistent deployments
- **Machine-readable catalog** for automation tools
- **REST API specification** for programmatic access

## 📋 Template Catalog

Browse available templates programmatically via the catalog:
- **Catalog**: [`catalog.json`](catalog.json) - Machine-readable manifest of all templates
- **API Spec**: [`api/openapi.json`](api/openapi.json) - REST API specification for template discovery

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

### 3. Template Library API
Use the OpenAPI specification to build consuming applications:

```javascript
// Example: Fetch catalog of available templates
const response = await fetch('/api/catalog');
const catalog = await response.json();

// Get specific workload template
const template = await fetch(`/api/workloads/data-warehouse/template`);
const bicepContent = await template.text();
```

### 4. Automated CI/CD Integration
Integrate templates into your deployment pipelines:

```yaml
# Example: Azure DevOps Pipeline consuming templates
stages:
  - stage: Deploy
    jobs:
    - job: DeployInfrastructure
      steps:
      - script: |
          # Download template from library
          curl -o main.bicep https://raw.githubusercontent.com/yourorg/azure-infrastructure/main/workloads/data-warehouse/main.bicep
          
          # Deploy using Azure CLI
          az deployment group create \
            --resource-group $(resourceGroup) \
            --template-file main.bicep \
            --parameters @my-custom-parameters.json
```

## 🏢 Multi-Environment Support

### Parameter Templates
Environment-specific parameter files provide deployment flexibility:

```
environments/
├── tenant1/
│   ├── dev/
│   │   └── data-warehouse.parameters.json    # Development parameters
│   └── prod/
│       └── data-warehouse.parameters.json    # Production parameters
└── tenant2/
    ├── dev/
    │   └── data-warehouse.parameters.json    # Different tenant config
    └── prod/
        └── data-warehouse.parameters.json
```

### Parameter Schema Validation
Each workload includes parameter schemas for validation:

```json
{
  "$schema": "https://json-schema.org/draft/2019-09/schema",
  "type": "object",
  "properties": {
    "environment": {
      "type": "string",
      "enum": ["dev", "test", "prod"]
    },
    "location": {
      "type": "string",
      "default": "eastus"
    }
  }
}
```

## 📋 Available Workloads

| Workload | Description | Status |
|----------|-------------|--------|
| **data-warehouse** | Comprehensive data analytics platform | ✅ Ready |
| **universal-print-connector** | Windows VM with Universal Print Connector | ✅ Ready |
| **web-application** | Scalable web application hosting | 🚧 Planned |
| **analytics-platform** | Business intelligence and reporting | 🚧 Planned |
| **network-hub** | Hub networking for hybrid connectivity | 🚧 Planned |

## 🛠️ Getting Started

### 1. Browse the Template Catalog
```bash
# Download catalog to see all available templates
curl https://raw.githubusercontent.com/yourorg/azure-infrastructure/main/catalog.json

# Or browse via GitHub
# Navigate to: https://github.com/yourorg/azure-infrastructure/blob/main/catalog.json
```

### 2. Use a Template in Your Project
```bash
# Option 1: Download template files directly
mkdir my-infrastructure
cd my-infrastructure

# Download main template
curl -o data-warehouse.bicep https://raw.githubusercontent.com/yourorg/azure-infrastructure/main/workloads/data-warehouse/main.bicep

# Download parameter schema for validation
curl -o parameters.schema.json https://raw.githubusercontent.com/yourorg/azure-infrastructure/main/workloads/data-warehouse/parameters.schema.json

# Create your own parameter file based on schema
cp environments/tenant1/dev/data-warehouse.parameters.json my-parameters.json

# Deploy using Azure CLI
az deployment group create \
  --resource-group "my-resource-group" \
  --template-file data-warehouse.bicep \
  --parameters @my-parameters.json
```

### 3. Integrate with Your Automation
```python
# Example: Python script consuming template library
import requests
import json

# Get catalog
catalog_url = "https://raw.githubusercontent.com/yourorg/azure-infrastructure/main/catalog.json"
catalog = requests.get(catalog_url).json()

# Find data warehouse workload
for workload in catalog['workloads']:
    if workload['name'] == 'data-warehouse':
        template_url = workload['templateUrl']
        template_content = requests.get(template_url).text
        
        # Use template in your deployment logic
        print(f"Downloaded template: {len(template_content)} characters")
```

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
- **API Reference**: See `api/openapi.json` for programmatic access
