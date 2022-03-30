param dnsZoneId string
param cnameRecordName string
param hostName string
param validationToken string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: last(split(dnsZoneId, '/'))
}

resource cnameRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: dnsZone
  name: cnameRecordName
  properties: {
    TTL: 60
    CNAMERecord: {
      cname: hostName
    }
  }
}

resource validationTxtRecord 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  parent: dnsZone
  name: '_dnsauth'
  properties: {
    TTL: 60
    TXTRecords: [
      {
        value: [
          validationToken
        ]
      }
    ]
  }
}
