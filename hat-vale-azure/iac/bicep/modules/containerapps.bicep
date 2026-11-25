// =============================================================================
// containerapps.bicep — Container Apps Environment INTERNO (snet-cae /24, zonal)
// Apps: app-integia-mcp (mín. 2), app-integia-gateway (mín. 2), app-integia-runtime
// Jobs: job-ingest-codigo (evento Service Bus), job-ingest-docs (agendado delta
//       Graph), job-avaliacao (manual/CI)
// Imagens iniciais = placeholder; o pipeline de aplicação troca pela imagem do ACR.
// =============================================================================
param location string
param envName string          // lab | dev
param namePrefix string       // integia-lab-brs
param tags object
param subnetId string
param workspaceId string
param appInsightsConnectionString string
param acrLoginServer string
param identities object       // saída de identities.bicep
param serviceBusFqdn string
param env object              // variáveis comuns (endpoints)
param placeholderImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: last(split(workspaceId, '/'))
  scope: resourceGroup(split(workspaceId, '/')[2], split(workspaceId, '/')[4])
}

resource cae 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${namePrefix}'
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
      internal: true
    }
    zoneRedundant: true
    workloadProfiles: [ { name: 'Consumption', workloadProfileType: 'Consumption' } ]
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: law.properties.customerId
        sharedKey: law.listKeys().primarySharedKey
      }
    }
    appInsightsConfiguration: { connectionString: appInsightsConnectionString }
    peerAuthentication: { mtls: { enabled: true } }
  }
}

var commonEnv = [for k in items(env): { name: k.key, value: k.value }]

var appDefs = [
  { short: 'mcp',     id: 'mcp',  minReplicas: 2, port: 8080, cpu: '0.5', mem: '1Gi' }
  { short: 'gateway', id: 'gw',   minReplicas: 2, port: 8080, cpu: '0.5', mem: '1Gi' }
  { short: 'runtime', id: 'orch', minReplicas: 1, port: 8080, cpu: '1.0', mem: '2Gi' }
  { short: 'artef',   id: 'artef', minReplicas: 1, port: 8080, cpu: '0.5', mem: '1Gi' }
  { short: 'valid',   id: 'valid', minReplicas: 1, port: 8080, cpu: '0.5', mem: '1Gi' }
]

resource apps 'Microsoft.App/containerApps@2024-03-01' = [for a in appDefs: {
  name: 'app-integia-${a.short}-${envName}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${identities[a.id].id}': {} }
  }
  properties: {
    environmentId: cae.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        // Em ambiente INTERNO, external=true significa "acessível pela VNet" (não pela internet).
        // Necessário para o APIM (snet-apim) alcançar os apps. Nada é exposto publicamente.
        external: true
        targetPort: a.port
        transport: 'auto'
        allowInsecure: false
      }
      registries: [ { server: acrLoginServer, identity: identities[a.id].id } ]
    }
    template: {
      containers: [
        {
          name: a.short
          image: placeholderImage
          resources: { cpu: json(a.cpu), memory: a.mem }
          env: concat(commonEnv, [ { name: 'AZURE_CLIENT_ID', value: identities[a.id].clientId } ])
          probes: [
            { type: 'Liveness', httpGet: { path: '/healthz', port: a.port }, periodSeconds: 30 }
          ]
        }
      ]
      scale: { minReplicas: a.minReplicas, maxReplicas: 5 }
    }
  }
}]

// ---------- Jobs ----------
resource jobCodigo 'Microsoft.App/jobs@2024-03-01' = {
  name: 'job-ingest-codigo-${envName}'
  location: location
  tags: tags
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${identities.ingest.id}': {} } }
  properties: {
    environmentId: cae.id
    workloadProfileName: 'Consumption'
    configuration: {
      triggerType: 'Event'
      replicaTimeout: 3600
      replicaRetryLimit: 2
      registries: [ { server: acrLoginServer, identity: identities.ingest.id } ]
      eventTriggerConfig: {
        parallelism: 1
        replicaCompletionCount: 1
        scale: {
          minExecutions: 0
          maxExecutions: 5
          pollingInterval: 30
          rules: [
            {
              name: 'sb-ingest-codigo'
              type: 'azure-servicebus'
              metadata: { queueName: 'ingest-codigo', namespace: split(serviceBusFqdn, '.')[0], messageCount: '1' }
              identity: identities.ingest.id
            }
          ]
        }
      }
    }
    template: {
      containers: [
        {
          name: 'ingest-codigo'
          image: placeholderImage
          resources: { cpu: json('1.0'), memory: '2Gi' }
          env: concat(commonEnv, [ { name: 'AZURE_CLIENT_ID', value: identities.ingest.clientId } ])
        }
      ]
    }
  }
}

resource jobDocs 'Microsoft.App/jobs@2024-03-01' = {
  name: 'job-ingest-docs-${envName}'
  location: location
  tags: tags
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${identities.ingest.id}': {} } }
  properties: {
    environmentId: cae.id
    workloadProfileName: 'Consumption'
    configuration: {
      triggerType: 'Schedule'
      replicaTimeout: 3600
      replicaRetryLimit: 1
      registries: [ { server: acrLoginServer, identity: identities.ingest.id } ]
      scheduleTriggerConfig: { cronExpression: '*/30 * * * *', parallelism: 1, replicaCompletionCount: 1 }
    }
    template: {
      containers: [
        {
          name: 'ingest-docs'
          image: placeholderImage
          resources: { cpu: json('1.0'), memory: '2Gi' }
          env: concat(commonEnv, [ { name: 'AZURE_CLIENT_ID', value: identities.ingest.clientId } ])
        }
      ]
    }
  }
}

resource jobAval 'Microsoft.App/jobs@2024-03-01' = {
  name: 'job-avaliacao-${envName}'
  location: location
  tags: tags
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${identities.valid.id}': {} } }
  properties: {
    environmentId: cae.id
    workloadProfileName: 'Consumption'
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 7200
      replicaRetryLimit: 0
      registries: [ { server: acrLoginServer, identity: identities.valid.id } ]
      manualTriggerConfig: { parallelism: 1, replicaCompletionCount: 1 }
    }
    template: {
      containers: [
        {
          name: 'avaliacao'
          image: placeholderImage
          resources: { cpu: json('1.0'), memory: '2Gi' }
          env: concat(commonEnv, [ { name: 'AZURE_CLIENT_ID', value: identities.valid.clientId } ])
        }
      ]
    }
  }
}

output environmentId string = cae.id
output defaultDomain string = cae.properties.defaultDomain
output staticIp string = cae.properties.staticIp
output appFqdns object = toObject(range(0, length(appDefs)), i => appDefs[i].short, i => apps[i].properties.configuration.ingress.fqdn)
