#########################################
###### Provider
#########################################

provider "azurerm" {
  subscription_id = "${var.azure_subscription_id}"
  version         = "1.6.0"
#  client_id       = "${var.azure_client_id}"
#  client_secret   = "${var.azure_client_secret}"
#  tenant_id       = "${var.azure_tenant_id}"
}

provider "random" {
    version = "~> 1.2"
}

#variable "azure_client_id" {
#  type        = "string"
#  description = "Azure Client ID"
#}
#
#variable "azure_client_secret" {
#  type        = "string"
#  description = "Azure Client Secret"
#}
#
#variable "azure_tenant_id" {
#  type        = "string"
#  description = "Azure Tenant ID"
#}

variable "azure_subscription_id" {
  type        = "string"
  description = "Azure Subscription ID"
}

#########################################
###### Common Variables
#########################################

variable "master_count" {
    default = 1
}

variable "infra_count" {
    default = 1
}

variable "app_count" {
    default = 1
}

variable "cluster_zone" {
    type    = "string"
    #default = "infra.getupcloud.com"
    description = "Cluster DNS zone (API)"
}

variable "apps_zone" {
    type    = "string"
    #default = "getup.io"
    description = "Cluster apps DNS zone"
}

variable "user" {
    type    = "string"
    default = "centos"
    description = "Username for login"
}

variable "cluster_id" {
    type    = "string"
}

#########################################
###### Provider specific variables
#########################################

variable "azure_location" {
  type        = "string"
  description = "Azure location for deployment"
}

variable "azure_resource_group" {
  type        = "string"
  description = "Azure resource group"
}

variable "azure_instance_bastion" {
  type        = "string"
  description = "Bastion VM size"
  default     = "Standard_DS1_v2"
}

variable "azure_instance_master" {
  type        = "string"
  description = "Master VM size"
  default     = "Standard_DS2_v2"
}

variable "azure_instance_infra" {
  type        = "string"
  description = "Infra VM size"
  default     = "Standard_DS2_v2"
}

variable "azure_instance_app" {
  type        = "string"
  description = "App VM size"
  default     = "Standard_DS2_v2"
}

variable "azure_user_public_key" {
  type        = "string"
  description = "SSH Public key content (not file)"
}


#########################################
###### Common Resources
#########################################

resource "random_string" "suffix" {
    length  = 16
    special = false
    upper   = false
}

data "azurerm_resource_group" "rg" {
  name     = "${var.azure_resource_group}"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  location            = "${data.azurerm_resource_group.rg.location}"
  address_space       = ["10.0.0.0/8"]
}

data "azurerm_image" "bastion" {
    name = "bastion"
    resource_group_name = "${data.azurerm_resource_group.rg.name}"
}

data "azurerm_image" "node" {
    name = "node"
    resource_group_name = "${data.azurerm_resource_group.rg.name}"
}

locals {
    cluster_zone_nodot = "${replace(var.cluster_zone, ".", "-")}"
    resource_group_dns = "${replace(var.azure_resource_group, "_", "-")}"
    portal_endpoint = "portal.${var.cluster_zone}"
    gapi_endpoint = "gapi.${var.cluster_zone}"
    usage_endpoint = "usage.${var.cluster_zone}"
    bastion_endpoint = "bastion.${var.cluster_zone}"
}

#########################################
###### Bastion
#########################################

resource "azurerm_subnet" "bastion" {
  name                      = "bastion"
  resource_group_name       = "${data.azurerm_resource_group.rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  network_security_group_id = "${azurerm_network_security_group.bastion.id}"
  address_prefix            = "10.1.0.0/16"
}

resource "azurerm_network_security_group" "bastion" {
  name                = "bastion"
  location            = "${data.azurerm_resource_group.rg.location}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "allowSSHin_all"
    description                = "Allow SSH in from all locations"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "bastion" {
  name                          = "bastion"
  location                      = "${data.azurerm_resource_group.rg.location}"
  resource_group_name           = "${data.azurerm_resource_group.rg.name}"
  public_ip_address_allocation  = "static"
  domain_name_label            = "bastion-${local.cluster_zone_nodot}"
}

resource "azurerm_network_interface" "bastion" {
  name                      = "bastion"
  location                  = "${data.azurerm_resource_group.rg.location}"
  resource_group_name       = "${data.azurerm_resource_group.rg.name}"
  network_security_group_id = "${azurerm_network_security_group.bastion.id}"

  ip_configuration {
    name                                    = "configuration-${count.index}"
    subnet_id                               = "${azurerm_subnet.bastion.id}"
    private_ip_address_allocation           = "dynamic"
    public_ip_address_id                    = "${azurerm_public_ip.bastion.id}"
  }
}

resource "azurerm_virtual_machine" "bastion" {
    name                  = "bastion"
    location              = "${data.azurerm_resource_group.rg.location}"
    resource_group_name   = "${data.azurerm_resource_group.rg.name}"
    network_interface_ids = ["${element(azurerm_network_interface.bastion.*.id, count.index)}"]
    vm_size               = "${var.azure_instance_bastion}"

    storage_image_reference {
        id = "${data.azurerm_image.bastion.id}"
    }

    storage_os_disk {
        name              = "bastion-osdisk-${random_string.suffix.result}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    os_profile {
        computer_name  = "bastion"
        admin_username = "${var.user}"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys {
            path     = "/home/${var.user}/.ssh/authorized_keys"
            key_data = "${var.azure_user_public_key}"
        }
    }

    tags {
        ResourceGroup = "${data.azurerm_resource_group.rg.name}"
        Name          = "bastion"
    }
}

#########################################
###### Master
#########################################

resource "azurerm_virtual_machine" "masters" {
    name                  = "master-${count.index + 1}"
    count                 = "${var.master_count}"
    location              = "${data.azurerm_resource_group.rg.location}"
    resource_group_name   = "${data.azurerm_resource_group.rg.name}"
    network_interface_ids = ["${element(azurerm_network_interface.master.*.id, count.index)}"]
    availability_set_id   = "${azurerm_availability_set.master.id}"
    vm_size               = "${var.azure_instance_master}"

    delete_os_disk_on_termination       = true
    delete_data_disks_on_termination    = true

    lifecycle {
        ignore_changes = [ "storage_data_disk", "tags" ]
    }

    storage_image_reference {
        id = "${data.azurerm_image.node.id}"
    }

    storage_os_disk {
        name              = "master-osdisk-${count.index + 1}-${random_string.suffix.result}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_data_disk {
        name                = "master-datadisk-container-${count.index + 1}-${random_string.suffix.result}"
        caching             = "ReadWrite"
        create_option       = "FromImage"
        managed_disk_type   = "Standard_LRS"
        disk_size_gb        = 100
        lun                 = 0
    }

    storage_data_disk {
        name                = "master-datadisk-docker-${count.index + 1}-${random_string.suffix.result}"
        caching             = "ReadWrite"
        create_option       = "FromImage"
        managed_disk_type   = "Standard_LRS"
        disk_size_gb        = 200
        lun                 = 1
    }

    os_profile {
        computer_name  = "master-${count.index + 1}"
        admin_username = "${var.user}"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys {
            path     = "/home/${var.user}/.ssh/authorized_keys"
            key_data = "${var.azure_user_public_key}"
        }
    }

    tags {
        ResourceGroup = "${data.azurerm_resource_group.rg.name}"
        Name          = "master-${count.index + 1}"
        Role          = "master"
    }

}

resource "azurerm_availability_set" "master" {
    name                = "master"
    location            = "${data.azurerm_resource_group.rg.location}"
    resource_group_name = "${data.azurerm_resource_group.rg.name}"
    managed             = true
}

resource "azurerm_subnet" "master" {
    name                      = "master"
    resource_group_name       = "${data.azurerm_resource_group.rg.name}"
    virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
    network_security_group_id = "${azurerm_network_security_group.master.id}"
    address_prefix            = "10.10.0.0/16"
}

resource "azurerm_network_interface" "master" {
    name                      = "master-${count.index + 1}"
    count                     = "${var.master_count}"
    location                  = "${data.azurerm_resource_group.rg.location}"
    resource_group_name       = "${data.azurerm_resource_group.rg.name}"
    network_security_group_id = "${azurerm_network_security_group.master.id}"

    ip_configuration {
        name                                    = "configuration-${count.index + 1}"
        subnet_id                               = "${azurerm_subnet.master.id}"
        private_ip_address_allocation           = "dynamic"
        public_ip_address_id                    = "${element(azurerm_public_ip.master.*.id, count.index)}"
    }
}

resource "azurerm_public_ip" "master" {
    name                         = "master-${count.index + 1}"
    location                     = "${data.azurerm_resource_group.rg.location}"
    resource_group_name          = "${data.azurerm_resource_group.rg.name}"
    public_ip_address_allocation = "dynamic"
    domain_name_label            = "master-${count.index + 1}-${local.cluster_zone_nodot}"
    count                        = "${var.master_count}"
}

resource "azurerm_network_security_group" "master" {
    name                = "master"
    location            = "${data.azurerm_resource_group.rg.location}"
    resource_group_name = "${data.azurerm_resource_group.rg.name}"

    security_rule {
      name                       = "allowSSH_in"
      description                = "Allow SSH in from bastion"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "${azurerm_subnet.bastion.address_prefix}"
      destination_address_prefix = "*"
    }

    security_rule {
      name                       = "master_master_443"
      description                = "Allow HTTPS connections from all locations"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }

    security_rule {
      name                       = "master_node_443"
      description                = "Allow HTTPS connections from node"
      priority                   = 300
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.2.0.0/16"
      destination_address_prefix = "*"
    }

    security_rule {
      name                       = "master_node_8054"
      description                = "Allow connections from node"
      priority                   = 400
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8054"
      source_address_prefix      = "10.2.0.0/16"
      destination_address_prefix = "*"
    }

    security_rule {
      name                       = "master_node_24224"
      description                = "Allow connections from node"
      priority                   = 500
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "24224"
      source_address_prefix      = "10.2.0.0/16"
      destination_address_prefix = "*"
    }

    security_rule {
      name                       = "master_node_8053"
      description                = "Allow connections from node"
      priority                   = 600
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_port_range          = "*"
      destination_port_range     = "8053"
      source_address_prefix      = "10.2.0.0/16"
      destination_address_prefix = "*"
    }

    security_rule {
      name                       = "etcd_etcd_2379"
      description                = "Allow connections for etcd between masters"
      priority                   = 700
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "2379"
      source_address_prefix      = "10.1.0.0/16"
      destination_address_prefix = "10.1.0.0/16"
    }
}

#########################################
###### Infra
#########################################

resource "azurerm_virtual_machine" "infras" {
    name                  = "infra-${count.index + 1}"
    count                 = "${var.infra_count}"
    location              = "${data.azurerm_resource_group.rg.location}"
    resource_group_name   = "${data.azurerm_resource_group.rg.name}"
    network_interface_ids = ["${element(azurerm_network_interface.infra.*.id, count.index)}"]
    availability_set_id   = "${azurerm_availability_set.infra.id}"
    vm_size               = "${var.azure_instance_infra}"

    delete_os_disk_on_termination       = true
    delete_data_disks_on_termination    = true

    lifecycle {
        ignore_changes = [ "storage_data_disk", "tags" ]
    }

    storage_image_reference {
        id = "${data.azurerm_image.node.id}"
    }

    storage_os_disk {
        name              = "infra-osdisk-${count.index + 1}-${random_string.suffix.result}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_data_disk {
        name                = "infra-datadisk-container-${count.index + 1}-${random_string.suffix.result}"
        caching             = "ReadWrite"
        create_option       = "FromImage"
        managed_disk_type   = "Standard_LRS"
        disk_size_gb        = 100
        lun                 = 0
    }

    storage_data_disk {
        name                = "infra-datadisk-docker-${count.index + 1}-${random_string.suffix.result}"
        caching             = "ReadWrite"
        create_option       = "FromImage"
        managed_disk_type   = "Standard_LRS"
        disk_size_gb        = 200
        lun                 = 1
    }

    os_profile {
        computer_name  = "infra-${count.index + 1}"
        admin_username = "${var.user}"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys {
            path     = "/home/${var.user}/.ssh/authorized_keys"
            key_data = "${var.azure_user_public_key}"
        }
    }

    tags {
        ResourceGroup = "${data.azurerm_resource_group.rg.name}"
        Name          = "infra-${count.index + 1}"
        Role          = "infra"
    }
}

resource "azurerm_availability_set" "infra" {
    name                = "infra"
    location            = "${data.azurerm_resource_group.rg.location}"
    resource_group_name = "${data.azurerm_resource_group.rg.name}"
    managed             = true
}

resource "azurerm_subnet" "infra" {
    name                      = "infra"
    resource_group_name       = "${data.azurerm_resource_group.rg.name}"
    virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
    network_security_group_id = "${azurerm_network_security_group.infra.id}"
    address_prefix            = "10.20.0.0/16"
}

resource "azurerm_network_interface" "infra" {
    name                      = "infra-${count.index + 1}"
    count                     = "${var.infra_count}"
    location                  = "${data.azurerm_resource_group.rg.location}"
    resource_group_name       = "${data.azurerm_resource_group.rg.name}"
    network_security_group_id = "${azurerm_network_security_group.infra.id}"

    ip_configuration {
        name                                    = "configuration-${count.index + 1}"
        subnet_id                               = "${azurerm_subnet.infra.id}"
        private_ip_address_allocation           = "dynamic"
        public_ip_address_id                    = "${element(azurerm_public_ip.infra.*.id, count.index)}"
    }
}

resource "azurerm_public_ip" "infra" {
    name                         = "infra-${count.index + 1}"
    location                     = "${data.azurerm_resource_group.rg.location}"
    resource_group_name          = "${data.azurerm_resource_group.rg.name}"
    public_ip_address_allocation = "dynamic"
    domain_name_label            = "infra-${count.index + 1}-${local.cluster_zone_nodot}"
    count                        = "${var.infra_count}"
}

resource "azurerm_network_security_group" "infra" {
    name                = "infra"
    location            = "${data.azurerm_resource_group.rg.location}"
    resource_group_name = "${data.azurerm_resource_group.rg.name}"

    security_rule {
        name                       = "allowSSH_in"
        description                = "Allow SSH in from bastion"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "${azurerm_subnet.bastion.address_prefix}"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "infra_infra_80"
        description                = "Allow connections from http"
        priority                   = 200
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "infra_infra_443"
        description                = "Allow connections from https"
        priority                   = 300
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "node_infra_prometheus_haproxy_1936"
        description                = "Allow connections from prometheus on nodes"
        priority                   = 400
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "1936"
        source_address_prefix      = "10.2.0.0/16"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "infra_infra_prometheus_haproxy_1936"
        description                = "Allow connections from prometheus"
        priority                   = 500
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "1936"
        source_address_prefix      = "10.3.0.0/16"
        destination_address_prefix = "10.3.0.0/16"
    }
}

#########################################
###### App
#########################################


resource "azurerm_virtual_machine" "apps" {
    name                  = "app-${count.index + 1}"
    count                 = "${var.app_count}"
    location              = "${data.azurerm_resource_group.rg.location}"
    resource_group_name   = "${data.azurerm_resource_group.rg.name}"
    network_interface_ids = ["${element(azurerm_network_interface.app.*.id, count.index)}"]
    availability_set_id   = "${azurerm_availability_set.app.id}"
    vm_size               = "${var.azure_instance_app}"

    delete_os_disk_on_termination       = true
    delete_data_disks_on_termination    = true

    lifecycle {
        ignore_changes = [ "storage_data_disk", "tags" ]
    }

    storage_image_reference {
        id = "${data.azurerm_image.node.id}"
    }

    storage_os_disk {
        name              = "app-osdisk-${count.index + 1}-${random_string.suffix.result}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_data_disk {
        name                = "app-datadisk-container-${count.index + 1}-${random_string.suffix.result}"
        caching             = "ReadWrite"
        create_option       = "FromImage"
        managed_disk_type   = "Standard_LRS"
        disk_size_gb        = 100
        lun                 = 0
    }

    storage_data_disk {
        name                = "app-datadisk-docker-${count.index + 1}-${random_string.suffix.result}"
        caching             = "ReadWrite"
        create_option       = "FromImage"
        managed_disk_type   = "Premium_LRS"
        disk_size_gb        = 200
        lun                 = 1
    }

    os_profile {
        computer_name  = "app-${count.index + 1}"
        admin_username = "${var.user}"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys {
            path     = "/home/${var.user}/.ssh/authorized_keys"
            key_data = "${var.azure_user_public_key}"
        }
    }

    tags {
        ResourceGroup = "${data.azurerm_resource_group.rg.name}"
        Name          = "app-${count.index + 1}"
        Role          = "app"
    }
}

resource "azurerm_availability_set" "app" {
    name                = "app"
    location            = "${data.azurerm_resource_group.rg.location}"
    resource_group_name = "${data.azurerm_resource_group.rg.name}"
    managed             = true
}

resource "azurerm_network_interface" "app" {
   name                      = "app-${count.index + 1}"
   count                     = "${var.app_count}"
   location                  = "${data.azurerm_resource_group.rg.location}"
   resource_group_name       = "${data.azurerm_resource_group.rg.name}"
   network_security_group_id = "${azurerm_network_security_group.node.id}"

   ip_configuration {
        name                                    = "configuration-${count.index + 1}"
        subnet_id                               = "${azurerm_subnet.app.id}"
        private_ip_address_allocation           = "dynamic"
    }
}

resource "azurerm_subnet" "app" {
    name                      = "app"
    resource_group_name       = "${data.azurerm_resource_group.rg.name}"
    virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
    network_security_group_id = "${azurerm_network_security_group.node.id}"
    address_prefix            = "10.30.0.0/16"
}


resource "azurerm_network_security_group" "node" {
  name                = "node"
  location            = "${data.azurerm_resource_group.rg.location}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "allowSSH_in"
    description                = "Allow SSH in from bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${azurerm_subnet.bastion.address_prefix}"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "node_master_10250"
    description                = "Allow connect from master"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "node_node_10250"
    description                = "Allow connect from node"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "10.2.0.0/16"
    destination_address_prefix = "*"
  }


  security_rule {
    name                       = "node_node_4789"
    description                = "Allow connect from node"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4789"
    source_address_prefix      = "10.2.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "node_prometheus_node_exporter_9100"
    description                = "Allow connect from node"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefix      = "10.2.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "infra_node_prometheus_node_exporter_9100"
    description                = "Allow connect for infra"
    priority                   = 600
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefix      = "10.3.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "infra_infra_prometheus_node_exporter_9100"
    description                = "Allow connect for infra"
    priority                   = 700
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefix      = "10.3.0.0/16"
    destination_address_prefix = "10.3.0.0/16"
  }

}

#########################################
###### Traffic Manager - api_external
#########################################

resource "azurerm_traffic_manager_profile" "api-external" {
  name                   = "api-external"
  resource_group_name    = "${data.azurerm_resource_group.rg.name}"
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "${lower("api-external-${local.resource_group_dns}-${random_string.suffix.result}")}"
    ttl           = 30
  }

  monitor_config {
    protocol = "https"
    port     = 443
    path     = "/"
  }
}

resource "azurerm_traffic_manager_endpoint" "api-endpoint" {
  count               = "${var.master_count}"
  name                = "master-${count.index + 1}-${random_string.suffix.result}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  profile_name        = "${azurerm_traffic_manager_profile.api-external.name}"
  target_resource_id  = "${element(azurerm_public_ip.master.*.id, count.index)}"
  type                = "azureEndpoints"
  weight              = 1
}


#########################################
###### Traffic Manager - infra
#########################################

resource "azurerm_traffic_manager_profile" "infra" {
  name                   = "infra"
  resource_group_name    = "${data.azurerm_resource_group.rg.name}"
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "${lower("infra-${local.resource_group_dns}-${random_string.suffix.result}")}"
    ttl           = 30
  }

  monitor_config {
    protocol = "https"
    port     = 443
    path     = "/"
  }
}

resource "azurerm_traffic_manager_endpoint" "infra-endpoint" {
  count               = "${var.infra_count}"
  name                = "infra-${count.index + 1 }-${random_string.suffix.result}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  profile_name        = "${azurerm_traffic_manager_profile.infra.name}"
  target_resource_id  = "${element(azurerm_public_ip.infra.*.id, count.index)}"
  type                = "azureEndpoints"
  weight              = 1
}

#########################################
###### DNS - APPS
#########################################

resource "azurerm_dns_zone" "apps" {
  name                = "${var.apps_zone}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
}

resource "azurerm_dns_cname_record" "infra-apps-cname" {
  name                = "infra"
  zone_name           = "${azurerm_dns_zone.apps.name}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  ttl                 = 300
  record              = "${azurerm_traffic_manager_profile.infra.fqdn}"
}

resource "azurerm_dns_cname_record" "infra-apps-wildcard" {
  name                = "*"
  zone_name           = "${azurerm_dns_zone.apps.name}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  ttl                 = 300
  record              = "${azurerm_traffic_manager_profile.infra.fqdn}"
}

#########################################
###### DNS - CLUSTER
#########################################

resource "azurerm_dns_zone" "cluster" {
  name                = "${var.cluster_zone}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
}

resource "azurerm_dns_a_record" "bastion-A" {
  name                = "bastion"
  zone_name           = "${azurerm_dns_zone.cluster.name}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  ttl                 = 300
  records             = ["${azurerm_public_ip.bastion.ip_address}"]
  depends_on          = ["azurerm_virtual_machine.bastion"]
}

resource "azurerm_dns_cname_record" "api-CNAME" {
  name                = "api"
  zone_name           = "${azurerm_dns_zone.cluster.name}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  ttl                 = 300
  record              = "${azurerm_traffic_manager_profile.api-external.fqdn}"
}

resource "azurerm_dns_cname_record" "portal-CNAME" {
  name                = "portal"
  zone_name           = "${azurerm_dns_zone.cluster.name}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  ttl                 = 300
  record              = "${azurerm_traffic_manager_profile.infra.fqdn}"
}

resource "azurerm_dns_cname_record" "gapi-CNAME" {
  name                = "gapi"
  zone_name           = "${azurerm_dns_zone.cluster.name}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  ttl                 = 300
  record              = "${azurerm_traffic_manager_profile.infra.fqdn}"
}

resource "azurerm_dns_cname_record" "usage-CNAME" {
  name                = "usage"
  zone_name           = "${azurerm_dns_zone.cluster.name}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  ttl                 = 300
  record              = "${azurerm_traffic_manager_profile.infra.fqdn}"
}


#########################################
###### Registry
#########################################

resource "azurerm_storage_account" "registry" {
  name                  = "registry${random_string.suffix.result}"
  location              = "${data.azurerm_resource_group.rg.location}"
  resource_group_name   = "${data.azurerm_resource_group.rg.name}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "registry" {
  name                  = "registry"
  resource_group_name   = "${data.azurerm_resource_group.rg.name}"
  storage_account_name  = "${azurerm_storage_account.registry.name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "registry" {
  name = "registry"

  resource_group_name   = "${data.azurerm_resource_group.rg.name}"
  storage_account_name   = "${azurerm_storage_account.registry.name}"
  storage_container_name = "${azurerm_storage_container.registry.name}"

  type = "block"
}


#################################################################
## Outputs
#################################################################

output "CLUSTER_ZONE" {
    value = "${var.cluster_zone}"
}

output "APPS_ZONE" {
    value = "${var.apps_zone}"
}

output "AZURE_LOCATION" {
    value = "${var.azure_location}"
}

output "CLUSTER_REGION" {
    value = "${var.azure_location}"
}

output "DEFAULT_USER" {
    value = "${var.user}"
}

output "CLUSTER_ID" {
    value = "${var.cluster_id}"
}

# Endpoints
###########

output "API_ENDPOINT" {
    value = "api.${var.cluster_zone}"
}

output "API_ENDPOINT_INTERNAL" {
    value = "${azurerm_traffic_manager_profile.api-external.fqdn}"
}

output "PORTAL_ENDPOINT" {
    value = "${local.portal_endpoint}"
}

output "GAPI_ENDPOINT" {
    value = "${local.gapi_endpoint}"
}

output "USAGE_ENDPOINT" {
    value = "${local.usage_endpoint}"
}

output "INFRA_ENDPOINT" {
    value = "${azurerm_traffic_manager_profile.infra.fqdn}"
}

output "BASTION_ENDPOINT" {
    value = "${local.bastion_endpoint}"
}

output "MASTER_HOSTNAMES" {
    value = "${azurerm_virtual_machine.masters.*.name}"
}

output "INFRA_HOSTNAMES" {
    value = "${azurerm_virtual_machine.infras.*.name}"
}

output "APP_HOSTNAMES" {
    value = "${azurerm_virtual_machine.apps.*.name}"
}

output "CLUSTER_ZONE_NAMES_SERVERS" {
    value = "${azurerm_dns_zone.cluster.name_servers}"
}

output "APPS_ZONE_NAMES_SERVERS" {
    value = "${azurerm_dns_zone.apps.name_servers}"
}

# Registry
##########

output "REGISTRY_STORAGE_PROVIDER" {
    value = "azure_blob"
}

output "REGISTRY_AZURE_ACCOUNT_NAME" {
    value = "${azurerm_storage_account.registry.name}"
}

output "REGISTRY_AZURE_CONTAINER" {
    value = "${azurerm_storage_container.registry.name}"
}

output "REGISTRY_AZURE_ACCESS_KEY" {
    value = "${azurerm_storage_account.registry.primary_access_key}"
}
