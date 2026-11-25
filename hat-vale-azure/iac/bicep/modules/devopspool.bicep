// =============================================================================
// devopspool.bicep — Managed DevOps Pool (snet-agents /27, delegada)
// Executa build obrigatório do PR proposto pelo A2/A3 e jobs de deploy privado.
// Pré-requisitos (item de solicitação na Vale):
//   - Provider Microsoft.DevOpsInfrastructure registrado
//   - SP "DevOpsInfrastructure" com Reader + Network Contributor na VNet
//   - Org Azure DevOps conectada ao tenant Entra; permissão para criar pools
// =============================================================================
param location string
param namePrefix string
param tags object
param subnetId string
param devOpsOrgUrl string
param maxConcurrency int = 2
param vmSku string = 'Standard_D2ads_v5'

resource dc 'Microsoft.DevCenter/devcenters@2024-02-01' = {
  name: 'dc-${namePrefix}'
  location: location
  tags: tags
}

resource dcp 'Microsoft.DevCenter/projects@2024-02-01' = {
  name: 'dcp-${namePrefix}'
  location: location
  tags: tags
  properties: { devCenterId: dc.id }
}

resource pool 'Microsoft.DevOpsInfrastructure/pools@2024-10-19' = {
  name: 'mdp-${namePrefix}'
  location: location
  tags: tags
  properties: {
    devCenterProjectResourceId: dcp.id
    maximumConcurrency: maxConcurrency
    organizationProfile: {
      kind: 'AzureDevOps'
      organizations: [ { url: devOpsOrgUrl, parallelism: maxConcurrency } ]
      permissionProfile: { kind: 'CreatorOnly' }
    }
    agentProfile: { kind: 'Stateless' }
    fabricProfile: {
      kind: 'Vmss'
      sku: { name: vmSku }
      images: [ { wellKnownImageName: 'ubuntu-22.04/latest', buffer: '*' } ]
      osProfile: { logonType: 'Service' }
      storageProfile: { osDiskStorageAccountType: 'Standard' }
      networkProfile: { subnetId: subnetId }
    }
  }
}

output poolName string = pool.name
