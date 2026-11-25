// =============================================================================
// postgres.bicep — PostgreSQL Flexible Server (registro, controle e grafo AGE)
// VNet-integrado na snet-psql (delegada) — slide 26 "snet-psql /28 · delegada".
// Autenticação somente Entra ID. Extensão Apache AGE habilitada.
// =============================================================================
param location string
param name string
param tags object
param delegatedSubnetId string
@description('Zona DNS privada <algo>.private.postgres.database.azure.com (HAT: criada aqui; Vale: do hub)')
param privateDnsZoneId string
param entraAdminObjectId string
param entraAdminName string
@allowed([ 'User', 'Group', 'ServicePrincipal' ])
param entraAdminType string = 'Group'
param skuName string = 'Standard_D2ds_v5'
@allowed([ 'Burstable', 'GeneralPurpose', 'MemoryOptimized' ])
param skuTier string = 'GeneralPurpose'
param storageSizeGB int = 64
param highAvailability bool = false
param version string = '16'

resource psql 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: skuName, tier: skuTier }
  properties: {
    version: version
    storage: { storageSizeGB: storageSizeGB, autoGrow: 'Enabled' }
    backup: { backupRetentionDays: 14, geoRedundantBackup: 'Disabled' }  // região única de dados
    highAvailability: { mode: highAvailability ? 'ZoneRedundant' : 'Disabled' }
    network: {
      delegatedSubnetResourceId: delegatedSubnetId
      privateDnsZoneArmResourceId: privateDnsZoneId
      publicNetworkAccess: 'Disabled'
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
      tenantId: subscription().tenantId
    }
  }
}

resource admin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = {
  parent: psql
  name: entraAdminObjectId
  properties: {
    principalName: entraAdminName
    principalType: entraAdminType
    tenantId: subscription().tenantId
  }
}

// Allow-list de extensões + pré-carga do AGE
resource extAllow 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: psql
  name: 'azure.extensions'
  properties: { value: 'AGE,VECTOR,PG_TRGM,UUID-OSSP', source: 'user-override' }
  dependsOn: [ admin ]
}

resource preload 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: psql
  name: 'shared_preload_libraries'
  properties: { value: 'age,pg_stat_statements', source: 'user-override' }
  dependsOn: [ extAllow ]
}

resource db 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: psql
  name: 'cdi'
  properties: { charset: 'UTF8', collation: 'en_US.utf8' }
  dependsOn: [ preload ]
}

output id string = psql.id
output name string = psql.name
output fqdn string = psql.properties.fullyQualifiedDomainName
