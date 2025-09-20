terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "2.4.0"
    }
  }
}

provider "azapi" {}

resource "azapi_resource" "resource_group" {
  type     = "Microsoft.Resources/resourceGroups@2025-04-01"
  name     = "rg-${var.environment}-${var.location_short}-pe"
  location = var.location
}

resource "azapi_resource" "storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2025-01-01"
  name      = "sa${var.environment}${var.location_short}<insert_random_suffix_here>"
  parent_id = azapi_resource.resource_group.id
  location  = var.location
  body = {
    properties = {
      publicNetworkAccess = "Disabled"
    }
    sku = {
      name = "Premium_ZRS"
    }
    kind = "StorageV2"
  }
  schema_validation_enabled = false
}

resource "azapi_resource" "virtual_network" {
  type      = "Microsoft.Network/virtualnetworks@2023-11-01"
  name      = "vnet-${var.environment}-${var.location_short}-pe"
  parent_id = azapi_resource.resource_group.id
  location  = var.location
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/24"]
      }
    }
  }
  schema_validation_enabled = false
}

locals {
  subnet_config = [
    {
      name          = "client"
      addressPrefix = "10.0.0.0/26"
    },
    {
      name          = "private-endpoint"
      addressPrefix = "10.0.0.64/26"
    }
  ]
}

resource "azapi_resource" "subnet" {
  for_each  = { for subnet in local.subnet_config : subnet.name => subnet }
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-07-01"
  parent_id = azapi_resource.virtual_network.id
  name      = each.value.name
  body = {
    properties = {
      addressPrefix = each.value.addressPrefix
    }
  }
  schema_validation_enabled = false
}

resource "azapi_resource" "private_endpoint_storage" {
  type      = "Microsoft.Network/privateEndpoints@2024-07-01"
  name      = "pe-${var.environment}-${var.location_short}-sa"
  parent_id = azapi_resource.resource_group.id
  location  = var.location
  body = {
    properties = {
      subnet = {
        id = azapi_resource.subnet["private-endpoint"].id
      }
      privateLinkServiceConnections = [
        {
          name = "pe-${var.environment}-${var.location_short}-sa"
          properties = {
            privateLinkServiceId = azapi_resource.storage_account.id
            groupIds             = ["blob"]
          }
        }
      ]
      customNetworkInterfaceName = "nic-${var.environment}-${var.location_short}-pe"
    }
  }
  schema_validation_enabled = false
}

resource "azapi_resource" "private_dns_zone_blob" {
  type      = "Microsoft.Network/privateDnsZones@2024-06-01"
  name      = "privatelink.blob.core.windows.net"
  parent_id = azapi_resource.resource_group.id
  location  = "global"
}

resource "azapi_resource" "private_dns_zone_blob_a_record" {
  type      = "Microsoft.Network/privateDnsZones/A@2024-06-01"
  name      = azapi_resource.storage_account.name
  parent_id = azapi_resource.private_dns_zone_blob.id
  body = {
    properties = {
      aRecords = [
        {
          ipv4Address = "10.0.0.68"
        },
      ]
      ttl = 300
    }
  }
  schema_validation_enabled = false
}

resource "azapi_resource" "private_dns_zone_blob_vnet_link" {
  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01"
  name      = "link-${var.environment}-${var.location_short}-pe-blob"
  parent_id = azapi_resource.private_dns_zone_blob.id
  location  = "global"
  body = {
    properties = {
      registrationEnabled = false
      virtualNetwork = {
        id = azapi_resource.virtual_network.id
      }
    }
  }
}
