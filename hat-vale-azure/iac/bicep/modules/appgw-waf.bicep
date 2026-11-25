// =============================================================================
// appgw-waf.bicep — "WAF de entrada" (slide 11 item 18): Application Gateway
// WAF_v2 público → APIM interno. Único ponto exposto à internet, usado apenas
// pelo canal do Bot Framework (/bot/api/messages).
// Na Vale, avaliar uso do WAF/Front Door corporativo em vez deste módulo.
// =============================================================================
param location string
param namePrefix string
param tags object
param subnetId string
param apimHostName string        // <apim>.azure-api.net (resolvido no DNS privado)
param appGwIdentityId string
@description('URI do segredo do certificado TLS no Key Vault (sem versão)')
param sslCertSecretId string
param publicHostName string      // ex.: bot-lab.hatthinking.com.br

resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-agw-${namePrefix}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  zones: [ '1', '2', '3' ]
  properties: { publicIPAllocationMethod: 'Static' }
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-05-01' = {
  name: 'waf-${namePrefix}'
  location: location
  tags: tags
  properties: {
    policySettings: { mode: 'Prevention', state: 'Enabled', requestBodyCheck: true }
    managedRules: {
      managedRuleSets: [
        { ruleSetType: 'Microsoft_DefaultRuleSet', ruleSetVersion: '2.1' }
        { ruleSetType: 'Microsoft_BotManagerRuleSet', ruleSetVersion: '1.1' }
      ]
    }
    customRules: [
      {
        name: 'SomenteBotMessages'
        priority: 10
        ruleType: 'MatchRule'
        action: 'Block'
        matchConditions: [
          {
            matchVariables: [ { variableName: 'RequestUri' } ]
            operator: 'BeginsWith'
            negationConditon: true
            matchValues: [ '/bot/api/messages' ]
          }
        ]
      }
    ]
  }
}

var agwName = 'agw-${namePrefix}'
var agwId = resourceId('Microsoft.Network/applicationGateways', agwName)

resource agw 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: agwName
  location: location
  tags: tags
  zones: [ '1', '2', '3' ]
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${appGwIdentityId}': {} } }
  properties: {
    sku: { name: 'WAF_v2', tier: 'WAF_v2' }
    autoscaleConfiguration: { minCapacity: 0, maxCapacity: 2 }
    firewallPolicy: { id: wafPolicy.id }
    gatewayIPConfigurations: [ { name: 'gwip', properties: { subnet: { id: subnetId } } } ]
    frontendIPConfigurations: [ { name: 'fe-public', properties: { publicIPAddress: { id: pip.id } } } ]
    frontendPorts: [ { name: 'p443', properties: { port: 443 } } ]
    sslCertificates: [ { name: 'cert-public', properties: { keyVaultSecretId: sslCertSecretId } } ]
    backendAddressPools: [ { name: 'be-apim', properties: { backendAddresses: [ { fqdn: apimHostName } ] } } ]
    probes: [
      {
        name: 'probe-apim'
        properties: {
          protocol: 'Https'
          host: apimHostName
          path: '/status-0123456789abcdef'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'bhs-apim'
        properties: {
          port: 443
          protocol: 'Https'
          hostName: apimHostName
          pickHostNameFromBackendAddress: false
          requestTimeout: 60
          probe: { id: '${agwId}/probes/probe-apim' }
        }
      }
    ]
    httpListeners: [
      {
        name: 'lst-https'
        properties: {
          frontendIPConfiguration: { id: '${agwId}/frontendIPConfigurations/fe-public' }
          frontendPort: { id: '${agwId}/frontendPorts/p443' }
          protocol: 'Https'
          hostName: publicHostName
          sslCertificate: { id: '${agwId}/sslCertificates/cert-public' }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'rr-bot'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: { id: '${agwId}/httpListeners/lst-https' }
          backendAddressPool: { id: '${agwId}/backendAddressPools/be-apim' }
          backendHttpSettings: { id: '${agwId}/backendHttpSettingsCollection/bhs-apim' }
        }
      }
    ]
  }
}

output publicIp string = pip.properties.ipAddress
