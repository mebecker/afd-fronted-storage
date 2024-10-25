param resourceGroupNamePrefix string = 'rg-afd-storage-poc'
param storageAccountNamePrefix string = 'sa'
param frontDoorNameprefix string = 'afd'
param logAnalyticsWorkspaceNameprefix string = 'log'
param location string = 'centralus'
param allowedIpAddresses array = []

var unique = uniqueString(subscription().id)

var resourceGroupName = '${resourceGroupNamePrefix}-${unique}'
var storageAccountName = '${storageAccountNamePrefix}${unique}'
var frontDoorName = '${frontDoorNameprefix}${unique}'
var logAnalyticsWorkspaceName = '${logAnalyticsWorkspaceNameprefix}-${unique}'

targetScope = 'subscription'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module logAnalytics './modules/logAnalytics.bicep' = {
  scope: resourceGroup
  name: 'logAnalytics'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
}

module storageAccount './modules/storage.bicep' = {
  scope: resourceGroup
  name: 'storageAccount'
  params: {
    storageAccountName: storageAccountName
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

module frontDoor './modules/frontDoor.bicep' = {
  scope: resourceGroup
  name: 'frontDoor'
  params: {
    frontDoorName: frontDoorName
    storageAccountId: storageAccount.outputs.storageAccountId
    storageAccountBlobEndpoint: replace(replace(storageAccount.outputs.storageAccountBlobEndpoint, 'https://', ''), '/', '')
    allowedIpAddresses: allowedIpAddresses
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

output resourceGroupName string = resourceGroupName
output storageAccountName string = storageAccountName
output frontDoorName string = frontDoorName
output frontDoorUrl string = frontDoor.outputs.frontDoorUrl



