targetScope = 'subscription'

param systemName string

@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string
param location string = deployment().location
param locationAbbreviation string
param availabilityRegions array
param availabilityEndpoints array = [
  {
    name: 'Users endpoint'
    endpoint: 'https://pollstar-api.hexmaster.nl/users/health'
  }
  {
    name: 'Sessions endpoint'
    endpoint: 'https://pollstar-api.hexmaster.nl/sessions/health'
  }
  {
    name: 'Polls endpoint'
    endpoint: 'https://pollstar-api.hexmaster.nl/polls/health'
  }
  {
    name: 'Votes endpoint'
    endpoint: 'https://pollstar-api.hexmaster.nl/votes/health'
  }
]

var integrationResourceGroupName = toLower('${systemName}-${environmentName}-${locationAbbreviation}')

resource integrationResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: integrationResourceGroupName
  location: location
}

module integrationModule 'integration.bicep' = {
  name: 'IntegrationModule'
  scope: integrationResourceGroup
  params: {
    environmentName: environmentName
    locationAbbreviation: locationAbbreviation
    systemName: systemName
    location: location
    availabilityRegions: availabilityRegions
    availabilityEndpoints: availabilityEndpoints
  }
}
