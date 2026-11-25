// =============================================================================
// private-endpoint.bicep — Private Endpoint genérico + registro no DNS privado
// Se `dnsZoneIds` vier vazio (caso Vale com Azure Policy DINE no hub), o
// registro DNS é feito pela policy corporativa e o zoneGroup não é criado.
// =============================================================================
param name string
param location string
param tags object
param subnetId string
param targetResourceId string
param groupId string
param dnsZoneIds array = []

resource pe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    customNetworkInterfaceName: 'nic-${name}'
    privateLinkServiceConnections: [
      {
        name: '${name}-conn'
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: [ groupId ]
        }
      }
    ]
  }
}

resource zg 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(dnsZoneIds)) {
  parent: pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [for (id, i) in dnsZoneIds: {
      name: 'cfg-${i}'
      properties: { privateDnsZoneId: id }
    }]
  }
}

output id string = pe.id
