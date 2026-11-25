// =============================================================================
// storage.bicep — ADLS Gen2 (Blob + HNS). Usado para:
//   - Data Lake de conhecimento: containers raw / gold / entregaveis
//   - Storage do Foundry Agent Service (standard setup): sem HNS
// =============================================================================
param location string
param name string
param tags object
param isHnsEnabled bool = true
param containers array = []
@allowed([ 'Standard_LRS', 'Standard_ZRS', 'Standard_GRS' ])
param skuName string = 'Standard_ZRS'

resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: skuName }
  properties: {
    isHnsEnabled: isHnsEnabled
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false          // somente Entra ID
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny', bypass: 'AzureServices' }
  }
}

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: st
  name: 'default'
  properties: {
    // Versionamento não é suportado com HNS; usamos soft delete + versões no registro (PostgreSQL)
    deleteRetentionPolicy: { enabled: true, days: 14 }
    containerDeleteRetentionPolicy: { enabled: true, days: 14 }
  }
}

resource cont 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for c in containers: {
  parent: blob
  name: c
  properties: { publicAccess: 'None' }
}]

output id string = st.id
output name string = st.name
output dfsEndpoint string = st.properties.primaryEndpoints.dfs
output blobEndpoint string = st.properties.primaryEndpoints.blob
