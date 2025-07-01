/*
  Shared Azure Virtual Network Manager (AVNM) Module
  
  Creates an Azure Virtual Network Manager with configurable network groups,
  connectivity configurations, and deployment automation for different
  network topologies including mesh, hub-and-spoke, and hybrid approaches.
*/

@description('Azure region for AVNM deployment')
param location string

@description('AVNM name')
param avnmName string = 'avnm-${location}'

@description('Spoke VNet resource IDs for static membership')
param spokeVnetIds array = []

@description('Hub VNet resource ID')
param hubVnetId string = ''

@description('Connectivity topology type')
@allowed(['mesh', 'hubAndSpoke', 'meshWithHubAndSpoke'])
param connectivityTopology string = 'meshWithHubAndSpoke'

@description('Network group membership type')
@allowed(['static', 'dynamic'])
param networkGroupMembershipType string = 'static'

@description('AVNM scope access types')
param scopeAccessTypes array = ['Connectivity']

@description('Subscription IDs for AVNM scope')
param subscriptionIds array = [subscription().subscriptionId]

@description('Management group IDs for AVNM scope')
param managementGroupIds array = []

@description('Enable hub gateway transit for spoke VNets')
param enableHubGateway bool = false

@description('Delete existing peering when applying configurations')
param deleteExistingPeering bool = true

@description('Enable global mesh connectivity')
param enableGlobalMesh bool = false

@description('Network group configuration for dynamic membership')
param networkGroupConfig object = {
  name: 'ng-spokes'
  description: 'Network Group for spoke VNets'
}

@description('Connectivity configuration name prefix')
param connectivityConfigPrefix string = 'cc-${connectivityTopology}'

@description('Create user-assigned identity for deployment operations')
param createManagedIdentity bool = true

@description('Auto-deploy AVNM configurations using deployment script')
param autoDeployConfigurations bool = true

@description('Deployment script name')
param deploymentScriptName string = 'ds-avnm-deploy-${location}'

@description('Target locations for AVNM deployment')
param targetLocations array = [location]

@description('Resource tags')
param tags object = {}

// Azure Virtual Network Manager
resource networkManager 'Microsoft.Network/networkManagers@2023-11-01' = {
  name: avnmName
  location: location
  properties: {
    networkManagerScopeAccesses: scopeAccessTypes
    networkManagerScopes: {
      subscriptions: [for subId in subscriptionIds: '/subscriptions/${subId}']
      managementGroups: [for mgId in managementGroupIds: '/providers/Microsoft.Management/managementGroups/${mgId}']
    }
  }
  tags: tags
}

// Static Network Group for Spokes (and Hub if mesh topology)
resource networkGroupStatic 'Microsoft.Network/networkManagers/networkGroups@2023-11-01' = if (networkGroupMembershipType == 'static') {
  name: '${networkGroupConfig.name}-static'
  parent: networkManager
  properties: {
    description: '${networkGroupConfig.description} - Static Membership'
  }
}

// Static Members - Spoke VNets
resource staticMembersSpokes 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2023-11-01' = [for (spokeId, i) in spokeVnetIds: if (networkGroupMembershipType == 'static') {
  name: 'sm-${last(split(spokeId, '/'))}'
  parent: networkGroupStatic
  properties: {
    resourceId: spokeId
  }
}]

// Static Member - Hub VNet (only for mesh topology)
resource staticMemberHub 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2023-11-01' = if (networkGroupMembershipType == 'static' && connectivityTopology == 'mesh' && !empty(hubVnetId)) {
  name: 'sm-${last(split(hubVnetId, '/'))}'
  parent: networkGroupStatic
  properties: {
    resourceId: hubVnetId
  }
}

// Dynamic Network Group for Spokes
resource networkGroupDynamic 'Microsoft.Network/networkManagers/networkGroups@2023-11-01' = if (networkGroupMembershipType == 'dynamic') {
  name: '${networkGroupConfig.name}-dynamic'
  parent: networkManager
  properties: {
    description: '${networkGroupConfig.description} - Dynamic Membership'
  }
}

// Get the appropriate network group ID
var networkGroupId = networkGroupMembershipType == 'static' ? networkGroupStatic.id : networkGroupDynamic.id

// Connectivity Configuration - Mesh
resource connectivityConfigMesh 'Microsoft.Network/networkManagers/connectivityConfigurations@2023-11-01' = if (connectivityTopology == 'mesh') {
  name: '${connectivityConfigPrefix}-mesh'
  parent: networkManager
  properties: {
    description: 'Mesh connectivity between all VNets including hub and spokes'
    appliesToGroups: [
      {
        networkGroupId: networkGroupId
        isGlobal: enableGlobalMesh ? 'True' : 'False'
        useHubGateway: enableHubGateway ? 'True' : 'False'
        groupConnectivity: 'DirectlyConnected'
      }
    ]
    connectivityTopology: 'Mesh'
    deleteExistingPeering: deleteExistingPeering ? 'True' : 'False'
    hubs: []
    isGlobal: enableGlobalMesh ? 'True' : 'False'
  }
}

// Connectivity Configuration - Hub and Spoke
resource connectivityConfigHubSpoke 'Microsoft.Network/networkManagers/connectivityConfigurations@2023-11-01' = if (connectivityTopology == 'hubAndSpoke') {
  name: '${connectivityConfigPrefix}-hubspoke'
  parent: networkManager
  properties: {
    description: 'Hub and spoke connectivity with spokes connected only to hub'
    appliesToGroups: [
      {
        networkGroupId: networkGroupId
        isGlobal: enableGlobalMesh ? 'True' : 'False'
        useHubGateway: enableHubGateway ? 'True' : 'False'
        groupConnectivity: 'None'
      }
    ]
    connectivityTopology: 'HubAndSpoke'
    deleteExistingPeering: deleteExistingPeering ? 'True' : 'False'
    hubs: !empty(hubVnetId) ? [
      {
        resourceId: hubVnetId
        resourceType: 'Microsoft.Network/virtualNetworks'
      }
    ] : []
    isGlobal: enableGlobalMesh ? 'True' : 'False'
  }
}

// Connectivity Configuration - Mesh with Hub and Spoke
resource connectivityConfigMeshWithHubSpoke 'Microsoft.Network/networkManagers/connectivityConfigurations@2023-11-01' = if (connectivityTopology == 'meshWithHubAndSpoke') {
  name: '${connectivityConfigPrefix}-meshwithhubspoke'
  parent: networkManager
  properties: {
    description: 'Mesh connectivity between spokes with hub connected via peering'
    appliesToGroups: [
      {
        networkGroupId: networkGroupId
        isGlobal: enableGlobalMesh ? 'True' : 'False'
        useHubGateway: enableHubGateway ? 'True' : 'False'
        groupConnectivity: 'DirectlyConnected'
      }
    ]
    connectivityTopology: 'HubAndSpoke'
    deleteExistingPeering: deleteExistingPeering ? 'True' : 'False'
    hubs: !empty(hubVnetId) ? [
      {
        resourceId: hubVnetId
        resourceType: 'Microsoft.Network/virtualNetworks'
      }
    ] : []
    isGlobal: enableGlobalMesh ? 'True' : 'False'
  }
}

// User Assigned Identity for deployment operations
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (createManagedIdentity) {
  name: 'uai-${avnmName}'
  location: location
  tags: tags
}

// Role assignment for the user assigned identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createManagedIdentity) {
  name: guid(resourceGroup().id, userAssignedIdentity.name, 'NetworkContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7') // Network Contributor
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// AVNM Configuration Deployment Script
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (autoDeployConfigurations && createManagedIdentity) {
  name: deploymentScriptName
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '8.3'
    retentionInterval: 'PT1H'
    timeout: 'PT1H'
    arguments: '-networkManagerName "${networkManager.name}" -targetLocations ${join(targetLocations, ',')} -configIds ${connectivityTopology == 'mesh' ? connectivityConfigMesh.id : (connectivityTopology == 'hubAndSpoke' ? connectivityConfigHubSpoke.id : connectivityConfigMeshWithHubSpoke.id)} -subscriptionId ${subscription().subscriptionId} -configType "Connectivity" -resourceGroupName ${resourceGroup().name}'
    scriptContent: '''
    param (
      # AVNM subscription id
      [parameter(mandatory=$true)][string]$subscriptionId,

      # AVNM resource name
      [parameter(mandatory=$true)][string]$networkManagerName,

      # string with comma-separated list of config ids to deploy. ids must be of the same config type
      [parameter(mandatory=$true)][string[]]$configIds,

      # string with comma-separated list of deployment target regions
      [parameter(mandatory=$true)][string[]]$targetLocations,

      # configuration type to deploy. must be either connecticity or securityadmin
      [parameter(mandatory=$true)][ValidateSet('Connectivity','SecurityAdmin','Routing')][string]$configType,

      # AVNM resource group name
      [parameter(mandatory=$true)][string]$resourceGroupName
    )
  
    $null = Login-AzAccount -Identity -Subscription $subscriptionId
  
    [System.Collections.Generic.List[string]]$configIdList = @()  
    $configIdList.addRange($configIds) 
    [System.Collections.Generic.List[string]]$targetLocationList = @() # target locations for deployment
    $targetLocationList.addRange($targetLocations)     
    
    $deployment = @{
        Name = $networkManagerName
        ResourceGroupName = $resourceGroupName
        ConfigurationId = $configIdList
        TargetLocation = $targetLocationList
        CommitType = $configType
    }
  
    try {
      Deploy-AzNetworkManagerCommit @deployment -ErrorAction Stop
    }
    catch {
      Write-Error "Deployment failed with error: $_"
      throw "Deployment failed with error: $_"
    }    '''
  }
  tags: tags
  dependsOn: [
    roleAssignment
  ]
}

// Outputs
output networkManagerId string = networkManager.id
output networkManagerName string = networkManager.name

output networkGroupId string = networkGroupId
output networkGroupName string = networkGroupMembershipType == 'static' ? networkGroupStatic.name : networkGroupDynamic.name

output connectivityConfigurationId string = connectivityTopology == 'mesh' ? connectivityConfigMesh.id : (connectivityTopology == 'hubAndSpoke' ? connectivityConfigHubSpoke.id : connectivityConfigMeshWithHubSpoke.id)
output connectivityConfigurationName string = connectivityTopology == 'mesh' ? connectivityConfigMesh.name : (connectivityTopology == 'hubAndSpoke' ? connectivityConfigHubSpoke.name : connectivityConfigMeshWithHubSpoke.name)

output userAssignedIdentityId string = createManagedIdentity ? userAssignedIdentity.id : ''
output userAssignedIdentityPrincipalId string = createManagedIdentity ? userAssignedIdentity.properties.principalId : ''

output deploymentScriptId string = (autoDeployConfigurations && createManagedIdentity) ? deploymentScript.id : ''
output deploymentScriptName string = (autoDeployConfigurations && createManagedIdentity) ? deploymentScript.name : ''

// Configuration summary for reference
output configurationSummary object = {
  topology: connectivityTopology
  membershipType: networkGroupMembershipType
  hubGatewayEnabled: enableHubGateway
  globalMeshEnabled: enableGlobalMesh
  deleteExistingPeering: deleteExistingPeering
  spokeCount: length(spokeVnetIds)
  hasHub: !empty(hubVnetId)
}
