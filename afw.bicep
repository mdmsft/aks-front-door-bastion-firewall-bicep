param subnetId string
param resourceSuffix string
param logAnalyticsWorkspaceId string
param availabilityZones array
param location string = resourceGroup().location
param internalLoadBalancerIpAddress string

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2021-03-01' = {
  name: 'afwp-${resourceSuffix}'
  location: location
  properties: {
    threatIntelMode: 'Deny'
    dnsSettings: {
      enableProxy: true
    }
    sku: {
      tier: 'Standard'
    }
    insights: {
      isEnabled: true
      retentionDays: 7
      logAnalyticsResources: {
        defaultWorkspaceId: {
          id: logAnalyticsWorkspaceId
        }
        workspaces: [
          {
            region: location
            workspaceId: {
              id: logAnalyticsWorkspaceId
            }
          }
        ]
      }
    }
  }

  resource ruleCollectionGroup 'ruleCollectionGroups' = {
    name: 'default'
    properties: {
      priority: 100
      ruleCollections: [
        {
          ruleCollectionType: 'FirewallPolicyNatRuleCollection'
          action: {
            type: 'DNAT'
          }
          name: 'nat'
          priority: 100
          rules: [
            {
              ruleType: 'NatRule'
              name: 'nginx'
              ipProtocols: [
                'TCP'
              ]
              destinationAddresses: [
                firewallPublicIpAddress.properties.ipAddress
              ]
              destinationPorts: [
                '80'
              ]
              sourceAddresses: [
                '*'
              ]
              translatedAddress: internalLoadBalancerIpAddress
              translatedPort: '80'
            }
          ]
        }
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'net'
          priority: 200
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'azure'
              ruleType: 'NetworkRule'
              ipProtocols: [
                'Any'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                'AzureMonitor'
                'AzureContainerRegistry'
                'MicrosoftContainerRegistry'
                'AzureActiveDirectory'
              ]
              destinationPorts: [
                '*'
              ]
            }
            {
              name: 'ntp'
              ruleType: 'NetworkRule'
              ipProtocols: [
                'UDP'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '123'
              ]
            }
          ]
        }
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'app'
          priority: 300
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'aks'
              sourceAddresses: [
                '*'
              ]
              targetFqdns: [
                '*.hcp.${location}.azmk8s.io'
                'mcr.microsoft.com'
                '*.data.mcr.microsoft.com'
                'management.azure.com'
                'login.microsoftonline.com'
                'packages.microsoft.com'
                'acs-mirror.azureedge.net'
                '*.ods.opinsights.azure.com'
                '*.oms.opinsights.azure.com'
                'dc.services.visualstudio.com'
                '*.monitoring.azure.com'
                'data.policy.core.windows.net'
                'store.policy.core.windows.net'
                '${location}.dp.kubernetesconfiguration.azure.com'
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'ubuntu'
              sourceAddresses: [
                '*'
              ]
              targetFqdns: [
                'archive.ubuntu.com'
                'security.ubuntu.com'
                'changelogs.ubuntu.com'
                'azure.archive.ubuntu.com'
                'motd.ubuntu.com'
              ]
              protocols: [
                {
                  protocolType: 'Http'
                  port: 80
                }
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'registry'
              sourceAddresses: [
                '*'
              ]
              targetFqdns: [
                'k8s.gcr.io'
                'storage.googleapis.com'
                'auth.docker.io'
                'registry-1.docker.io'
                'production.cloudflare.docker.com'
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
            }
          ]
        }
      ]
    }
  }
}

resource firewallPublicIpAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'pip-${resourceSuffix}-afw'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: replace(resourceSuffix, '-${location}', '')
    }
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2021-03-01' = {
  name: 'afw-${resourceSuffix}'
  location: location
  zones: availabilityZones
  properties: {
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: firewallPublicIpAddress.id
          }
        }
      }
    ]
  }
}

var logCategories = [
  'AzureFirewallApplicationRule'
  'AzureFirewallNetworkRule'
  'AzureFirewallDnsProxy'
]

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: firewall
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [for log in logCategories: {
      enabled: true
      category: log
    }]
  }
}

output publicIpAddress string = firewallPublicIpAddress.properties.ipAddress
output privateIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output policyId string = firewallPolicy.id
output policyName string = firewallPolicy.name
output publicIpAddressId string = firewallPublicIpAddress.id
