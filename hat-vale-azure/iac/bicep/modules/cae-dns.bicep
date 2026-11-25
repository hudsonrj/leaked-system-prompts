// =============================================================================
// cae-dns.bicep — DNS privado do Container Apps Environment interno
// (zona = defaultDomain, registro * -> staticIp). Somente HAT; na Vale o time de
// DNS do hub cria a zona/registro (item da solicitação de rede).
// Mesmo padrão para o APIM interno (zona azure-api.net).
// =============================================================================
param vnetId string
param tags object
param caeDefaultDomain string
param caeStaticIp string
param apimName string
param apimPrivateIp string

resource zCae 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: caeDefaultDomain
  location: 'global'
  tags: tags
}

resource zCaeA 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: zCae
  name: '*'
  properties: { ttl: 300, aRecords: [ { ipv4Address: caeStaticIp } ] }
}

resource zCaeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: zCae
  name: 'link-cae'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: vnetId } }
}

resource zApim 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'azure-api.net'
  location: 'global'
  tags: tags
}

resource zApimRecords 'Microsoft.Network/privateDnsZones/A@2024-06-01' = [for suffix in [ '', '.portal', '.developer', '.management', '.scm' ]: {
  parent: zApim
  name: '${apimName}${suffix}'
  properties: { ttl: 300, aRecords: [ { ipv4Address: apimPrivateIp } ] }
}]

resource zApimLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: zApim
  name: 'link-apim'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: vnetId } }
}
