// =============================================================================
// bot.bicep — Azure Bot (canal Microsoft Teams) com identidade UserAssignedMSI
// Endpoint: https://<host público do WAF>/bot/api/messages → APIM interno → runtime
// =============================================================================
param name string
param tags object
param botIdentity object   // { id, clientId }
param messagingEndpoint string
param tenantId string = subscription().tenantId
@allowed([ 'F0', 'S1' ])
param sku string = 'S1'

resource bot 'Microsoft.BotService/botServices@2022-09-15' = {
  name: name
  location: 'global'
  tags: tags
  kind: 'azurebot'
  sku: { name: sku }
  properties: {
    displayName: 'Integração IA — Core Data'
    endpoint: messagingEndpoint
    msaAppId: botIdentity.clientId
    msaAppType: 'UserAssignedMSI'
    msaAppMSIResourceId: botIdentity.id
    msaAppTenantId: tenantId
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource teams 'Microsoft.BotService/botServices/channels@2022-09-15' = {
  parent: bot
  name: 'MsTeamsChannel'
  location: 'global'
  properties: {
    channelName: 'MsTeamsChannel'
    properties: { isEnabled: true, acceptedTerms: true }
  }
}

output id string = bot.id
