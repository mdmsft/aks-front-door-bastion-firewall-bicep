param resourceSuffix string
param location string
param kubernetesVersion string
param systemNodePoolSubnetId string
param virtualNetworkId string
param userNodePoolSubnetId string
param logAnalyticsWorkspaceId string
param principalId string
param firewallPublicIpAddress string
param firewallPrivateIpAddress string
param routeTableId string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: last(split(virtualNetworkId, '/'))
}

resource routeTable 'Microsoft.Network/routeTables@2021-05-01' existing = {
  name: last(split(routeTableId, '/'))

  resource routeToFirewall 'routes' = {
    name: 'net-afw'
    properties: {
      nextHopType: 'VirtualAppliance'
      addressPrefix: '0.0.0.0/0'
      nextHopIpAddress: firewallPrivateIpAddress
    }
  }

  resource routeFromFirewall 'routes' = {
    name: 'afw-www'
    properties: {
      addressPrefix: '${firewallPublicIpAddress}/32'
      nextHopType: 'Internet'
    }
  }
}

resource managedCluster 'Microsoft.ContainerService/managedClusters@2022-01-02-preview' = {
  name: 'aks-${resourceSuffix}'
  dependsOn: [
    routeTable::routeToFirewall
    routeTable::routeFromFirewall
  ]
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    aadProfile: {
      enableAzureRBAC: true
      managed: true
    }
    autoUpgradeProfile: {
      upgradeChannel: 'rapid'
    }
    disableLocalAccounts: true
    kubernetesVersion: kubernetesVersion
    dnsPrefix: resourceSuffix
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'default'
        count: 1
        minCount: 1
        maxCount: 3
        vmSize: 'Standard_D4s_v3'
        osType: 'Linux'
        mode: 'System'
        enableAutoScaling: true
        maxPods: 30
        nodeTaints: [
          'CriticalAddonsOnly:NoSchedule'
        ]
        osDiskSizeGB: 30
        osDiskType: 'Ephemeral'
        osSKU: 'CBLMariner'
        type: 'VirtualMachineScaleSets'
        upgradeSettings: {
          maxSurge: '100%'
        }
        vnetSubnetID: systemNodePoolSubnetId
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.0.0.0/24'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '192.168.255.0/24'
      outboundType: 'userDefinedRouting'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    }
  }

  resource agentPool 'agentPools' = {
    name: 'main'
    properties: {
      count: 1
      minCount: 1
      maxCount: 3
      vmSize: 'Standard_F4s_v2'
      osType: 'Linux'
      mode: 'User'
      enableAutoScaling: true
      maxPods: 30
      osDiskSizeGB: 30
      osDiskType: 'Ephemeral'
      osSKU: 'CBLMariner'
      type: 'VirtualMachineScaleSets'
      upgradeSettings: {
        maxSurge: '100%'
      }
      vnetSubnetID: userNodePoolSubnetId
    }
  }
}

var networkContributorRoleDefinitionId = '4d97b98b-1d4f-4787-a291-c67834d212e7'
var aksRbacClusterAdminRoleDefinitionId = 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
var readerRoleDefinitionId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

resource kubeletIdentityNetworkContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(networkContributorRoleDefinitionId, virtualNetworkId, managedCluster.id, 'kubelet')
  scope: virtualNetwork
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', networkContributorRoleDefinitionId)
    principalId: managedCluster.properties.identityProfile.kubeletIdentity.objectId
  }
}

resource managedIdentityNetworkContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(networkContributorRoleDefinitionId, virtualNetworkId, managedCluster.id)
  scope: virtualNetwork
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', networkContributorRoleDefinitionId)
    principalId: managedCluster.identity.principalId
  }
}

resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(readerRoleDefinitionId, resourceGroup().id, managedCluster.id)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleDefinitionId)
    principalId: managedCluster.identity.principalId
  }
}

resource aksRbacClusterAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(aksRbacClusterAdminRoleDefinitionId, principalId, managedCluster.id)
  scope: managedCluster
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', aksRbacClusterAdminRoleDefinitionId)
  }
}

output name string = managedCluster.name
output issuerUrl string = managedCluster.properties.oidcIssuerProfile.issuerURL
output fqdn string = managedCluster.properties.fqdn
