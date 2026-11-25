// =============================================================================
// durabletask.bicep — Durable Task Scheduler (orquestração durável A2/A3/A4 com
// esperas por validação humana — slide 18 item 17).
// ATENÇÃO: confirmar a api-version GA vigente e o suporte a Private Endpoint na
// região Brazil South antes do deploy na Vale (`az provider show -n Microsoft.DurableTask`).
// =============================================================================
param location string
param name string
param tags object
@allowed([ 'Consumption', 'Dedicated' ])
param skuName string = 'Consumption'

resource dts 'Microsoft.DurableTask/schedulers@2025-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    ipAllowlist: [ '0.0.0.0/0' ] // restringir; preferir Private Endpoint quando disponível na região
    sku: { name: skuName }
  }
}

resource hub 'Microsoft.DurableTask/schedulers/taskHubs@2025-11-01' = {
  parent: dts
  name: 'cdi'
  properties: {}
}

output id string = dts.id
output endpoint string = dts.properties.endpoint
output taskHub string = hub.name
