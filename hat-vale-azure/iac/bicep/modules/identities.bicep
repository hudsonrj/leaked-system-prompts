// =============================================================================
// identities.bicep — Managed Identities por serviço (slide "Identidades de
// leitura e gravação": id-cdi-artef, id-cdi-ingest, id-cdi-mcp, id-cdi-valid)
// + identidades de runtime/orquestrador, gateway LLM, bot e app gateway.
// =============================================================================
param location string
param tags object
param envName string

var names = [
  'artef'   // serviço de artefatos — publica entregáveis aprovados
  'ingest'  // jobs de ingestão (código, docs, LeanIX)
  'mcp'     // servidor MCP de conhecimento — leitura com filtro de grupos
  'valid'   // validadores determinísticos — leitura
  'orch'    // runtime + orquestrador (Durable Task) — chama Foundry/Agent Service
  'gw'      // gateway LLM — único caller dos deployments de modelo
  'bot'     // Azure Bot (UserAssignedMSI)
  'appgw'   // Application Gateway — lê certificado TLS no Key Vault
]

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [for n in names: {
  name: 'id-cdi-${n}-${envName}'
  location: location
  tags: tags
}]

output ids object = toObject(range(0, length(names)), i => names[i], i => {
  id: uami[i].id
  principalId: uami[i].properties.principalId
  clientId: uami[i].properties.clientId
  name: uami[i].name
})
