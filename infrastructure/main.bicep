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

var integrationResourceGroupName = toLower('${systemName}-${environmentName}-${locationAbbreviation}')

resource integrationResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: integrationResourceGroupName
  location: location
}

module integrationModule 'integration.bicep' = {
  name: 'IntegrationModule'
  scope: integrationResourceGroup
  params: {
    defaultResourceName: toLower('${systemName}-int-${environmentName}-${locationAbbreviation}')
    location: location
  }
}