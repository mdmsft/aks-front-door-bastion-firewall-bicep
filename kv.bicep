param resourceSuffix string
param location string
param principalId string
param frontDoorPrincipalId string
param secretName string

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: take('kv-${replace(resourceSuffix, location, uniqueString(location))}', 24)
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: false
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        permissions: {
          certificates: [
            'all'
          ]
          keys: [
            'all'
          ]
          secrets: [
            'all'
          ]
        }
        objectId: principalId
      }
      {
        tenantId: subscription().tenantId
        permissions: {
          certificates: [
            'get'
          ]
          secrets: [
            'get'
          ]
        }
        objectId: frontDoorPrincipalId
      }
    ]
  }

  resource secret 'secrets' = {
    name: secretName
    properties: {
      contentType: 'application/x-pkcs12'
      value: loadFileAsBase64('./certificate.pfx')
    }
  }
}

output id string = keyVault.id
output secretId string = keyVault::secret.id
