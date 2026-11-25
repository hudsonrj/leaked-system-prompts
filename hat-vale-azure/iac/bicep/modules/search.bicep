// =============================================================================
// search.bicep — Azure AI Search (idx-codigo, idx-docs, idx-leanix)
// Índices são criados por script (iac/search/*.json) via data plane.
// Busca híbrida BM25 + vetores + semantic ranker (slides 13, 15, 16).
// =============================================================================
param location string
param name string
param tags object
@allowed([ 'basic', 'standard', 'standard2' ])
param sku string = 'standard'
param replicaCount int = 1
param partitionCount int = 1

resource srch 'Microsoft.Search/searchServices@2023-11-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: sku }
  identity: { type: 'SystemAssigned' }
  properties: {
    replicaCount: replicaCount
    partitionCount: partitionCount
    hostingMode: 'default'
    publicNetworkAccess: 'disabled'
    disableLocalAuth: true            // somente Entra ID (RBAC)
    semanticSearch: 'standard'
    networkRuleSet: { ipRules: [] }
  }
}

output id string = srch.id
output name string = srch.name
output endpoint string = 'https://${srch.name}.search.windows.net'
output principalId string = srch.identity.principalId
