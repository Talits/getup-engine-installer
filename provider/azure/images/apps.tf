#########################################
###### Provider
#########################################

provider "azurerm" {
    subscription_id = "${var.azure_subscription_id}"
    client_id       = "${var.azure_client_id}"
    client_secret   = "${var.azure_client_secret}"
    tenant_id       = "${var.azure_tenant_id}"
}

variable "azure_client_id" {
   type        = "string"
   description = "Azure Client ID"
}

variable "azure_client_secret" {
   type        = "string"
   description = "Azure Client Secret"
}

variable "azure_tenant_id" {
    type        = "string"
    description = "Azure Tenant ID"
}

variable "azure_subscription_id" {
    type        = "string"
    description = "Azure Subscription ID"
}

#########################################
###### Provider specific variables
#########################################

variable "app_provisioner_file" {
   type        = "string"
   description = "Script to self-join app node into openshift cluster"
}

variable "azure_instance_app" {
  type        = "string"
  description = "App VM size"
  default     = "Standard_DS2_v2"
}

#########################################
###### Common Resources
#########################################

data "azurerm_image" "app" {
    name = "app"
    resource_group_name = "${azurerm_resource_group.rg.name}"
}

#########################################
###### ScaleSet
#########################################


resource "azurerm_public_ip" "apps" {
    name                         = "apps"
    location                     = "${azurerm_resource_group.rg.location}"
    resource_group_name          = "${azurerm_resource_group.rg.name}"
    public_ip_address_allocation = "dynamic"
    domain_name_label            = "lb-${local.cluster_zone_nodot}"

    tags {
        ResourceGroup = "${azurerm_resource_group.rg.name}"
        Name          = "apps"
        Role          = "lb"
    }
}

resource "azurerm_lb" "apps" {
    name                = "apps"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    frontend_ip_configuration {
        name                 = "PublicIPAddress"
        public_ip_address_id = "${azurerm_public_ip.apps.id}"
    }
}

resource "azurerm_lb_backend_address_pool" "apps" {
    name                = "apps"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    loadbalancer_id     = "${azurerm_lb.apps.id}"
}

resource "azurerm_lb_nat_pool" "apps" {
    count                          = 3
    resource_group_name            = "${azurerm_resource_group.rg.name}"
    name                           = "ssh"
    loadbalancer_id                = "${azurerm_lb.apps.id}"
    protocol                       = "Tcp"
    frontend_port_start            = 50000
    frontend_port_end              = 50119
    backend_port                   = 22
    frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_virtual_machine_scale_set" "apps" {
    name                = "apps"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    upgrade_policy_mode = "Manual"

    sku {
        name     = "${var.azure_instance_app}"
        tier     = "Standard"
        capacity = 2
    }

    storage_profile_image_reference {
        id = "${data.azurerm_image.app.id}"
    }

    storage_profile_data_disk {
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_profile_data_disk {
        caching             = "ReadWrite"
        create_option       = "FromImage"
        managed_disk_type   = "Standard_LRS"
        disk_size_gb        = 100
        lun                 = 0
    }

    storage_profile_data_disk {
        caching             = "ReadWrite"
        create_option       = "FromImage"
        managed_disk_type   = "Premium_LRS"
        disk_size_gb        = 200
        lun                 = 1
    }

    os_profile {
        computer_name_prefix    = "apps"
        admin_username          = "${var.user}"
        custom_data             = "/provision.sh"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys {
            path     = "/home/${var.user}/.ssh/authorized_keys"
            key_data = "${var.azure_user_public_key}"
        }
    }

    network_profile {
        name    = "apps"
        primary = true

        ip_configuration {
            name                                   = "apps"
            subnet_id                              = "${azurerm_subnet.apps.id}"
            load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.apps.id}"]
            load_balancer_inbound_nat_rules_ids    = ["${element(azurerm_lb_nat_pool.apps.*.id, count.index)}"]
        }
    }

    tags {
        environment = "staging"
    }
}

