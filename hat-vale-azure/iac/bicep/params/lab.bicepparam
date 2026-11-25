// =============================================================================
// Ambiente INTERNO HAT (lab) — tenant/assinatura da HAT Thinking
// Espelho fiel do desenho da Vale para validar IaC, rede privada, RBAC e agentes
// antes de submeter as solicitações à Vale.
// =============================================================================
using '../main.bicep'

param envName = 'lab'
param location = 'brazilsouth'
param nameSuffix = 'hat'            // nomes globais distintos dos da Vale
param tags = {
  owner: 'hat-engenharia'
  'cost-center': 'HAT-LAB-CDI'
  project: 'vale-core-data-integration'
}

// Rede — sem hub: DNS privado local, sem firewall
param addressPrefix = '10.50.0.0/22'
param subnets = {
  cae: '10.50.0.0/24'
  pe: '10.50.1.0/26'
  apim: '10.50.1.64/27'
  devops: '10.50.1.96/27'
  psql: '10.50.1.128/28'
  jump: '10.50.1.144/28'
  appgw: '10.50.1.192/27'
  aiagents: '10.50.2.0/24'
  bastion: '10.50.3.0/26'
}
param createPrivateDnsZones = true
param firewallPrivateIp = ''

// 1º deploy: WAF e Bot desligados (o certificado TLS precisa ser importado no Key Vault,
// que só aceita acesso privado). Depois de importar `tls-appgw` pelo jump, mude para true.
param deployAppGw = false
param deployBastion = true
param deployDevOpsPool = true
param deployBot = false

// Entra ID (tenant HAT) — preencher com os objectIds reais
param engineeringGroupObjectId = '<objectId grp-hat-cdi-engenharia>'
param pgAdminGroupObjectId = '<objectId grp-hat-cdi-pg-admins>'
param pgAdminGroupName = 'grp-hat-cdi-pg-admins'
param apiAudience = 'api://integia-api-lab'
param publisherEmail = 'engenharia@hatthinking.com.br'

param devOpsOrgUrl = 'https://dev.azure.com/<org-hat>'

// Modelos — SKU Standard regional (residência de dados em Brazil South).
// Validar disponibilidade/cota: scripts/00-preflight.sh
param modelDeployments = [
  { name: 'gpt-4.1',                model: 'gpt-4.1',                version: '2025-04-14', skuName: 'Standard', capacity: 30 }
  { name: 'gpt-4.1-mini',           model: 'gpt-4.1-mini',           version: '2025-04-14', skuName: 'Standard', capacity: 30 }
  { name: 'text-embedding-3-large', model: 'text-embedding-3-large', version: '1',          skuName: 'Standard', capacity: 50 }
]

// Dimensionamento econômico de laboratório
param apimSku = 'Developer'
param searchSku = 'basic'
param pgSkuName = 'Standard_B2s'
param pgSkuTier = 'Burstable'
param pgHighAvailability = false
param serviceBusCapacity = 1

// Entrada pública do Bot (domínio HAT) — certificado no Key Vault
param publicHostName = 'cdi-bot-lab.hatthinking.com.br'
param sslCertSecretId = 'https://kv-integia-lab-brs-hat.vault.azure.net/secrets/tls-appgw'

param jumpSshPublicKey = '<ssh-rsa AAAA... break-glass>'
