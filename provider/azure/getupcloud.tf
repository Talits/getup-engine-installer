#########################################
###### Getup API
#########################################

resource "azurerm_storage_account" "api" {
    name                        = "getupapi${random_string.suffix.result}"
    location                    = "${data.azurerm_resource_group.rg.location}"
    resource_group_name         = "${data.azurerm_resource_group.rg.name}"
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

resource "azurerm_storage_blob" "api" {
    name                    = "api"
    type                    = "block"
    resource_group_name     = "${data.azurerm_resource_group.rg.name}"
    storage_account_name    = "${azurerm_storage_account.api.name}"
    storage_container_name  = "${azurerm_storage_container.api.name}"
}

resource "azurerm_storage_container" "api" {
   name                     = "api"
   resource_group_name      = "${data.azurerm_resource_group.rg.name}"
   storage_account_name     = "${azurerm_storage_account.api.name}"
   container_access_type    = "container"
}

#########################################
###### Blob for Backup
#########################################

resource "azurerm_storage_account" "backup" {
    name                        = "getupbkp${random_string.suffix.result}"
    location                    = "${data.azurerm_resource_group.rg.location}"
    resource_group_name         = "${data.azurerm_resource_group.rg.name}"
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

resource "azurerm_storage_container" "backup" {
    name                    = "backup"
    resource_group_name     = "${data.azurerm_resource_group.rg.name}"
    storage_account_name    = "${azurerm_storage_account.backup.name}"
    container_access_type   = "private"
}

resource "azurerm_storage_blob" "backup" {
    name                    = "backup"
    type                    = "block"
    resource_group_name     = "${data.azurerm_resource_group.rg.name}"
    storage_account_name    = "${azurerm_storage_account.backup.name}"
    storage_container_name  = "${azurerm_storage_container.backup.name}"
}

#################################################################
## Outputs
#################################################################

# API
########

output "GETUPCLOUD_API_AZURE_STORAGE_ACCOUNT_NAME" {
    value = "${azurerm_storage_blob.api.storage_account_name}"
}

output "GETUPCLOUD_API_AZURE_STORAGE_CONTAINER_NAME" {
    value = "${azurerm_storage_container.api.name}"
}

output "GETUPCLOUD_API_AZURE_STORAGE_ACCOUNT_KEY" {
    value = "${azurerm_storage_account.api.primary_access_key}"
}

output "GETUPCLOUD_API_STORAGE_BACKEND" {
    value = "storages.backends.azure_storage.AzureStorage"
}

# Database
##########

output "GETUPCLOUD_DATABASE_MODE" {
    value = "hosted"
}

# Backup
########

output "GETUPCLOUD_BACKUP_STORAGE_AZURE_ACCOUNT_NAME" {
    value = "${azurerm_storage_blob.backup.storage_account_name}"
}

output "GETUPCLOUD_BACKUP_STORAGE_AZURE_CONTAINER" {
    value = "${azurerm_storage_container.backup.name}"
}
output "GETUPCLOUD_BACKUP_STORAGE_AZURE_ACCOUNT_KEY" {
    value = "${azurerm_storage_account.backup.primary_access_key}"
}

output "GETUPCLOUD_BACKUP_STORAGE_KIND" {
    value = "blobstorage"
}
