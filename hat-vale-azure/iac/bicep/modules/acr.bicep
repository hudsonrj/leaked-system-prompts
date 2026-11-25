// =============================================================================
// acr.bicep — Azure Container Registry Premium (Private Endpoint)
// Imagens: app-integia-mcp, app-integia-gateway, app-integia-runtime, jobs
// =============================================================================
param location string
param name string
param tags object

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Enabled'
    policies: {
      retentionPolicy: { status: 'enabled', days: 30 }
    }
  }
}

output id string = acr.id
output name string = acr.name
output loginServer string = acr.properties.loginServer
