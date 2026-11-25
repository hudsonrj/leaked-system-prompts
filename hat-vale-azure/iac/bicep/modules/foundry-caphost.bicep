// =============================================================================
// foundry-caphost.bicep — Capability Host do Agent Service (standard setup)
// Deve rodar DEPOIS das role assignments da identidade do projeto em
// Cosmos / Storage / Search (ver rbac.bicep). Depois do caphost, aplicar as
// permissões de data plane no Cosmos (script 02-post-deploy.sh).
// =============================================================================
param accountName string
param projectName string
param cosmosConnection string
param storageConnection string
param searchConnection string

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' existing = {
  parent: account
  name: projectName
}

resource caphost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-06-01' = {
  parent: project
  name: 'caphost-agents'
  properties: {
    capabilityHostKind: 'Agents'
    vectorStoreConnections: [ searchConnection ]
    storageConnections: [ storageConnection ]
    threadStorageConnections: [ cosmosConnection ]
  }
}
