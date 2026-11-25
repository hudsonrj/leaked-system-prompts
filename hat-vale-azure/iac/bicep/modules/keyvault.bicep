// =============================================================================
// keyvault.bicep — Key Vault RBAC-only, acesso público desabilitado
// Segredos esperados (criados fora do IaC): devops-pat (ou SP), btp-is-oauth,
// leanix-api-token, graph-client-secret (se não usar certificado), tls-appgw.
// =============================================================================
param location string
param name string
param tags object
param tenantId string = subscription().tenantId
param softDeleteRetentionInDays int = 90
param purgeProtection bool = true

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: purgeProtection ? true : null
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny', bypass: 'AzureServices' }
  }
}

output id string = kv.id
output name string = kv.name
output uri string = kv.properties.vaultUri
