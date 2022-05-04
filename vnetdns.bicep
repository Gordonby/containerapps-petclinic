@description('Name for DNS Private Zone')
param dnsZoneName string 

@description('Fully Qualified DNS Private Zone')
param dnsZoneFqdn string = '${dnsZoneName}.private.mysql.database.azure.com'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Virtual Network Name')
param virtualNetworkName string

@description('MySql Subnet Name')
param mySqlSubnetName string = 'snet-mysql'

@description('MySql Subnet Name')
param cappEnvCtrlSubnetName string = 'snet-capps-ctrl'

@description('MySql Subnet Name')
param cappEnvAppsSubnetName string = 'snet-capps-apps'

@description('Virtual Network Address Prefix')
param vnetAddressPrefix string = '10.0.0.0/19'

@description('Subnet Address Prefix for MySql subnet')
param mySqlSubnetPrefix string = '10.0.16.0/28'

@description('Subnet for control plane infrastructure components')
param cappEnvCtrlSubnetPrefix string = '10.0.0.0/21'

@description('Subnet for user app containers.')
param cappEnvAppsSubnetPrefix string = '10.0.8.0/21'

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: mySqlSubnetName
        properties: {
          addressPrefix: mySqlSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: [
            {
              name: 'dlg-Microsoft.DBforMySQL-flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforMySQL/flexibleServers'
              }
            }
          ]
        }
      }
      {
        name: cappEnvCtrlSubnetName
        properties: {
          addressPrefix: cappEnvCtrlSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: cappEnvAppsSubnetName
        properties: {
          addressPrefix: cappEnvAppsSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource dnszone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneFqdn
  location: 'global'
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: vnet.name
  parent: dnszone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

var mysqlSubnetId =  '${vnetLink.properties.virtualNetwork.id}/subnets/${mySqlSubnetName}'
var cappEnvCtrlSubnetId =  '${vnetLink.properties.virtualNetwork.id}/subnets/${cappEnvCtrlSubnetName}'
var cappEnvAppsSubnetId =  '${vnetLink.properties.virtualNetwork.id}/subnets/${cappEnvAppsSubnetName}'

output mysqlSubnetId string = mysqlSubnetId
output cappEnvCtrlSubnetId string = cappEnvCtrlSubnetId
output cappEnvAppsSubnetId string = cappEnvAppsSubnetId
output vnetId string = vnet.id
output privateDnsId string = dnszone.id
output privateDnsName string = dnszone.name
