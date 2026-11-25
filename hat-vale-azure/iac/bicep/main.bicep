// =============================================================================
// main.bicep — Core Data Integration Foundation (HAT ⇄ Vale)
// Um único template para os dois ambientes:
//   - HAT (envName=lab): tenant HAT, cria DNS privado, Bastion/jump, sem hub
//   - Vale (envName=dev): tenant Vale, DNS pelo hub, UDR para firewall/NVA,
//     sem Bastion, nomes iguais aos do slide "Implantação e segregação"
// Escopo: resource group (criado por scripts/01-deploy.sh).
// =============================================================================
targetScope = 'resourceGroup'

// ---------------- Identificação ----------------
@allowed([ 'lab', 'dev', 'qa', 'prd' ])
param envName string
param location string = 'brazilsouth'
param workload string = 'integia'
param locShort string = 'brs'
@description('Sufixo opcional para nomes globais (evita colisão de nomes globais; vazio = nomes do desenho)')
param nameSuffix string = ''
param tags object = {}

// ---------------- Rede ----------------
param addressPrefix string
param subnets object
param firewallPrivateIp string = ''
param dnsServers array = []
@description('true = cria zonas privatelink.* neste RG (HAT). false = usa zonas do hub (Vale).')
param createPrivateDnsZones bool = true
@description('Vale: mapa { "privatelink.blob.core.windows.net": "<resourceId da zona no hub>", ... }. Vazio = registro por Azure Policy (DINE).')
param existingDnsZoneIds object = {}
@description('Vale: resourceId da zona <x>.private.postgres.database.azure.com fornecida pelo hub')
param postgresPrivateDnsZoneId string = ''

// ---------------- Opcionais ----------------
param deployAppGw bool = true
param deployBastion bool = false
param deployDevOpsPool bool = true
param deployBot bool = true

// ---------------- Identidade / acesso ----------------
param engineeringGroupObjectId string
param pgAdminGroupObjectId string
param pgAdminGroupName string
@description('Audiência (App ID URI ou clientId) da API "integia-api" registrada no Entra')
param apiAudience string
param publisherEmail string
param publisherName string = 'HAT Thinking'

// ---------------- Plataforma ----------------
param devOpsOrgUrl string = ''
param modelDeployments array
param existingWorkspaceId string = ''
param apimSku string = 'Developer'
param searchSku string = 'standard'
param pgSkuName string = 'Standard_D2ds_v5'
param pgSkuTier string = 'GeneralPurpose'
param pgHighAvailability bool = false
param serviceBusCapacity int = 1

// ---------------- Entrada pública (Bot) ----------------
param publicHostName string = ''
param sslCertSecretId string = ''

// ---------------- Jump (somente HAT) ----------------
param jumpSshPublicKey string = ''

// =============================================================================
var namePrefix = '${workload}-${envName}-${locShort}'
var sfx = empty(nameSuffix) ? '' : '-${nameSuffix}'
var sfxNoDash = replace(nameSuffix, '-', '')
var allTags = union({
  workload: 'core-data-integration'
  environment: envName
  'managed-by': 'bicep'
  'data-residency': 'brazil'
}, tags)

var names = {
  kv: take('kv-${namePrefix}${sfx}', 24)
  lake: take('st${workload}${envName}${locShort}${sfxNoDash}', 24)
  agentSt: take('st${workload}ag${envName}${locShort}${sfxNoDash}', 24)
  sb: 'sb-${namePrefix}${sfx}'
  acr: take('cr${workload}${envName}${locShort}${sfxNoDash}', 50)
  search: 'srch-${namePrefix}${sfx}'
  psql: 'psql-${namePrefix}${sfx}'
  cosmos: 'cosmos-${namePrefix}${sfx}'
  foundry: 'aif-${namePrefix}${sfx}'
  project: 'proj-cdi-${envName}'
  docintel: 'di-${namePrefix}${sfx}'
  apim: 'apim-${namePrefix}${sfx}'
  dts: 'dts-${namePrefix}${sfx}'
  bot: 'bot-${namePrefix}${sfx}'
}

var privatelinkZones = [
  'privatelink.blob.core.windows.net'
  'privatelink.dfs.core.windows.net'
  'privatelink.vaultcore.azure.net'
  'privatelink.search.windows.net'
  'privatelink.servicebus.windows.net'
  'privatelink.azurecr.io'
  'privatelink.documents.azure.com'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
]
var pgZoneName = '${names.psql}.private.postgres.database.azure.com'

// ---------------- Rede ----------------
module net 'modules/network.bicep' = {
  name: 'net'
  params: {
    location: location
    namePrefix: namePrefix
    tags: allTags
    addressPrefix: addressPrefix
    subnets: subnets
    firewallPrivateIp: firewallPrivateIp
    dnsServers: dnsServers
    deployAppGw: deployAppGw
    deployBastion: deployBastion
  }
}

module dns 'modules/private-dns.bicep' = if (createPrivateDnsZones) {
  name: 'dns'
  params: {
    vnetId: net.outputs.vnetId
    tags: allTags
    zones: concat(privatelinkZones, [ pgZoneName ])
  }
}

var zoneMap = createPrivateDnsZones ? dns.outputs.zoneIds : existingDnsZoneIds
var z = {
  blob: contains(zoneMap, 'privatelink.blob.core.windows.net') ? [ zoneMap['privatelink.blob.core.windows.net'] ] : []
  dfs: contains(zoneMap, 'privatelink.dfs.core.windows.net') ? [ zoneMap['privatelink.dfs.core.windows.net'] ] : []
  kv: contains(zoneMap, 'privatelink.vaultcore.azure.net') ? [ zoneMap['privatelink.vaultcore.azure.net'] ] : []
  search: contains(zoneMap, 'privatelink.search.windows.net') ? [ zoneMap['privatelink.search.windows.net'] ] : []
  sb: contains(zoneMap, 'privatelink.servicebus.windows.net') ? [ zoneMap['privatelink.servicebus.windows.net'] ] : []
  acr: contains(zoneMap, 'privatelink.azurecr.io') ? [ zoneMap['privatelink.azurecr.io'] ] : []
  cosmos: contains(zoneMap, 'privatelink.documents.azure.com') ? [ zoneMap['privatelink.documents.azure.com'] ] : []
  ai: filter([
    contains(zoneMap, 'privatelink.cognitiveservices.azure.com') ? zoneMap['privatelink.cognitiveservices.azure.com'] : ''
    contains(zoneMap, 'privatelink.openai.azure.com') ? zoneMap['privatelink.openai.azure.com'] : ''
    contains(zoneMap, 'privatelink.services.ai.azure.com') ? zoneMap['privatelink.services.ai.azure.com'] : ''
  ], x => !empty(x))
  cog: contains(zoneMap, 'privatelink.cognitiveservices.azure.com') ? [ zoneMap['privatelink.cognitiveservices.azure.com'] ] : []
}
var pgZoneId = createPrivateDnsZones ? dns.outputs.zoneIds[pgZoneName] : postgresPrivateDnsZoneId

// ---------------- Observabilidade e identidades ----------------
module mon 'modules/monitoring.bicep' = {
  name: 'mon'
  params: {
    location: location
    namePrefix: namePrefix
    tags: allTags
    existingWorkspaceId: existingWorkspaceId
  }
}

module ids 'modules/identities.bicep' = {
  name: 'ids'
  params: { location: location, tags: allTags, envName: envName }
}

// ---------------- PaaS de dados ----------------
module kv 'modules/keyvault.bicep' = {
  name: 'kv'
  params: { location: location, name: names.kv, tags: allTags, purgeProtection: envName != 'lab' }
}

module lake 'modules/storage.bicep' = {
  name: 'lake'
  params: {
    location: location
    name: names.lake
    tags: allTags
    isHnsEnabled: true
    containers: [ 'raw', 'gold', 'entregaveis' ]
  }
}

module agentSt 'modules/storage.bicep' = {
  name: 'agentst'
  params: {
    location: location
    name: names.agentSt
    tags: allTags
    isHnsEnabled: false
    containers: []
  }
}

module sb 'modules/servicebus.bicep' = {
  name: 'sb'
  params: { location: location, name: names.sb, tags: allTags, capacity: serviceBusCapacity }
}

module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: { location: location, name: names.acr, tags: allTags }
}

module search 'modules/search.bicep' = {
  name: 'search'
  params: { location: location, name: names.search, tags: allTags, sku: searchSku }
}

module cosmos 'modules/cosmos.bicep' = {
  name: 'cosmos'
  params: { location: location, name: names.cosmos, tags: allTags }
}

module di 'modules/docintel.bicep' = {
  name: 'docintel'
  params: { location: location, name: names.docintel, tags: allTags }
}

module psql 'modules/postgres.bicep' = {
  name: 'psql'
  params: {
    location: location
    name: names.psql
    tags: allTags
    delegatedSubnetId: net.outputs.subnetIds.psql
    privateDnsZoneId: pgZoneId
    entraAdminObjectId: pgAdminGroupObjectId
    entraAdminName: pgAdminGroupName
    skuName: pgSkuName
    skuTier: pgSkuTier
    highAvailability: pgHighAvailability
  }
}

// ---------------- Private Endpoints ----------------
var peDefs = [
  { n: 'lake-blob', id: lake.outputs.id, g: 'blob', zones: z.blob }
  { n: 'lake-dfs', id: lake.outputs.id, g: 'dfs', zones: z.dfs }
  { n: 'agentst-blob', id: agentSt.outputs.id, g: 'blob', zones: z.blob }
  { n: 'kv', id: kv.outputs.id, g: 'vault', zones: z.kv }
  { n: 'search', id: search.outputs.id, g: 'searchService', zones: z.search }
  { n: 'sb', id: sb.outputs.id, g: 'namespace', zones: z.sb }
  { n: 'acr', id: acr.outputs.id, g: 'registry', zones: z.acr }
  { n: 'cosmos', id: cosmos.outputs.id, g: 'Sql', zones: z.cosmos }
  { n: 'docintel', id: di.outputs.id, g: 'account', zones: z.cog }
]

module pes 'modules/private-endpoint.bicep' = [for p in peDefs: {
  name: 'pe-${p.n}'
  params: {
    name: 'pe-${p.n}-${namePrefix}'
    location: location
    tags: allTags
    subnetId: net.outputs.subnetIds.pe
    targetResourceId: p.id
    groupId: p.g
    dnsZoneIds: p.zones
  }
}]

// ---------------- Foundry ----------------
module foundry 'modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    location: location
    accountName: names.foundry
    projectName: names.project
    tags: allTags
    agentSubnetId: net.outputs.subnetIds.aiagents
    modelDeployments: modelDeployments
    cosmosId: cosmos.outputs.id
    cosmosEndpoint: cosmos.outputs.endpoint
    agentStorageId: agentSt.outputs.id
    agentStorageBlobEndpoint: agentSt.outputs.blobEndpoint
    searchId: search.outputs.id
    searchEndpoint: search.outputs.endpoint
    appInsightsId: mon.outputs.appInsightsId
    appInsightsConnectionString: mon.outputs.appInsightsConnectionString
  }
}

module peFoundry 'modules/private-endpoint.bicep' = {
  name: 'pe-foundry'
  params: {
    name: 'pe-foundry-${namePrefix}'
    location: location
    tags: allTags
    subnetId: net.outputs.subnetIds.pe
    targetResourceId: foundry.outputs.accountId
    groupId: 'account'
    dnsZoneIds: z.ai
  }
}

// ---------------- RBAC ----------------
module rbac 'modules/rbac.bicep' = {
  name: 'rbac'
  params: {
    identities: ids.outputs.ids
    lakeName: lake.outputs.name
    agentStorageName: agentSt.outputs.name
    searchName: search.outputs.name
    keyVaultName: kv.outputs.name
    acrName: acr.outputs.name
    serviceBusName: sb.outputs.name
    foundryAccountName: foundry.outputs.accountName
    foundryProjectPrincipalId: foundry.outputs.projectPrincipalId
    cosmosName: cosmos.outputs.name
    docIntelName: names.docintel
    engineeringGroupObjectId: engineeringGroupObjectId
  }
  dependsOn: [ di ]
}

module caphost 'modules/foundry-caphost.bicep' = {
  name: 'foundry-caphost'
  params: {
    accountName: foundry.outputs.accountName
    projectName: foundry.outputs.projectName
    cosmosConnection: foundry.outputs.connectionNames.cosmos
    storageConnection: foundry.outputs.connectionNames.storage
    searchConnection: foundry.outputs.connectionNames.search
  }
  dependsOn: [ rbac, peFoundry, pes ]
}

// ---------------- Orquestração durável ----------------
module dts 'modules/durabletask.bicep' = {
  name: 'dts'
  params: { location: location, name: names.dts, tags: allTags }
}

// ---------------- Compute (Container Apps) ----------------
module cae 'modules/containerapps.bicep' = {
  name: 'cae'
  params: {
    location: location
    envName: envName
    namePrefix: namePrefix
    tags: allTags
    subnetId: net.outputs.subnetIds.cae
    workspaceId: mon.outputs.workspaceId
    appInsightsConnectionString: mon.outputs.appInsightsConnectionString
    acrLoginServer: acr.outputs.loginServer
    identities: ids.outputs.ids
    serviceBusFqdn: sb.outputs.fqdn
    env: {
      CDI_ENV: envName
      SEARCH_ENDPOINT: search.outputs.endpoint
      LAKE_DFS_ENDPOINT: lake.outputs.dfsEndpoint
      PG_HOST: psql.outputs.fqdn
      PG_DATABASE: 'cdi'
      SERVICEBUS_FQDN: sb.outputs.fqdn
      KEYVAULT_URI: kv.outputs.uri
      FOUNDRY_PROJECT_ENDPOINT: foundry.outputs.endpoint
      DOCINTEL_ENDPOINT: di.outputs.endpoint
      DTS_ENDPOINT: dts.outputs.endpoint
      DTS_TASKHUB: dts.outputs.taskHub
      SEARCH_INDEX_CODIGO: 'idx-codigo'
      SEARCH_INDEX_DOCS: 'idx-docs'
      SEARCH_INDEX_LEANIX: 'idx-leanix'
    }
  }
  dependsOn: [ rbac, pes ]
}

// ---------------- Gateway (APIM interno) ----------------
module apim 'modules/apim.bicep' = {
  name: 'apim'
  params: {
    location: location
    name: names.apim
    tags: allTags
    subnetId: net.outputs.subnetIds.apim
    publisherEmail: publisherEmail
    publisherName: publisherName
    skuName: apimSku
    appInsightsId: mon.outputs.appInsightsId
    appInsightsConnectionString: mon.outputs.appInsightsConnectionString
    apiAudience: apiAudience
    mcpBackendUrl: 'https://${cae.outputs.appFqdns.mcp}'
    gatewayBackendUrl: 'https://${cae.outputs.appFqdns.gateway}'
    runtimeBackendUrl: 'https://${cae.outputs.appFqdns.runtime}'
    botAppId: ids.outputs.ids.bot.clientId
  }
}

module caeDns 'modules/cae-dns.bicep' = if (createPrivateDnsZones) {
  name: 'cae-apim-dns'
  params: {
    vnetId: net.outputs.vnetId
    tags: allTags
    caeDefaultDomain: cae.outputs.defaultDomain
    caeStaticIp: cae.outputs.staticIp
    apimName: apim.outputs.name
    apimPrivateIp: apim.outputs.privateIp
  }
}

// ---------------- Entrada pública + Bot ----------------
module agw 'modules/appgw-waf.bicep' = if (deployAppGw) {
  name: 'appgw'
  params: {
    location: location
    namePrefix: namePrefix
    tags: allTags
    subnetId: net.outputs.subnetIds.appgw
    apimHostName: apim.outputs.gatewayHost
    appGwIdentityId: ids.outputs.ids.appgw.id
    sslCertSecretId: sslCertSecretId
    publicHostName: publicHostName
  }
  dependsOn: [ rbac, caeDns ]
}

module bot 'modules/bot.bicep' = if (deployBot) {
  name: 'bot'
  params: {
    name: names.bot
    tags: allTags
    botIdentity: ids.outputs.ids.bot
    messagingEndpoint: 'https://${publicHostName}/bot/api/messages'
  }
}

// ---------------- CI/CD privado ----------------
module mdp 'modules/devopspool.bicep' = if (deployDevOpsPool && !empty(devOpsOrgUrl)) {
  name: 'devopspool'
  params: {
    location: location
    namePrefix: namePrefix
    tags: allTags
    subnetId: net.outputs.subnetIds.devops
    devOpsOrgUrl: devOpsOrgUrl
  }
}

// ---------------- Jump (HAT) ----------------
module jump 'modules/bastion-jump.bicep' = if (deployBastion) {
  name: 'bastion-jump'
  params: {
    location: location
    namePrefix: namePrefix
    tags: allTags
    bastionSubnetId: net.outputs.subnetIds.bastion
    jumpSubnetId: net.outputs.subnetIds.jump
    sshPublicKey: jumpSshPublicKey
  }
}

// =============================================================================
output vnetId string = net.outputs.vnetId
output identities object = ids.outputs.ids
output foundryProjectEndpoint string = foundry.outputs.endpoint
output foundryProjectPrincipalId string = foundry.outputs.projectPrincipalId
output foundryProjectWorkspaceId string = foundry.outputs.projectWorkspaceId
output cosmosName string = cosmos.outputs.name
output searchEndpoint string = search.outputs.endpoint
output postgresFqdn string = psql.outputs.fqdn
output apimPrivateIp string = apim.outputs.privateIp
output caeDefaultDomain string = cae.outputs.defaultDomain
output caeStaticIp string = cae.outputs.staticIp
output dtsId string = dts.outputs.id
output keyVaultName string = kv.outputs.name
output acrLoginServer string = acr.outputs.loginServer
