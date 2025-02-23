terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.56.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "codility"
  location = "West Europe"
}


resource "azurerm_storage_account" "upload_storage_account" {
  name                     = "uploadstorageaccount"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "upload_container" {
  name                  = "upload-container"
  storage_account_id  = azurerm_storage_account.upload_storage_account.id
  container_access_type = "blob"
}
resource "azurerm_servicebus_namespace" "upload_queue_ns" {
  name                = "upload-queue-ns"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

}
resource "azurerm_servicebus_queue" "upload_queue" {
  name                = "upload-queue"
  namespace_id = azurerm_servicebus_namespace.upload_queue_ns.id
  partitioning_enabled = true
}
resource "azurerm_eventgrid_event_subscription" "upload_subscription" {
  name  = "upload-event-subscription"
  scope = azurerm_storage_container.upload_container.id
  service_bus_queue_endpoint_id = azurerm_servicebus_queue.upload_queue.id
  included_event_types = ["Microsoft.Storage.BlobCreated"]
}
