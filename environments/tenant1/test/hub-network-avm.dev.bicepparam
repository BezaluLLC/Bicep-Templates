using '../../../workloads/hub-network-avm/main.bicep'

param resourceGroupName = 'RG-Connectivity-test'
param location = 'northcentralus'
param tags = {
  Environment: 'Test'
  Owner: 'NetworkingTeam'
}
param subnetPrefixes = {
  gateway: '10.250.0.0/27'
  firewall: '10.250.0.64/26'
  bastion: '10.250.0.96/27'
  management: '10.250.0.192/26'
  shared: '10.250.1.0/24'
}
param hubNamePrefix = 'hub-dev01'
param vpnGatewaySku = 'Basic'
param enableBgp = false
param publicIpAvailabilityZones = []
param networkManagerScopeSubscriptions = [
  '/subscriptions/11111111-1111-1111-1111-111111111111'
  '/subscriptions/00000000-0000-0000-0000-000000000000'
]
