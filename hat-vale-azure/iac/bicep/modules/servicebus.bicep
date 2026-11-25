// =============================================================================
// servicebus.bicep — Service Bus Premium (exigido para Private Endpoint)
// Filas: eventos de ingestão (DevOps pós-merge, SharePoint delta, BTP) e avaliação
// =============================================================================
param location string
param name string
param tags object
param capacity int = 1
param queues array = [ 'ingest-codigo', 'ingest-docs', 'ingest-leanix', 'avaliacao', 'ingest-eventos-finais' ]

resource sb 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: 'Premium', tier: 'Premium', capacity: capacity }
  properties: {
    disableLocalAuth: true
    publicNetworkAccess: 'Disabled'
    minimumTlsVersion: '1.2'
    zoneRedundant: true
  }
}

resource q 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = [for n in queues: {
  parent: sb
  name: n
  properties: {
    maxDeliveryCount: 5
    lockDuration: 'PT5M'
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P7D'
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT30M'
  }
}]

output id string = sb.id
output name string = sb.name
output fqdn string = '${sb.name}.servicebus.windows.net'
