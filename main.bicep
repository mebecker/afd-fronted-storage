param resourceGroupNamePrefix string = 'rg-afd-storage-poc'
param storageAccountNamePrefix string = 'sa'
param frontDoorNameprefix string = 'afd'
param location string = 'centralus'
param allowedIpAddresses array = []

var unique = uniqueString(subscription().id)

var resourceGroupName = '${resourceGroupNamePrefix}-${unique}'
var storageAccountName = '${storageAccountNamePrefix}${unique}'
var frontDoorName = '${frontDoorNameprefix}${unique}'

targetScope = 'subscription'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module storageAccount 'storage.bicep' = {
  scope: resourceGroup
  name: 'storageAccount'
  params: {
    storageAccountName: storageAccountName
    location: location
  }
}

module frontDoor 'frontDoor.bicep' = {
  scope: resourceGroup
  name: 'frontDoor'
  params: {
    frontDoorName: frontDoorName
    storageAccountId: storageAccount.outputs.storageAccountId
    storageAccountBlobEndpoint: replace(replace(storageAccount.outputs.storageAccountBlobEndpoint, 'https://', ''), '/', '')
    allowedIpAddresses: allowedIpAddresses
  }
}

output frontDoorUrl string = frontDoor.outputs.frontDoorUrl


