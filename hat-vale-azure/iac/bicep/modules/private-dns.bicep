// =============================================================================
// private-dns.bicep — Zonas DNS privadas + links com a VNet
// HAT (lab): criamos as zonas no próprio RG.
// Vale: NÃO usar — o DNS privado é resolvido pelo hub corporativo (slide 26).
//       Informe os IDs das zonas do hub em `existingZoneIds` no main.bicep.
// =============================================================================
param vnetId string
param tags object
param zones array

resource zone 'Microsoft.Network/privateDnsZones@2024-06-01' = [for z in zones: {
  name: z
  location: 'global'
  tags: tags
}]

resource link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (z, i) in zones: {
  parent: zone[i]
  name: 'link-${uniqueString(vnetId)}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnetId }
  }
}]

output zoneIds object = toObject(zones, z => z, z => resourceId('Microsoft.Network/privateDnsZones', z))
