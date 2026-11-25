// =============================================================================
// rbac.bicep — Matriz de acesso (menor privilégio) — ver docs/04-matriz-identidades-rbac.md
// Somente roles built-in com GUID fixo. Roles de data plane que dependem de
// recursos em preview (Durable Task) e do Cosmos (sqlRoleAssignments) ficam no
// script 02-post-deploy.sh.
// =============================================================================
param identities object
param lakeName string
param agentStorageName string
param searchName string
param keyVaultName string
param acrName string
param serviceBusName string
param foundryAccountName string
param foundryProjectPrincipalId string
param cosmosName string
param docIntelName string
@description('Grupo Entra do time de engenharia (HAT ou Vale) — acesso de operação')
param engineeringGroupObjectId string

var role = {
  blobContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  blobReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  blobOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  searchIndexContributor: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  searchIndexReader: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  searchServiceContributor: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  kvSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  kvSecretsOfficer: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  acrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
  sbReceiver: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  sbSender: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
  openAiUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  cogServicesUser: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  azureAiUser: '53ca6127-db72-4b80-b1b0-d745d6d5456d'
  cosmosOperator: '230815da-be43-4aae-9cb4-875f7bd000aa'
  reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

// ---------- recursos existentes ----------
resource lake 'Microsoft.Storage/storageAccounts@2023-05-01' existing = { name: lakeName }
resource lakeBlob 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = { parent: lake, name: 'default' }
resource cRaw 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = { parent: lakeBlob, name: 'raw' }
resource cGold 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = { parent: lakeBlob, name: 'gold' }
resource cEntreg 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = { parent: lakeBlob, name: 'entregaveis' }
resource agentSt 'Microsoft.Storage/storageAccounts@2023-05-01' existing = { name: agentStorageName }
resource srch 'Microsoft.Search/searchServices@2023-11-01' existing = { name: searchName }
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: keyVaultName }
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = { name: acrName }
resource sb 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = { name: serviceBusName }
resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = { name: foundryAccountName }
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = { name: cosmosName }
resource di 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = { name: docIntelName }

// ---------- Data Lake (escopo de container) ----------
resource raIngestRaw 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cRaw
  name: guid(cRaw.id, identities.ingest.principalId, role.blobContributor)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.blobContributor), principalId: identities.ingest.principalId, principalType: 'ServicePrincipal' }
}
resource raIngestGold 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cGold
  name: guid(cGold.id, identities.ingest.principalId, role.blobContributor)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.blobContributor), principalId: identities.ingest.principalId, principalType: 'ServicePrincipal' }
}
resource raArtefEntreg 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cEntreg
  name: guid(cEntreg.id, identities.artef.principalId, role.blobContributor)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.blobContributor), principalId: identities.artef.principalId, principalType: 'ServicePrincipal' }
}
resource raArtefGold 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cGold
  name: guid(cGold.id, identities.artef.principalId, role.blobReader)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.blobReader), principalId: identities.artef.principalId, principalType: 'ServicePrincipal' }
}
resource raMcpGold 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cGold
  name: guid(cGold.id, identities.mcp.principalId, role.blobReader)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.blobReader), principalId: identities.mcp.principalId, principalType: 'ServicePrincipal' }
}
resource raValidGold 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cGold
  name: guid(cGold.id, identities.valid.principalId, role.blobReader)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.blobReader), principalId: identities.valid.principalId, principalType: 'ServicePrincipal' }
}
resource raValidEntreg 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cEntreg
  name: guid(cEntreg.id, identities.valid.principalId, role.blobReader)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.blobReader), principalId: identities.valid.principalId, principalType: 'ServicePrincipal' }
}

// ---------- AI Search ----------
resource raSearchIngest 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: srch
  name: guid(srch.id, identities.ingest.principalId, role.searchIndexContributor)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.searchIndexContributor), principalId: identities.ingest.principalId, principalType: 'ServicePrincipal' }
}
resource raSearchMcp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: srch
  name: guid(srch.id, identities.mcp.principalId, role.searchIndexReader)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.searchIndexReader), principalId: identities.mcp.principalId, principalType: 'ServicePrincipal' }
}
resource raSearchValid 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: srch
  name: guid(srch.id, identities.valid.principalId, role.searchIndexReader)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.searchIndexReader), principalId: identities.valid.principalId, principalType: 'ServicePrincipal' }
}

// ---------- Key Vault ----------
var kvReaders = [ 'ingest', 'artef', 'mcp', 'orch', 'gw', 'appgw' ]
resource raKv 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for k in kvReaders: {
  scope: kv
  name: guid(kv.id, identities[k].principalId, role.kvSecretsUser)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.kvSecretsUser), principalId: identities[k].principalId, principalType: 'ServicePrincipal' }
}]

// ---------- ACR (pull para todas as cargas) ----------
var acrPullers = [ 'ingest', 'artef', 'mcp', 'valid', 'orch', 'gw' ]
resource raAcr 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for k in acrPullers: {
  scope: acr
  name: guid(acr.id, identities[k].principalId, role.acrPull)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.acrPull), principalId: identities[k].principalId, principalType: 'ServicePrincipal' }
}]

// ---------- Service Bus ----------
resource raSbIngest 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: sb
  name: guid(sb.id, identities.ingest.principalId, role.sbReceiver)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.sbReceiver), principalId: identities.ingest.principalId, principalType: 'ServicePrincipal' }
}
resource raSbIngestSend 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: sb
  name: guid(sb.id, identities.ingest.principalId, role.sbSender)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.sbSender), principalId: identities.ingest.principalId, principalType: 'ServicePrincipal' }
}
resource raSbOrch 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: sb
  name: guid(sb.id, identities.orch.principalId, role.sbSender)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.sbSender), principalId: identities.orch.principalId, principalType: 'ServicePrincipal' }
}

// ---------- Foundry ----------
// Gateway LLM é o único caller dos deployments (mascaramento antes do modelo)
resource raFoundryGw 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: foundry
  name: guid(foundry.id, identities.gw.principalId, role.openAiUser)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.openAiUser), principalId: identities.gw.principalId, principalType: 'ServicePrincipal' }
}
// Orquestrador cria/roda agentes no Agent Service
resource raFoundryOrch 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: foundry
  name: guid(foundry.id, identities.orch.principalId, role.azureAiUser)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.azureAiUser), principalId: identities.orch.principalId, principalType: 'ServicePrincipal' }
}
resource raFoundryEng 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: foundry
  name: guid(foundry.id, engineeringGroupObjectId, role.azureAiUser)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.azureAiUser), principalId: engineeringGroupObjectId, principalType: 'Group' }
}
// Document Intelligence (conversão prebuilt-layout) para a ingestão
resource raDiIngest 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: di
  name: guid(di.id, identities.ingest.principalId, role.cogServicesUser)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.cogServicesUser), principalId: identities.ingest.principalId, principalType: 'ServicePrincipal' }
}

// ---------- Identidade do PROJETO Foundry (standard agent setup) ----------
resource raProjCosmos 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cosmos
  name: guid(cosmos.id, foundryProjectPrincipalId, role.cosmosOperator)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.cosmosOperator), principalId: foundryProjectPrincipalId, principalType: 'ServicePrincipal' }
}
resource raProjSt 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: agentSt
  name: guid(agentSt.id, foundryProjectPrincipalId, role.blobContributor)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.blobContributor), principalId: foundryProjectPrincipalId, principalType: 'ServicePrincipal' }
}
resource raProjSearchIdx 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: srch
  name: guid(srch.id, foundryProjectPrincipalId, role.searchIndexContributor)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.searchIndexContributor), principalId: foundryProjectPrincipalId, principalType: 'ServicePrincipal' }
}
resource raProjSearchSvc 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: srch
  name: guid(srch.id, foundryProjectPrincipalId, role.searchServiceContributor)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.searchServiceContributor), principalId: foundryProjectPrincipalId, principalType: 'ServicePrincipal' }
}

// ---------- Grupo de engenharia (operação; sem Owner) ----------
resource raEngKv 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(kv.id, engineeringGroupObjectId, role.kvSecretsOfficer)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.kvSecretsOfficer), principalId: engineeringGroupObjectId, principalType: 'Group' }
}
resource raEngAcr 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, engineeringGroupObjectId, role.acrPush)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.acrPush), principalId: engineeringGroupObjectId, principalType: 'Group' }
}
resource raEngSearch 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: srch
  name: guid(srch.id, engineeringGroupObjectId, role.searchServiceContributor)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.searchServiceContributor), principalId: engineeringGroupObjectId, principalType: 'Group' }
}
resource raEngSearchIdx 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: srch
  name: guid(srch.id, engineeringGroupObjectId, role.searchIndexContributor)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.searchIndexContributor), principalId: engineeringGroupObjectId, principalType: 'Group' }
}
resource raEngLake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: lake
  name: guid(lake.id, engineeringGroupObjectId, role.blobReader)
  properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.blobReader), principalId: engineeringGroupObjectId, principalType: 'Group' }
}
