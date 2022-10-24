param systemName string

@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string
param location string = resourceGroup().location
param locationAbbreviation string
param availabilityRegions array
param availabilityEndpoints array
param webPubSubSku object
param developersGroup string

var defaultResourceName = toLower('${systemName}-${environmentName}-${locationAbbreviation}')
var webPubSubHubname = 'pollstar'

resource configurationDataReaderRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: resourceGroup()
  name: '516239f1-63e1-4d78-a4de-a74fb236a071'
}
resource allowContributorForDevelopmentTeam 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${developersGroup}-${configurationDataReaderRole.name}')
  properties: {
    principalId: developersGroup
    principalType: 'Group'
    roleDefinitionId: configurationDataReaderRole.id
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${defaultResourceName}-kv'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        objectId: developersGroup
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'list'
            'get'
          ]
        }
      }
    ]
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: '${defaultResourceName}-log'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${defaultResourceName}-ai'
  location: location
  kind: 'web'
  properties: {
    WorkspaceResourceId: logAnalyticsWorkspace.id
    Application_Type: 'web'
  }
}

resource containerAppEnvironments 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: '${defaultResourceName}-env'
  location: location
  properties: {
    daprAIInstrumentationKey: applicationInsights.properties.InstrumentationKey
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

// Web pubsub
resource webPubSub 'Microsoft.SignalRService/webPubSub@2021-10-01' = {
  name: '${defaultResourceName}-pubsub'
  location: location
  sku: webPubSubSku
  properties: {
    publicNetworkAccess: 'Enabled'
  }
  resource hub 'hubs' = {
    name: webPubSubHubname
    properties: {
      anonymousConnectPolicy: 'allow'
    }
  }
}
resource webPubSubSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'WebPubSub'
  parent: keyVault
  properties: {
    contentType: 'text/plain'
    value: webPubSub.listKeys().primaryConnectionString
  }
}
resource webPubSubConfigurationValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  name: 'Azure:WebPubSub'
  parent: appConfig
  properties: {
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
    value: '{"uri":"${webPubSubSecret.properties.secretUri}"}'
  }
}
resource webPubSubHubNameConfigurationValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  name: 'Azure:PollStarHub'
  parent: appConfig
  properties: {
    contentType: 'text/plain'
    value: webPubSubHubname
  }
}

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2022-05-01' = {
  name: '${defaultResourceName}-cfg'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: toLower(replace('${defaultResourceName}-acr', '-', ''))
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    anonymousPullEnabled: true

  }
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: '${defaultResourceName}-bus'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource availabilityTest 'Microsoft.Insights/webtests@2022-06-15' = [for avchk in availabilityEndpoints: {
  name: avchk.name
  location: location
  tags: {
    'hidden-link:${applicationInsights.id}': 'Resource'
  }
  kind: 'standard'
  properties: {
    SyntheticMonitorId: avchk.name
    Kind: 'standard'
    Frequency: 600
    Name: avchk.name
    Enabled: true
    Locations: [for loc in availabilityRegions: {
      Id: loc
    }]
    Request: {
      RequestUrl: avchk.endpoint
    }
  }
}]

resource serviceBusName 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  name: 'Azure:ServiceBus'
  parent: appConfig
  properties: {
    contentType: 'text/plain'
    value: serviceBus.name
  }
}

resource applicationInsightsConfigurationValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
  parent: appConfig
  properties: {
    value: applicationInsights.properties.ConnectionString
    contentType: 'text/plain'
  }
}

output containerAppEnvironmentName string = containerAppEnvironments.name
output applicationInsightsResourceName string = applicationInsights.name
