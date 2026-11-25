// =============================================================================
// network.bicep — VNet spoke, subnets, NSGs e (opcional) rota para Firewall/NVA
// Espelha o slide "Implantação e segregação": VNet spoke /22 em Brazil South.
// =============================================================================
param location string
param namePrefix string            // ex.: integia-lab-brs
param tags object
param addressPrefix string         // ex.: 10.50.0.0/22
param subnets object               // ver main.bicep (cae, pe, apim, devops, psql, aiagents, appgw, bastion, jump)
@description('IP privado do Firewall/NVA do hub. Vazio = sem UDR (ambiente HAT sem hub).')
param firewallPrivateIp string = ''
@description('Servidores DNS customizados (DNS do hub). Vazio = Azure DNS (168.63.129.16).')
param dnsServers array = []
param deployAppGw bool
param deployBastion bool

var hasUdr = !empty(firewallPrivateIp)

resource rt 'Microsoft.Network/routeTables@2024-05-01' = if (hasUdr) {
  name: 'rt-${namePrefix}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default-to-hub-fw'
        properties: { addressPrefix: '0.0.0.0/0', nextHopType: 'VirtualAppliance', nextHopIpAddress: firewallPrivateIp }
      }
    ]
  }
}

// ---------- NSGs ----------
resource nsgDefault 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${namePrefix}-default'
  location: location
  tags: tags
  properties: { securityRules: [] }
}

// APIM em modo VNet interno (stv2) — regras mínimas documentadas pela Microsoft
resource nsgApim 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${namePrefix}-apim'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'in-apim-management'
        properties: { priority: 100, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'ApiManagement', sourcePortRange: '*', destinationAddressPrefix: 'VirtualNetwork', destinationPortRange: '3443' }
      }
      {
        name: 'in-azure-lb'
        properties: { priority: 110, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'AzureLoadBalancer', sourcePortRange: '*', destinationAddressPrefix: 'VirtualNetwork', destinationPortRange: '6390' }
      }
      {
        name: 'in-vnet-https'
        properties: { priority: 120, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*', destinationAddressPrefix: 'VirtualNetwork', destinationPortRange: '443' }
      }
      {
        name: 'out-storage'
        properties: { priority: 100, direction: 'Outbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*', destinationAddressPrefix: 'Storage', destinationPortRange: '443' }
      }
      {
        name: 'out-sql'
        properties: { priority: 110, direction: 'Outbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*', destinationAddressPrefix: 'Sql', destinationPortRange: '1433' }
      }
      {
        name: 'out-keyvault'
        properties: { priority: 120, direction: 'Outbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*', destinationAddressPrefix: 'AzureKeyVault', destinationPortRange: '443' }
      }
      {
        name: 'out-monitor'
        properties: { priority: 130, direction: 'Outbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*', destinationAddressPrefix: 'AzureMonitor', destinationPortRanges: [ '1886', '443' ] }
      }
    ]
  }
}

// Application Gateway v2 (WAF de entrada do /api/messages do Bot)
resource nsgAppGw 'Microsoft.Network/networkSecurityGroups@2024-05-01' = if (deployAppGw) {
  name: 'nsg-${namePrefix}-appgw'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'in-gateway-manager'
        properties: { priority: 100, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'GatewayManager', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '65200-65535' }
      }
      {
        name: 'in-https-botframework'
        // Restringir à service tag do Bot Framework / Teams conforme política do cliente

        properties: { priority: 110, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'AzureBotService', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '443' }
      }
      {
        name: 'in-azure-lb'
        properties: { priority: 120, direction: 'Inbound', access: 'Allow', protocol: '*', sourceAddressPrefix: 'AzureLoadBalancer', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '*' }
      }
    ]
  }
}

// Bastion (somente ambiente HAT) — regras obrigatórias do Azure Bastion
resource nsgBastion 'Microsoft.Network/networkSecurityGroups@2024-05-01' = if (deployBastion) {
  name: 'nsg-${namePrefix}-bastion'
  location: location
  tags: tags
  properties: {
    securityRules: [
      { name: 'in-https', properties: { priority: 100, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'Internet', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '443' } }
      { name: 'in-gwmgr', properties: { priority: 110, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'GatewayManager', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '443' } }
      { name: 'in-lb', properties: { priority: 120, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'AzureLoadBalancer', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '443' } }
      { name: 'in-dataplane', properties: { priority: 130, direction: 'Inbound', access: 'Allow', protocol: '*', sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*', destinationAddressPrefix: 'VirtualNetwork', destinationPortRanges: [ '8080', '5701' ] } }
      { name: 'out-ssh-rdp', properties: { priority: 100, direction: 'Outbound', access: 'Allow', protocol: '*', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: 'VirtualNetwork', destinationPortRanges: [ '22', '3389' ] } }
      { name: 'out-azurecloud', properties: { priority: 110, direction: 'Outbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: 'AzureCloud', destinationPortRange: '443' } }
      { name: 'out-dataplane', properties: { priority: 120, direction: 'Outbound', access: 'Allow', protocol: '*', sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*', destinationAddressPrefix: 'VirtualNetwork', destinationPortRanges: [ '8080', '5701' ] } }
      { name: 'out-internet', properties: { priority: 130, direction: 'Outbound', access: 'Allow', protocol: '*', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: 'Internet', destinationPortRange: '80' } }
    ]
  }
}

var udr = hasUdr ? { id: rt.id } : null

var baseSubnets = [
  {
    name: 'snet-cae'
    properties: {
      addressPrefix: subnets.cae
      networkSecurityGroup: { id: nsgDefault.id }
      routeTable: udr
      delegations: [ { name: 'cae', properties: { serviceName: 'Microsoft.App/environments' } } ]
    }
  }
  {
    name: 'snet-pe'
    properties: {
      addressPrefix: subnets.pe
      networkSecurityGroup: { id: nsgDefault.id }
      privateEndpointNetworkPolicies: 'Enabled'
    }
  }
  {
    name: 'snet-apim'
    properties: {
      addressPrefix: subnets.apim
      networkSecurityGroup: { id: nsgApim.id }
      routeTable: udr
    }
  }
  {
    name: 'snet-agents'
    properties: {
      addressPrefix: subnets.devops
      networkSecurityGroup: { id: nsgDefault.id }
      routeTable: udr
      delegations: [ { name: 'mdp', properties: { serviceName: 'Microsoft.DevOpsInfrastructure/pools' } } ]
    }
  }
  {
    name: 'snet-psql'
    properties: {
      addressPrefix: subnets.psql
      networkSecurityGroup: { id: nsgDefault.id }
      delegations: [ { name: 'psql', properties: { serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers' } } ]
    }
  }
  {
    // Subnet para o Foundry Agent Service (standard setup com VNet própria)
    name: 'snet-aiagents'
    properties: {
      addressPrefix: subnets.aiagents
      networkSecurityGroup: { id: nsgDefault.id }
      routeTable: udr
      delegations: [ { name: 'aiagents', properties: { serviceName: 'Microsoft.App/environments' } } ]
    }
  }
]

var appGwSubnet = deployAppGw ? [
  {
    name: 'snet-appgw'
    properties: {
      addressPrefix: subnets.appgw
      networkSecurityGroup: { id: nsgAppGw.id }
    }
  }
] : []

var bastionSubnets = deployBastion ? [
  {
    name: 'AzureBastionSubnet'
    properties: {
      addressPrefix: subnets.bastion
      networkSecurityGroup: { id: nsgBastion.id }
    }
  }
  {
    name: 'snet-jump'
    properties: {
      addressPrefix: subnets.jump
      networkSecurityGroup: { id: nsgDefault.id }
    }
  }
] : []

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${namePrefix}'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [ addressPrefix ] }
    dhcpOptions: empty(dnsServers) ? null : { dnsServers: dnsServers }
    subnets: concat(baseSubnets, appGwSubnet, bastionSubnets)
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetIds object = {
  cae: '${vnet.id}/subnets/snet-cae'
  pe: '${vnet.id}/subnets/snet-pe'
  apim: '${vnet.id}/subnets/snet-apim'
  devops: '${vnet.id}/subnets/snet-agents'
  psql: '${vnet.id}/subnets/snet-psql'
  aiagents: '${vnet.id}/subnets/snet-aiagents'
  appgw: deployAppGw ? '${vnet.id}/subnets/snet-appgw' : ''
  bastion: deployBastion ? '${vnet.id}/subnets/AzureBastionSubnet' : ''
  jump: deployBastion ? '${vnet.id}/subnets/snet-jump' : ''
}
