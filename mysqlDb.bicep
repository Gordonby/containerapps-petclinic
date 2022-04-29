@description('Server Name for Azure database for MySQL')
param serverName string

@description('Name for DNS Private Zone for MySQL Server')
param dnsZoneName string = '${serverName}.private.mysql.database.azure.com'

@description('Database administrator login name')
@minLength(1)
param administratorLogin string

@description('Database administrator password')
@minLength(8)
@secure()
param administratorLoginPassword string

// @description('Azure database for MySQL compute capacity in vCores (2,4,8,16,32)')
// param skuCapacity int = 2

@description('Azure database for MySQL sku name ')
param skuName string = 'Standard_B1s'

@minValue(20)
@description('Azure database for MySQL Sku Size ')
param StorageSizeGB int = 20

@minValue(360)
param StorageIops int = 360

@description('Azure database for MySQL pricing tier')
@allowed([
  'GeneralPurpose'
  'MemoryOptimized'
  'Burstable'
])
param SkuTier string = 'Burstable'

// @description('Azure database for MySQL sku family')
// param skuFamily string = 'Gen5'

@description('MySQL version')
@allowed([
  '5.7'
  '8.0.21'
])
param mysqlVersion string = '8.0.21'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('MySQL Server backup retention days')
param backupRetentionDays int = 7

@description('Geo-Redundant Backup setting')
param geoRedundantBackup string = 'Disabled'

@description('Virtual Network Name')
param virtualNetworkName string = 'azure_mysql_vnet'

@description('Subnet Name')
param subnetName string = 'azure_mysql_subnet'

@description('Virtual Network RuleName')
param virtualNetworkRuleName string = 'AllowSubnet'

@description('Virtual Network Address Prefix')
param vnetAddressPrefix string = '10.0.0.0/24'

@description('Subnet Address Prefix')
param subnetPrefix string = '10.0.0.0/28'

var firewallrules = [
  {
    Name: 'rule1'
    StartIpAddress: '0.0.0.0'
    EndIpAddress: '255.255.255.255'
  }
  {
    Name: 'rule2'
    StartIpAddress: '0.0.0.0'
    EndIpAddress: '255.255.255.255'
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }

  resource subnet 'subnets@2021-05-01' = {
    name: subnetName
    properties: {
      addressPrefix: subnetPrefix
      delegations: [
        {
          name: 'dlg-Microsoft.DBforMySQL-flexibleServers'
          properties: {
            serviceName: 'Microsoft.DBforMySQL/flexibleServers'
          }
        }
      ]
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
}

resource dnszone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'
  
  resource dnsDbName 'A' = {
    name: serverName
    properties: {
      ttl: 30
      aRecords: [
        {
          ipv4Address: '10.0.0.4' //TODO: Work this out via subnetPrefix
        }
      ]
    }
  }
  
  resource dnsSoa 'SOA' = {
    name: '@'
    properties: {
      ttl: 3600
      soaRecord: {
        email: 'azureprivatedns-host.microsoft.com'
        expireTime: 2419200
        host: 'azureprivatedns.net'
        minimumTtl: 10
        refreshTime: 3600
        retryTime: 300
        serialNumber: 1
      }
    }
  }
  
  resource vnetLink 'virtualNetworkLinks@2020-06-01' = {
    name: 'randomcharseh'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource mysqlDbServer 'Microsoft.DBforMySQL/flexibleServers@2021-05-01' = {
  name: serverName
  location: location
  sku: {
    name: skuName
    tier: SkuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      autoGrow: 'Enabled'
      iops: StorageIops
      storageSizeGB: StorageSizeGB
    }
    createMode: 'Default'
    version: mysqlVersion
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }

  resource virtualNetworkRule 'firewallRules@2021-05-01' = [for rule in firewallrules: {
    name: rule.Name
    properties: {
      startIpAddress: rule.StartIpAddress
      endIpAddress: rule.EndIpAddress
    }
  }]
}
