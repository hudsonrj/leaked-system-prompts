// =============================================================================
// foundry.bicep — Microsoft Foundry (AIServices) + projeto + deployments de modelo
// + Agent Service "standard setup" (Cosmos, Storage e AI Search do próprio cliente)
// com injeção de rede (snet-aiagents) e acesso público desabilitado.
// Baseado no padrão "private network standard agent setup" da Microsoft.
// ATENÇÃO: confirmar api-version e disponibilidade regional dos modelos em
// Brazil South (SKU Standard regional — exigência de residência de dados).
// =============================================================================
param location string
param accountName string
param projectName string
param tags object
param agentSubnetId string
param modelDeployments array
param cosmosId string
param cosmosEndpoint string
param agentStorageId string
param agentStorageBlobEndpoint string
param searchId string
param searchEndpoint string
param appInsightsId string
param appInsightsConnectionString string

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: accountName
    allowProjectManagement: true
    disableLocalAuth: true
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny', virtualNetworkRules: [], ipRules: [] }
    networkInjections: [
      {
        scenario: 'agent'
        subnetArmId: agentSubnetId
        useMicrosoftManagedNetwork: false
      }
    ]
  }
}

@batchSize(1)
resource deployments 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = [for d in modelDeployments: {
  parent: account
  name: d.name
  sku: { name: d.skuName, capacity: d.capacity }
  properties: {
    model: { format: 'OpenAI', name: d.model, version: d.version }
    raiPolicyName: 'Microsoft.DefaultV2'   // inclui Prompt Shields (jailbreak/indirect attacks)
    versionUpgradeOption: 'NoAutoUpgrade'
  }
}]

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: account
  name: projectName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: projectName
    description: 'Core Data Integration — agentes A1..A4 + revisor'
  }
}

// ---------- Conexões do projeto (Entra ID / AAD) ----------
resource connCosmos 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: project
  name: 'conn-cosmos'
  properties: {
    category: 'CosmosDB'
    target: cosmosEndpoint
    authType: 'AAD'
    metadata: { ApiType: 'Azure', ResourceId: cosmosId, location: location }
  }
}

resource connStorage 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: project
  name: 'conn-storage'
  properties: {
    category: 'AzureStorageAccount'
    target: agentStorageBlobEndpoint
    authType: 'AAD'
    metadata: { ApiType: 'Azure', ResourceId: agentStorageId, location: location }
  }
}

resource connSearch 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: project
  name: 'conn-search'
  properties: {
    category: 'CognitiveSearch'
    target: searchEndpoint
    authType: 'AAD'
    metadata: { ApiType: 'Azure', ResourceId: searchId, location: location }
  }
}

resource connAppi 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: project
  name: 'conn-appinsights'
  properties: {
    category: 'AppInsights'
    target: appInsightsId
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: { key: appInsightsConnectionString }
    metadata: { ApiType: 'Azure', ResourceId: appInsightsId }
  }
}

output accountId string = account.id
output accountName string = account.name
output accountPrincipalId string = account.identity.principalId
output projectId string = project.id
output projectName string = project.name
output projectPrincipalId string = project.identity.principalId
output projectWorkspaceId string = project.properties.internalId
output endpoint string = 'https://${accountName}.services.ai.azure.com/api/projects/${projectName}'
output connectionNames object = {
  cosmos: connCosmos.name
  storage: connStorage.name
  search: connSearch.name
}
