/* This Bicep file creates a function app running in a Flex Consumption plan 
that connects to Azure Storage by using managed identities with Microsoft Entra ID. */

//********************************************
// Parameters
//********************************************

@description('Primary region for all Azure resources.')
@minLength(1)
param location string = resourceGroup().location

@description('Language runtime used by the function app.')
@allowed(['dotnet-isolated'])
param functionAppRuntime string = 'dotnet-isolated' //Defaults to .NET isolated worker

@description('Target language version used by the function app.')
@allowed(['9.0', '10'])
param functionAppRuntimeVersion string = '9.0' //Defaults to .NET 8.

@description('The maximum scale-out instance count limit for the app.')
@maxValue(2)
param maximumInstanceCount int = 1

param instanceMemoryMB int = 1024

@description('A unique token used for resource name generation.')
@minLength(3)
param resourceToken string = toLower(uniqueString(subscription().id, location))

@description('A globally unique name for your deployed function app.')
param appName string = 'func-${resourceToken}'

//********************************************
// Variables
//********************************************

// Generates a unique container name for deployments.
// 
// 
// // Key access to the storage account is disabled by default 
// var storageAccountAllowSharedKeyAccess = false
// 
// // Define the IDs of the roles we need to assign to our managed identities.
// var storageBlobDataOwnerRoleId  = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
// var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
// var storageQueueDataContributorId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
// var storageTableDataContributorId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'

var rg = resourceGroup()
var storageAccountName = 'stsqlmanagedidentity'
var deploymentStorageContainerName = 'deployment${resourceToken}'

//********************************************
// Azure resources required by your function app.
//********************************************

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
  }
}

module storage 'br/public:avm/res/storage/storage-account:0.29.0' = {
  name: 'storage'
  scope: rg
  params: {
    name: storageAccountName
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Disable local authentication methods as per policy
    dnsEndpointType: 'Standard'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    blobServices: {
      containers: [{name: deploymentStorageContainerName}]
    }
    tableServices:{}
    queueServices: {}
    minimumTlsVersion: 'TLS1_2'  // Enforcing TLS 1.2 for better security
    location: location
  }
}

module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: 'plan${resourceToken}'
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
    reserved: true
    location: location
  }
}

module functionApp 'br/public:avm/res/web/site:0.16.0' = {
  name: 'functionapp'
  scope: rg
  params: {
    kind: 'functionapp,linux'
    name: appName
    location: location
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.outputs.primaryBlobEndpoint}${deploymentStorageContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: maximumInstanceCount
        instanceMemoryMB: instanceMemoryMB
      }
      runtime: { 
        name: functionAppRuntime
        version: functionAppRuntimeVersion
      }
    }
    siteConfig: {
      alwaysOn: false
    }
    configs: [{
      name: 'appsettings'
      properties:{
        // Only include required credential settings unconditionally
        AzureWebJobsStorage__credential: 'managedidentity'
        AzureWebJobsStorage__blobServiceUri: 'https://${storage.outputs.name}.blob.${environment().suffixes.storage}'
        AzureWebJobsStorage__queueServiceUri: 'https://${storage.outputs.name}.queue.${environment().suffixes.storage}'
        AzureWebJobsStorage__tableServiceUri: 'https://${storage.outputs.name}.table.${environment().suffixes.storage}'
    }
    }]
  }
}