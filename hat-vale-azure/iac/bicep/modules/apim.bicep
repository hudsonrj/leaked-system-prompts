// =============================================================================
// apim.bicep — API Management em modo VNet INTERNO (snet-apim /27)
// Entrada única do MCP, do gateway LLM e do /api/messages do Bot.
// Políticas (validate-jwt, rate-limit por agente/x-demanda, métricas de tokens)
// ficam em iac/bicep/apim-policies/*.xml e são aplicadas aqui.
// HAT: SKU Developer (sem SLA). Vale: Premium (SLA/zonas) — decisão de custo.
// =============================================================================
param location string
param name string
param tags object
param subnetId string
param publisherEmail string
param publisherName string
@allowed([ 'Developer', 'Premium' ])
param skuName string = 'Developer'
param skuCapacity int = 1
param appInsightsId string
@secure()
param appInsightsConnectionString string
param tenantId string = subscription().tenantId
@description('App ID URI / client id da API registrada no Entra (audiência dos tokens)')
param apiAudience string
param mcpBackendUrl string
param gatewayBackendUrl string
param runtimeBackendUrl string
@description('clientId da identidade do Bot (id-cdi-bot)')
param botAppId string

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: skuName, capacity: skuCapacity }
  identity: { type: 'SystemAssigned' }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: { subnetResourceId: subnetId }
    publicNetworkAccess: 'Enabled' // exigido na criação em modo Internal; o tráfego de dados permanece privado
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
    }
  }
}

resource logger 'Microsoft.ApiManagement/service/loggers@2024-05-01' = {
  parent: apim
  name: 'appi'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: appInsightsId
    credentials: { connectionString: appInsightsConnectionString }
  }
}

resource nvTenant 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'tenant-id'
  properties: { displayName: 'tenant-id', value: tenantId }
}

resource nvBot 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'bot-app-id'
  properties: { displayName: 'bot-app-id', value: botAppId }
}

resource nvAudience 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'api-audience'
  properties: { displayName: 'api-audience', value: apiAudience }
}

// ---------- API: MCP de conhecimento ----------
resource apiMcp 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'mcp-conhecimento'
  properties: {
    displayName: 'MCP de conhecimento'
    path: 'mcp'
    protocols: [ 'https' ]
    serviceUrl: mcpBackendUrl
    subscriptionRequired: false
  }
}

resource apiMcpOps 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: apiMcp
  name: 'mcp-all'
  properties: {
    displayName: 'MCP (streamable HTTP)'
    method: '*'
    urlTemplate: '/*'
  }
}

resource apiMcpPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: apiMcp
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../apim-policies/mcp.xml')
  }
  dependsOn: [ nvTenant, nvAudience ]
}

// ---------- API: Gateway LLM (embeddings/chat via deployments do Foundry) ----------
resource apiLlm 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'gateway-llm'
  properties: {
    displayName: 'Gateway LLM'
    path: 'llm'
    protocols: [ 'https' ]
    serviceUrl: gatewayBackendUrl
    subscriptionRequired: false
  }
}

resource apiLlmOps 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: apiLlm
  name: 'llm-all'
  properties: {
    displayName: 'LLM proxy'
    method: '*'
    urlTemplate: '/*'
  }
}

resource apiLlmPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: apiLlm
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../apim-policies/llm.xml')
  }
  dependsOn: [ nvTenant, nvAudience ]
}

// ---------- API: Bot (/api/messages) ----------
resource apiBot 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'bot'
  properties: {
    displayName: 'Bot Framework messages'
    path: 'bot'
    protocols: [ 'https' ]
    serviceUrl: runtimeBackendUrl
    subscriptionRequired: false
  }
}

resource apiBotOps 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: apiBot
  name: 'messages'
  properties: {
    displayName: 'POST /api/messages'
    method: 'POST'
    urlTemplate: '/api/messages'
  }
}

resource apiBotPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: apiBot
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../apim-policies/bot.xml')
  }
  dependsOn: [ nvBot ]
}

resource diag 'Microsoft.ApiManagement/service/diagnostics@2024-05-01' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerId: logger.id
    alwaysLog: 'allErrors'
    sampling: { samplingType: 'fixed', percentage: 100 }
    metrics: true
  }
}

output id string = apim.id
output name string = apim.name
output privateIp string = apim.properties.privateIPAddresses[0]
output gatewayHost string = '${apim.name}.azure-api.net'
output principalId string = apim.identity.principalId
