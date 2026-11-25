// =============================================================================
// docintel.bicep — Document Intelligence (prebuilt-layout → Markdown, slide 16)
// =============================================================================
param location string
param name string
param tags object

resource di 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: name
  location: location
  tags: tags
  kind: 'FormRecognizer'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: name
    disableLocalAuth: true
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny' }
  }
}

output id string = di.id
output endpoint string = 'https://${name}.cognitiveservices.azure.com/'
