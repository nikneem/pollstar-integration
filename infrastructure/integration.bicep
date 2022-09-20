param defaultResourceName string
param location string = resourceGroup().location
param availabilityRegions array
param availabilityEndpoints array

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

resource webPubSub 'Microsoft.SignalRService/webPubSub@2021-10-01' = {
  name: '${defaultResourceName}-pubsub'
  location: location
  sku: {
    capacity: 1
    tier: 'Basic'
    name: 'Standard_S1'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
  resource hub 'hubs' = {
    name: 'pollstar'
    properties: {
      anonymousConnectPolicy: 'allow'
    }
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
    Locations: [for loc in availabilityRegions: {
      Id: loc
    }]
    Request: {
      RequestUrl: avchk.endpoint
    }
  }
}]

output containerAppEnvironmentName string = containerAppEnvironments.name
output applicationInsightsResourceName string = applicationInsights.name
