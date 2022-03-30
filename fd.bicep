param resourceSuffix string
param keyVaultSecretId string
param dnsZoneId string
param publicIpAddressId string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  scope: resourceGroup(split(dnsZoneId, '/')[4])
  name: last(split(dnsZoneId, '/'))
}

var secretName = last(split(keyVaultSecretId, '/'))

var hostname = '*.${dnsZone.name}'

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2021-05-01' existing = {
  scope: resourceGroup(split(publicIpAddressId, '/')[4])
  name: last(split(publicIpAddressId, '/'))
}

module dns 'dns.bicep' = {
  name: '${deployment().name}-dns'
  scope: resourceGroup(split(dnsZoneId, '/')[4])
  params: {
    cnameRecordName: first(split(hostname, '.'))
    dnsZoneId: dnsZoneId
    hostName: profile::endpoint.properties.hostName
    validationToken: profile::customDomain.properties.validationProperties.validationToken
  }
}

resource profile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: 'cdnp-${resourceSuffix}'
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }

  resource endpoint 'afdEndpoints' = {
    name: resourceSuffix
    location: 'global'
    properties: {
      enabledState: 'Enabled'
    }

    resource route 'routes' = {
      name: 'default'
      dependsOn: [
        profile::originGroup::origin
      ]
      properties: {
        customDomains: [
          {
            id: profile::customDomain.id
          }
        ]
        enabledState: 'Enabled'
        forwardingProtocol: 'HttpOnly'
        httpsRedirect: 'Enabled'
        linkToDefaultDomain: 'Enabled'
        originGroup: {
          id: profile::originGroup.id
        }
        patternsToMatch: [
          '/*'
        ]
        supportedProtocols: [
          'Http'
          'Https'
        ]
      }
    }
  }

  resource originGroup 'originGroups' = {
    name: 'default'
    properties: {
      healthProbeSettings: {
        probeIntervalInSeconds: 30
        probePath: '/'
        probeProtocol: 'Http'
        probeRequestType: 'HEAD'
      }
      sessionAffinityState: 'Disabled'
      loadBalancingSettings: {
        sampleSize: 4
        successfulSamplesRequired: 2
      }
    }

    resource origin 'origins' = {
      name: 'ingress'
      properties: {
        hostName: publicIpAddress.properties.dnsSettings.fqdn
        enabledState: 'Enabled'
        httpPort: 80
        priority: 1
        weight: 1000
      }
    }
  }

  resource secret 'secrets' = {
    name: secretName
    properties: {
      parameters: {
        type: 'CustomerCertificate'
        secretSource: {
          id: keyVaultSecretId
        }
        useLatestVersion: true
      }
    }
  }

  resource customDomain 'customDomains' = {
    name: replace(dnsZone.name, '.', '-')
    properties: {
      hostName: hostname
      azureDnsZone: {
        id: dnsZone.id
      }
      tlsSettings: {
        certificateType: 'CustomerCertificate'
        minimumTlsVersion: 'TLS12'
        secret: {
          id: profile::secret.id
        }
      }
    }
  }
}

