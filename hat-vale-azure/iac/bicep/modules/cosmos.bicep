// =============================================================================
// cosmos.bicep — Cosmos DB for NoSQL (threads/execuções do Foundry Agent Service
// no "standard setup"). Não guarda conhecimento de negócio (slide 12).
// =============================================================================
param location string
param name string
param tags object
param serverless bool = true

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: name
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [ { locationName: location, failoverPriority: 0, isZoneRedundant: !serverless } ]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    capabilities: serverless ? [ { name: 'EnableServerless' } ] : []
    disableLocalAuth: true
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: 'Tls12'
    disableKeyBasedMetadataWriteAccess: true
  }
}

output id string = cosmos.id
output name string = cosmos.name
output endpoint string = cosmos.properties.documentEndpoint
