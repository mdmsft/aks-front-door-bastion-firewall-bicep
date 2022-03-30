param resourceSuffix string
param location string
param addressPrefix string

var subnetAddressPrefix = replace(addressPrefix, '/22', '/24')

resource systemNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${resourceSuffix}-aks-system'
  location: location
}

resource userNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${resourceSuffix}-aks-user'
  location: location
}

resource routeTable 'Microsoft.Network/routeTables@2021-05-01' = {
  name: 'rt-${resourceSuffix}'
  location: location
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-${resourceSuffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: subnetAddressPrefix
        }
      }
      {
        name: 'snet-aks-sys'
        properties: {
          addressPrefix: replace(subnetAddressPrefix, '.0.', '.1.')
          networkSecurityGroup: {
            id: systemNetworkSecurityGroup.id
          }
          routeTable: {
            id: routeTable.id
          }
        }
      }
      {
        name: 'snet-aks-usr'
        properties: {
          addressPrefix: replace(subnetAddressPrefix, '.0.', '.2.')
          networkSecurityGroup: {
            id: userNetworkSecurityGroup.id
          }
          routeTable: {
            id: routeTable.id
          }
        }
      }
    ]
  }
}

output id string = virtualNetwork.id
output firewallSubnetId string = virtualNetwork.properties.subnets[0].id
output systemNodePoolSubnetId string = virtualNetwork.properties.subnets[1].id
output userNodePoolSubnetId string = virtualNetwork.properties.subnets[2].id
output systemNodePoolSubnetAddressPrefix string = virtualNetwork.properties.subnets[1].properties.addressPrefix
output userNodePoolSubnetAddressPrefix string = virtualNetwork.properties.subnets[2].properties.addressPrefix
output routeTableId string = routeTable.id
