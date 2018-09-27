#########################################
###### Provider & Modules
#########################################

provider "google" {
    version     = "~> 1.17"
    project     = "${var.gce_project}"
    region      = "${var.gce_region}"
}

provider "random" {
    version = "~> 1.2"
}

#########################################
###### Common Variables
#########################################

variable "openshift_release" {
    description = "Openshift Release for base image name"
}

variable "master_count" {
    default = 1
}

variable "infra_count" {
    default = 1
}

variable "app_count" {
    default = 1
}

variable "use_high_perf_disks" {
    default = true
}

variable "high_perf_disk_type" {
    default = "pd-ssd"
}

variable "cluster_zone" {
    type    = "string"
    description = "Cluster DNS zone (API)"
}

variable "apps_zone" {
    type    = "string"
    description = "Cluster apps DNS zone"
}

variable "default_user" {
    type    = "string"
    default = "centos"
    description = "Username for login"
}

variable "id_rsa_pub_file" {
    type        = "string"
    description = "Path for ssh public key"
}

variable "cluster_id" {
    type    = "string"
    description = "Cloud provider wide unique id for cluster"
}

variable "acme_enabled" {
    default = "false"
}

variable "acme_mode" {
    default = "staging"
    description = "ACME certificate URL mode: 'staging' or 'production'"
}

#########################################
###### Provider specific variables
#########################################

variable "gce_credentials" {
    type = "string"
}

variable "gce_project" {
    type = "string"
}

variable "gce_region" {
    type = "string"
}

variable "gce_zones" {
    type = "string"
}

variable "gce_instance_bastion" {
    type    = "string"
    default = "g1-small"
    description = "Instance type for bastion host"
}

variable "gce_instance_master" {
    type    = "string"
    default = "n1-standard-2"
    description = "Instance type for master node hosts"
}

variable "gce_instance_infra" {
    type    = "string"
    default = "n1-standard-4"
    description = ""
    description = "Instance type for infra node hosts"
}

variable "gce_instance_app" {
    type    = "string"
        default = "n1-standard-4"
        description = "Instance type for app node hosts"
}

variable "gce_image_bastion" {
    type    = "string"
}

variable "gce_image_master" {
    type    = "string"
}

variable "gce_image_infra" {
    type    = "string"
}

variable "gce_image_app" {
    type    = "string"
}

variable "acme_email_address" {
    default = ""
}

locals {
    gce_zones           = ["${split(" ", trimspace(var.gce_zones))}"]
    disk_type           = "${var.use_high_perf_disks == true ? var.high_perf_disk_type : "pd-standard"}"
    acme_email_address  = "${var.acme_email_address == "" ? "admin@${var.cluster_zone}" : var.acme_email_address}"
}

#########################################
###### Basic Resources
#########################################

module "vpc" {
    source      = "./modules/vpc"
    cluster_id  = "${var.cluster_id}"
}

module "dns" {
    source              = "./modules/dns"
    cluster_id          = "${var.cluster_id}"
    cluster_zone        = "${var.cluster_zone}"
    apps_zone           = "${var.apps_zone}"
    bastion_address     = "${module.bastion.address}"
    master_lb_address   = "${module.load-balancer.master_lb_address}"
    infra_lb_address    = "${module.load-balancer.infra_lb_address}"
}

#########################################
###### Main Resources
#########################################

module "firewall" {
    source      = "./modules/firewall"
    cluster_id  = "${var.cluster_id}"
    network     = "${module.vpc.network}"
}

module "cluster-cert" {
    source              = "./modules/acme"
    enabled             = "${var.acme_enabled}"
    acme_email_address  = "${local.acme_email_address}"
    zone                = "${substr(module.dns.cluster_zone, 0, length(module.dns.cluster_zone) - 1)}"
    gce_project         = "${var.gce_project}"
    gce_credentials     = "${var.gce_credentials}"
    mode                = "${var.acme_mode}"
}

module "apps-cert" {
    source              = "./modules/acme"
    enabled             = "${var.acme_enabled}"
    acme_email_address  = "${local.acme_email_address}"
    zone                = "${substr(module.dns.apps_zone, 0, length(module.dns.apps_zone) - 1)}"
    gce_project         = "${var.gce_project}"
    gce_credentials     = "${var.gce_credentials}"
    mode                = "${var.acme_mode}"
}

module "bastion" {
    source          = "./modules/bastion"
    cluster_id      = "${var.cluster_id}"
    network         = "${module.vpc.network}"
    count           = 1
    default_user    = "${var.default_user}"
    id_rsa_pub_file = "${var.id_rsa_pub_file}"
    gce_region      = "${var.gce_region}"
    gce_zones       = "${local.gce_zones}"
    gce_instance    = "${var.gce_instance_bastion}"
    gce_image       = "${var.gce_image_bastion}"
}

module "master" {
    source              = "./modules/master"
    cluster_id          = "${var.cluster_id}"
    network             = "${module.vpc.network}"
    count               = "${var.master_count}"
    default_user        = "${var.default_user}"
    id_rsa_pub_file     = "${var.id_rsa_pub_file}"
    gce_region          = "${var.gce_region}"
    gce_zones           = "${local.gce_zones}"
    gce_instance        = "${var.gce_instance_master}"
    gce_image           = "${var.gce_image_master}"
    cluster_zone        = "${module.dns.cluster_zone}"
    cluster_zone_name   = "${module.dns.cluster_zone_name}"
    disk_type           = "${local.disk_type}"
}

module "infra" {
    source              = "./modules/infra"
    cluster_id          = "${var.cluster_id}"
    network             = "${module.vpc.network}"
    count               = "${var.infra_count}"
    default_user        = "${var.default_user}"
    id_rsa_pub_file     = "${var.id_rsa_pub_file}"
    gce_region          = "${var.gce_region}"
    gce_zones           = "${local.gce_zones}"
    gce_instance        = "${var.gce_instance_infra}"
    gce_image           = "${var.gce_image_infra}"
    cluster_zone        = "${module.dns.cluster_zone}"
    cluster_zone_name   = "${module.dns.cluster_zone_name}"
    disk_type           = "${local.disk_type}"
}

module "app" {
    source              = "./modules/app"
    cluster_id          = "${var.cluster_id}"
    network             = "${module.vpc.network}"
    count               = "${var.app_count}"
    default_user        = "${var.default_user}"
    id_rsa_pub_file     = "${var.id_rsa_pub_file}"
    gce_region          = "${var.gce_region}"
    gce_zones           = "${local.gce_zones}"
    gce_instance        = "${var.gce_instance_app}"
    gce_image           = "${var.gce_image_app}"
    cluster_zone        = "${module.dns.cluster_zone}"
    cluster_zone_name   = "${module.dns.cluster_zone_name}"
    disk_type           = "${local.disk_type}"
}

module "load-balancer" {
    source                  = "./modules/lb"
    cluster_id              = "${var.cluster_id}"
    network                 = "${module.vpc.network}"
    infra_instances         = "${module.infra.instances}"
    master_instance_groups = "${module.master.instance_groups}"
}

module "buckets" {
    source      = "./modules/buckets"
    cluster_id  = "${var.cluster_id}"
}
