// =============================================================================
// Ambiente Vale (dev) — tenant/assinatura da Vale
// Nomes conforme slide "Implantação e segregação" (rg-integia-dev-brs, ...).
// Valores <...> dependem das respostas às solicitações (docs/03).
// =============================================================================
using '../main.bicep'

param envName = 'dev'
param location = 'brazilsouth'
param nameSuffix = ''
param tags = {
  owner: '<responsável Vale>'
  'cost-center': '<centro de custo Vale>'
  project: 'core-data-integration'
  supplier: 'hat-thinking'
}

// Rede — VNet spoke 10.X.0.0/22 alocada pelo time de rede da Vale (SOL-NET-01)
param addressPrefix = '10.X.0.0/22'
param subnets = {
  cae: '10.X.0.0/24'
  pe: '10.X.1.0/26'
  apim: '10.X.1.64/27'
  devops: '10.X.1.96/27'
  psql: '10.X.1.128/28'
  jump: '10.X.1.144/28'      // não utilizada (deployBastion=false)
  appgw: '10.X.1.192/27'
  aiagents: '10.X.2.0/24'
  bastion: '10.X.3.0/26'     // não utilizada
}
// UDR 0.0.0.0/0 → Firewall/NVA do hub (SOL-NET-03)
param firewallPrivateIp = '<IP privado do firewall do hub>'
// DNS do hub (SOL-NET-04)
param dnsServers = [ '<IP DNS resolver hub 1>', '<IP DNS resolver hub 2>' ]

// DNS privado é do hub: não criar zonas. Duas opções:
//  (a) Azure Policy DINE da Vale registra os PEs → deixar existingDnsZoneIds = {}
//  (b) Informar os IDs das zonas do hub (exige Private DNS Zone Contributor nelas)
param createPrivateDnsZones = false
param existingDnsZoneIds = {}
param postgresPrivateDnsZoneId = '<resourceId da zona psql-integia-dev-brs.private.postgres.database.azure.com no hub>'

// WAF: se a Vale tiver WAF/Front Door corporativo, usar deployAppGw = false
param deployAppGw = true
param deployBastion = false
param deployDevOpsPool = true
param deployBot = true

// Entra ID (tenant Vale) — SOL-IAM-02/03
param engineeringGroupObjectId = '<objectId grp-vale-cdi-engenharia>'
param pgAdminGroupObjectId = '<objectId grp-vale-cdi-pg-admins>'
param pgAdminGroupName = 'grp-vale-cdi-pg-admins'
param apiAudience = 'api://integia-api-dev'
param publisherEmail = '<dl-integracao@vale.com>'
param publisherName = 'Vale — Integração'

param devOpsOrgUrl = 'https://dev.azure.com/<org-vale>'
param existingWorkspaceId = ''   // ou workspace central da Vale

param modelDeployments = [
  { name: 'gpt-4.1',                model: 'gpt-4.1',                version: '2025-04-14', skuName: 'Standard', capacity: 50 }
  { name: 'gpt-4.1-mini',           model: 'gpt-4.1-mini',           version: '2025-04-14', skuName: 'Standard', capacity: 50 }
  { name: 'text-embedding-3-large', model: 'text-embedding-3-large', version: '1',          skuName: 'Standard', capacity: 100 }
]

param apimSku = 'Developer'          // Premium se exigido SLA/zonas
param searchSku = 'standard'
param pgSkuName = 'Standard_D2ds_v5'
param pgSkuTier = 'GeneralPurpose'
param pgHighAvailability = false
param serviceBusCapacity = 1

param publicHostName = '<cdi-bot-dev.vale.com>'
param sslCertSecretId = 'https://kv-integia-dev-brs.vault.azure.net/secrets/tls-appgw'
