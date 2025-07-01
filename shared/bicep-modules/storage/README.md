# Storage and Database Shared Modules

This directory contains reusable Bicep modules for Azure storage and database services. These modules are designed to support various data patterns, from relational databases to NoSQL, analytics, and general storage needs.

## Modules Overview

### Database Services

| Module | Description | Use Case |
|--------|-------------|----------|
| `sql-database.bicep` | Azure SQL Database with server | OLTP applications, relational workloads |
| `postgresql.bicep` | Azure Database for PostgreSQL Flexible Server | Open-source relational databases, web applications |
| `mysql.bicep` | Azure Database for MySQL Flexible Server | MySQL workloads, web applications, CMS |
| `cosmosdb.bicep` | Azure Cosmos DB multi-model database | NoSQL applications, globally distributed apps, MongoDB API |

### Storage Services

| Module | Description | Use Case |
|--------|-------------|----------|
| `storage-account.bicep` | Azure Storage Account with Data Lake Gen2 support | Data lakes, file storage, blob storage |

## Module Documentation

### sql-database.bicep - Azure SQL Database

Creates an Azure SQL Server with SQL Database, including security features, private endpoints, and backup configurations.

**Key Features:**
- SQL Server with AAD admin configuration
- SQL Database with configurable SKU and storage
- Elastic pool support
- Private endpoint connectivity
- Transparent Data Encryption
- Advanced Threat Protection
- Long-term retention policies
- Auditing and diagnostic settings

**Parameters:**
- `sqlServerName`: SQL Server name
- `sqlDatabaseName`: Database name
- `location`: Azure region
- `administratorLogin`: SQL admin username
- `sqlSku`: Database service objective (Basic, S0, P1, etc.)
- `enablePrivateEndpoint`: Enable private endpoint
- `subnetId`: Subnet for private endpoint
- `vnetId`: VNet for DNS zone linking

**Example Usage:**
```bicep
module sqlDatabase 'shared/bicep-modules/storage/sql-database.bicep' = {
  name: 'app-database'
  params: {
    sqlServerName: 'sql-${workloadName}-${environment}'
    sqlDatabaseName: 'appdb'
    location: location
    administratorLogin: 'sqladmin'
    sqlSku: 'S2'
    enablePrivateEndpoint: true
    subnetId: dataSubnet.outputs.subnetId
    vnetId: spoke.outputs.spokeVnetId
    aadAdminObjectId: servicePrincipalObjectId
    aadAdminLogin: 'AppServicePrincipal'
    tags: commonTags
  }
}
```

### postgresql.bicep - Azure Database for PostgreSQL

Creates an Azure Database for PostgreSQL Flexible Server with configurable performance tiers and security settings.

**Key Features:**
- PostgreSQL Flexible Server
- Configurable compute and storage
- Subnet delegation support
- Private DNS zone integration
- High availability options
- Backup retention configuration
- Database and user creation
- Diagnostic settings

**Parameters:**
- `postgresServerName`: PostgreSQL server name
- `location`: Azure region
- `administratorLogin`: Admin username
- `postgresSku`: Server SKU (Standard_B1ms, Standard_D2s_v3, etc.)
- `postgresVersion`: PostgreSQL version (11, 12, 13, 14, 15, 16)
- `enablePrivateEndpoint`: Enable private endpoint
- `subnetId`: Delegated subnet for server
- `vnetId`: VNet for DNS zone linking

**Example Usage:**
```bicep
module postgresql 'shared/bicep-modules/storage/postgresql.bicep' = {
  name: 'app-postgres'
  params: {
    postgresServerName: 'psql-${workloadName}-${environment}'
    location: location
    administratorLogin: 'pgadmin'
    postgresSku: 'Standard_D2s_v3'
    postgresVersion: '15'
    enablePrivateEndpoint: true
    subnetId: dbSubnet.outputs.subnetId
    vnetId: spoke.outputs.spokeVnetId
    databases: [
      { name: 'appdb', charset: 'UTF8', collation: 'en_US.utf8' }
    ]
    tags: commonTags
  }
}
```

### mysql.bicep - Azure Database for MySQL

Creates an Azure Database for MySQL Flexible Server with configurable compute, storage, and networking options.

**Key Features:**
- MySQL Flexible Server
- Configurable compute and storage
- Subnet delegation support
- Private DNS zone integration
- High availability options
- Backup retention configuration
- Database and user creation
- Diagnostic settings

**Parameters:**
- `mysqlServerName`: MySQL server name
- `location`: Azure region
- `administratorLogin`: Admin username
- `mysqlSku`: Server SKU (Standard_B1ms, Standard_D2s_v3, etc.)
- `mysqlVersion`: MySQL version (5.7, 8.0)
- `enablePrivateEndpoint`: Enable private endpoint
- `subnetId`: Delegated subnet for server
- `vnetId`: VNet for DNS zone linking

**Example Usage:**
```bicep
module mysql 'shared/bicep-modules/storage/mysql.bicep' = {
  name: 'app-mysql'
  params: {
    mysqlServerName: 'mysql-${workloadName}-${environment}'
    location: location
    administratorLogin: 'mysqladmin'
    mysqlSku: 'Standard_D2s_v3'
    mysqlVersion: '8.0'
    enablePrivateEndpoint: true
    subnetId: dbSubnet.outputs.subnetId
    vnetId: spoke.outputs.spokeVnetId
    databases: [
      { name: 'appdb', charset: 'utf8', collation: 'utf8_general_ci' }
    ]
    tags: commonTags
  }
}
```

### cosmosdb.bicep - Azure Cosmos DB

Creates an Azure Cosmos DB account with support for multiple APIs, consistency levels, and global distribution.

**Key Features:**
- Multi-API support (SQL, MongoDB, Cassandra, Gremlin, Table)
- Configurable consistency levels
- Multi-region deployments
- Analytical storage support
- Serverless and provisioned throughput
- Private endpoint connectivity
- Database and container creation
- Backup policy configuration

**Parameters:**
- `cosmosAccountName`: Cosmos DB account name
- `location`: Primary region
- `databaseApi`: API type (Sql, MongoDB, etc.)
- `consistencyLevel`: Consistency level
- `enablePrivateEndpoint`: Enable private endpoint
- `additionalLocations`: Additional regions for geo-replication
- `databases`: Databases and containers to create

**Example Usage:**
```bicep
module cosmosdb 'shared/bicep-modules/storage/cosmosdb.bicep' = {
  name: 'app-cosmos'
  params: {
    cosmosAccountName: 'cosmos-${workloadName}-${environment}'
    location: location
    databaseApi: 'Sql'
    consistencyLevel: 'Session'
    enablePrivateEndpoint: true
    subnetId: dataSubnet.outputs.subnetId
    vnetId: spoke.outputs.spokeVnetId
    databases: [
      {
        name: 'AppDatabase'
        containers: [
          {
            name: 'Users'
            partitionKey: '/userId'
            throughput: 400
          }
          {
            name: 'Orders'
            partitionKey: '/customerId'
            throughput: 1000
          }
        ]
      }
    ]
    tags: commonTags
  }
}
```

### storage-account.bicep - Azure Storage Account

Creates an Azure Storage Account with support for Data Lake Gen2, private endpoints, and various storage services.

**Key Features:**
- Data Lake Gen2 support (hierarchical namespace)
- Multiple storage services (Blob, File, Queue, Table)
- Private endpoints for all services
- Configurable security and encryption
- Network access control
- Soft delete and versioning
- Container and file share creation
- SFTP and NFS v3 support

**Parameters:**
- `storageAccountName`: Storage account name
- `location`: Azure region
- `storageAccountSku`: SKU (Standard_LRS, Premium_LRS, etc.)
- `enableHierarchicalNamespace`: Enable Data Lake Gen2
- `privateEndpointConfig`: Private endpoint configuration
- `blobContainers`: Containers to create
- `fileShares`: File shares to create

**Example Usage - Data Lake:**
```bicep
module dataLake 'shared/bicep-modules/storage/storage-account.bicep' = {
  name: 'data-lake'
  params: {
    storageAccountName: 'dl${workloadName}${environment}'
    location: location
    storageAccountSku: 'Standard_LRS'
    enableHierarchicalNamespace: true
    publicNetworkAccess: 'Disabled'
    privateEndpointConfig: {
      enabled: true
      subnetId: dataSubnet.outputs.subnetId
      vnetId: spoke.outputs.spokeVnetId
      services: ['blob', 'dfs']
    }
    blobContainers: [
      { name: 'raw-data', metadata: { classification: 'Bronze' } }
      { name: 'processed-data', metadata: { classification: 'Silver' } }
      { name: 'curated-data', metadata: { classification: 'Gold' } }
    ]
    tags: commonTags
  }
}
```

**Example Usage - General Storage:**
```bicep
module appStorage 'shared/bicep-modules/storage/storage-account.bicep' = {
  name: 'app-storage'
  params: {
    storageAccountName: 'st${workloadName}${environment}'
    location: location
    storageAccountSku: 'Standard_LRS'
    enableBlobSoftDelete: true
    enableBlobVersioning: true
    privateEndpointConfig: {
      enabled: true
      subnetId: appSubnet.outputs.subnetId
      vnetId: spoke.outputs.spokeVnetId
      services: ['blob', 'file']
    }
    blobContainers: [
      { name: 'uploads' }
      { name: 'processed' }
      { name: 'archive' }
    ]
    fileShares: [
      { name: 'shared-files', quota: 1024 }
    ]
    tags: commonTags
  }
}
```

## Common Patterns

### Microservices Data Stack

```bicep
// SQL Database for transactional data
module sqlDb 'shared/bicep-modules/storage/sql-database.bicep' = {
  name: 'transactional-db'
  params: {
    sqlServerName: 'sql-${workloadName}-${environment}'
    sqlDatabaseName: 'transactions'
    sqlSku: 'S2'
    enablePrivateEndpoint: true
    subnetId: dataSubnet.outputs.subnetId
    vnetId: vnet.outputs.vnetId
  }
}

// Cosmos DB for document storage
module cosmosDb 'shared/bicep-modules/storage/cosmosdb.bicep' = {
  name: 'document-db'
  params: {
    cosmosAccountName: 'cosmos-${workloadName}-${environment}'
    databaseApi: 'Sql'
    enablePrivateEndpoint: true
    subnetId: dataSubnet.outputs.subnetId
    vnetId: vnet.outputs.vnetId
  }
}

// Storage for files and logs
module storage 'shared/bicep-modules/storage/storage-account.bicep' = {
  name: 'app-storage'
  params: {
    storageAccountName: 'st${workloadName}${environment}'
    privateEndpointConfig: {
      enabled: true
      subnetId: dataSubnet.outputs.subnetId
      vnetId: vnet.outputs.vnetId
      services: ['blob']
    }
  }
}
```

### Analytics Platform

```bicep
// PostgreSQL for operational analytics
module postgres 'shared/bicep-modules/storage/postgresql.bicep' = {
  name: 'analytics-postgres'
  params: {
    postgresServerName: 'psql-analytics-${environment}'
    postgresSku: 'Standard_D4s_v3'
    enablePrivateEndpoint: true
    subnetId: dbSubnet.outputs.subnetId
    vnetId: vnet.outputs.vnetId
  }
}

// Data Lake for big data analytics
module dataLake 'shared/bicep-modules/storage/storage-account.bicep' = {
  name: 'analytics-lake'
  params: {
    storageAccountName: 'dl${workloadName}${environment}'
    enableHierarchicalNamespace: true
    storageAccountSku: 'Standard_GRS'
    privateEndpointConfig: {
      enabled: true
      subnetId: dataSubnet.outputs.subnetId
      vnetId: vnet.outputs.vnetId
      services: ['blob', 'dfs']
    }
    blobContainers: [
      { name: 'raw-data' }
      { name: 'processed-data' }
      { name: 'curated-data' }
    ]
  }
}
```

### Multi-Region Setup

```bicep
// Multi-region Cosmos DB
module globalCosmosDb 'shared/bicep-modules/storage/cosmosdb.bicep' = {
  name: 'global-cosmos'
  params: {
    cosmosAccountName: 'cosmos-global-${workloadName}'
    enableMultipleWriteLocations: true
    additionalLocations: [
      { locationName: 'West Europe', isZoneRedundant: true }
      { locationName: 'East Asia', isZoneRedundant: false }
    ]
    consistencyLevel: 'Session'
  }
}

// Geo-replicated storage
module geoStorage 'shared/bicep-modules/storage/storage-account.bicep' = {
  name: 'geo-storage'
  params: {
    storageAccountName: 'stgeo${workloadName}${environment}'
    storageAccountSku: 'Standard_RAGRS'
    enableBlobVersioning: true
  }
}
```

## Security Best Practices

1. **Use Private Endpoints**: Enable private endpoints for all database and storage services
2. **Network Isolation**: Configure network ACLs to restrict access to specific subnets
3. **Encryption**: Enable encryption at rest and in transit for all services
4. **Access Control**: Use Azure AD authentication where possible
5. **Auditing**: Enable diagnostic settings and auditing for compliance
6. **Backup**: Configure appropriate backup retention policies
7. **Secrets Management**: Store connection strings and keys in Azure Key Vault

## Performance Considerations

1. **Right-size Resources**: Choose appropriate SKUs based on workload requirements
2. **Geo-location**: Place resources close to your users and applications
3. **Caching**: Use Redis Cache or built-in caching features where applicable
4. **Connection Pooling**: Implement connection pooling for database connections
5. **Monitoring**: Set up monitoring and alerts for performance metrics

## Migration from Existing Modules

To migrate existing workloads to use these shared modules:

1. **Inventory existing resources** and their configurations
2. **Map current settings** to shared module parameters
3. **Update workload templates** to use shared modules
4. **Test in development** before production migration
5. **Plan for minimal downtime** during migration

## Support and Contributions

These modules are part of the shared infrastructure library. For questions, issues, or enhancement requests, please refer to the main project documentation and follow the established contribution guidelines.
