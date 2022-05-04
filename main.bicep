param nameseed string = 'petclinic'

param location string = resourceGroup().location

//param mySqlServerName string = ''

param mySqlServerAdminLoginName string = 'leadmin'

@secure()
@minLength(8)
param mySqlServerAdminPassword string = newGuid()

var rgUniqueString= uniqueString(resourceGroup().id, nameseed)
var rawKvName = 'kv-${nameseed}-${rgUniqueString}'
var kvName = length(rawKvName) > 24 ? substring(rawKvName,0,24) : rawKvName

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: kvName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enableRbacAuthorization: true
    tenantId: subscription().tenantId
    enableSoftDelete: false
  }
}

@description('KeyVault is being leveraged for persistance of the MySql admin password')
resource adminSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: 'mysqladminpw'
  parent: kv
  properties: {
    value: mySqlServerAdminPassword
  }
}

module vnet 'vnetdns.bicep' = {
  name: 'vnet-dns'
  params: {
    location: location
    dnsZoneName: nameseed
    virtualNetworkName: 'vnet-${nameseed}'
  }
}

module mysql 'mysqlDb.bicep' = {
  name: 'mysqlDb'
  params: {
    location: location
    administratorLogin: mySqlServerAdminLoginName
    administratorLoginPassword: mySqlServerAdminPassword
    dnsZoneFqdn: vnet.outputs.privateDnsName
    mysqlSubnetId: vnet.outputs.mysqlSubnetId
  }
}
var mysqlConnectionstring = mysql.outputs.mysqlHostname
var jdbcDatasourceUrl = mysqlConnectionstring

module containerAppEnv 'containerAppEnv.bicep' = {
  name: 'containerAppEnv'
  params: {
    location: location
    containerAppEnvName: nameseed
    infraSubnetId: vnet.outputs.cappEnvCtrlSubnetId
    runtimeSubnetId: vnet.outputs.cappEnvAppsSubnetId
  }
}

module apigw 'containerApp.bicep' = {
  name: 'app-apigw'
  params: {
    location: location
    containerAppEnvName: containerAppEnv.outputs.containerAppEnvironmentName
    containerAppName: '${nameseed}-apigw'
    containerImage: 'docker.io/springcommunity/spring-petclinic-cloud-api-gateway:latest'
    externalIngress: true
  }
}

module visits 'containerApp.bicep' = {
  name: 'app-visits'
  params: {
    location: location
    containerAppEnvName: containerAppEnv.outputs.containerAppEnvironmentName
    containerAppName: '${nameseed}-visits'
    containerImage: 'docker.io/springcommunity/spring-petclinic-cloud-visits-service:latest'
    externalIngress: false
    environmentVariables: [
      {
        name : 'SPRING_DATASOURCE_URL'
        value : jdbcDatasourceUrl
      }
      // {
      //   name : 'SPRING_DATASOURCE_URL'
      //   value : jdbcDatasourceUrl
      // }
    ]
  }
}

module vets 'containerApp.bicep' = {
  name: 'app-vets'
  params: {
    location: location
    containerAppEnvName: containerAppEnv.outputs.containerAppEnvironmentName
    containerAppName: '${nameseed}-vets'
    containerImage: 'docker.io/springcommunity/spring-petclinic-cloud-vets-service:latest'
    externalIngress: false
  }
}

module customers 'containerApp.bicep' = {
  name: 'app-customers'
  params: {
    location: location
    containerAppEnvName: containerAppEnv.outputs.containerAppEnvironmentName
    containerAppName: '${nameseed}-customers'
    containerImage: 'docker.io/springcommunity/spring-petclinic-cloud-customers-service:latest'
    externalIngress: false
  }
}
