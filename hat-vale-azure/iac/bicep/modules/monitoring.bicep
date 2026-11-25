// =============================================================================
// monitoring.bicep — Log Analytics + Application Insights (tracing dos agentes)
// =============================================================================
param location string
param namePrefix string
param tags object
@description('Na Vale, pode ser o workspace central. Se informado, não cria um novo.')
param existingWorkspaceId string = ''
param retentionDays int = 30

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (empty(existingWorkspaceId)) {
  name: 'log-${namePrefix}'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: retentionDays
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
  }
}

var workspaceId = empty(existingWorkspaceId) ? law.id : existingWorkspaceId

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${namePrefix}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceId
    DisableLocalAuth: false // App Insights SDK/OTel com connection string; avaliar Entra-only na Vale
  }
}

output workspaceId string = workspaceId
output appInsightsId string = appi.id
output appInsightsConnectionString string = appi.properties.ConnectionString
