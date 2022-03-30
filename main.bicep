targetScope = 'subscription'

param workload string
param environment string
param location string = deployment().location
param deploymentName string = '${deployment().name}-${uniqueString(utcNow())}'
param principalId string
param kubernetesVersion string = '1.22.6'
param dnsZoneId string
param addressPrefix string
param firewallAvailabilityZones array = [
  '1'
  '2'
  '3'
]

var frontDoorPrincipalId = '4dbab725-22a4-44d5-ad44-c267ca38a954'

var resourceSuffix = '${workload}-${environment}-${location}'

var internalLoadBalancerIpAddress = replace(replace(virtualNetwork.outputs.systemNodePoolSubnetAddressPrefix, '.0', '.100'), '/24', '')

var hostname = last(split(dnsZoneId, '/'))

var keyVaultSecretName = replace(hostname, '.', '-')

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${resourceSuffix}'
  location: location
  tags: {
    workload: workload
    environment: environment
  }
}

module virtualNetwork './vnet.bicep' = {
  name: '${deploymentName}-vnet'
  scope: resourceGroup
  params: {
    resourceSuffix: resourceSuffix
    location: location
    addressPrefix: addressPrefix
  }
}

module logAnalyticsWorkspace './log.bicep' = {
  name: '${deploymentName}-log'
  scope: resourceGroup
  params: {
    resourceSuffix: resourceSuffix
    location: location
  }
}

module keyVault './kv.bicep' = {
  name: '${deploymentName}-kv'
  scope: resourceGroup
  params: {
    location: location
    frontDoorPrincipalId: frontDoorPrincipalId
    principalId: principalId
    resourceSuffix: resourceSuffix
    secretName: keyVaultSecretName
  }
}

module firewall 'afw.bicep' = {
  name: '${deploymentName}-afw'
  scope: resourceGroup
  params: {
    location: location
    availabilityZones: firewallAvailabilityZones
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    resourceSuffix: resourceSuffix
    subnetId: virtualNetwork.outputs.firewallSubnetId
    internalLoadBalancerIpAddress: internalLoadBalancerIpAddress
  }
}

module managedCluster './aks.bicep' = {
  name: '${deploymentName}-aks'
  scope: resourceGroup
  params: {
    resourceSuffix: resourceSuffix
    location: location
    kubernetesVersion: kubernetesVersion
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    virtualNetworkId: virtualNetwork.outputs.id
    systemNodePoolSubnetId: virtualNetwork.outputs.systemNodePoolSubnetId
    userNodePoolSubnetId: virtualNetwork.outputs.userNodePoolSubnetId
    principalId: principalId
    firewallPublicIpAddress: firewall.outputs.publicIpAddress
    firewallPrivateIpAddress: firewall.outputs.privateIpAddress
    routeTableId: virtualNetwork.outputs.routeTableId
  }
}

module frontDoor 'fd.bicep' = {
  scope: resourceGroup
  name: '${deploymentName}-fd'
  params: {
    dnsZoneId: dnsZoneId
    publicIpAddressId: firewall.outputs.publicIpAddressId
    resourceSuffix: resourceSuffix
    keyVaultSecretId: keyVault.outputs.secretId
  }
 }

output managedClusterIssuerUrl string = managedCluster.outputs.issuerUrl
output azCliCommandText string = 'az aks get-credentials -n ${managedCluster.outputs.name} -g ${resourceGroup.name} --context ${workload}-${environment} --overwrite-existing && kubelogin convert-kubeconfig -l azurecli'
output firewallPolicyId string = firewall.outputs.policyId
output virtualNetworkId string = virtualNetwork.outputs.id
output clusterSubnet string = virtualNetwork.outputs.userNodePoolSubnetAddressPrefix
output clusterFqdn string = managedCluster.outputs.fqdn
output azCliSetContainerLogPlan string = 'az monitor log-analytics workspace table update --subscription ${subscription().subscriptionId} --resource-group ${resourceGroup.name}  --workspace-name ${logAnalyticsWorkspace.outputs.name} --name ContainerLog  --plan Basic'
output internalLoadBalancerIpAddress string = internalLoadBalancerIpAddress
output hostname string = hostname
