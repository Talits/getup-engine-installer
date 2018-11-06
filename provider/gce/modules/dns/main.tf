variable "cluster_id" {}
variable "network" { default = "default" }
variable "cluster_zone" {}
variable "apps_zone" {}

variable "master_lb_address" {}
variable "bastion_address" {}
variable "infra_lb_address" {}

locals {
    single_zone = "${var.cluster_zone == var.apps_zone ? true : false}"
}

##
## Cluster Zone
##

resource "google_dns_managed_zone" "cluster" {
    name        = "${var.cluster_id}-cluster-zone"
    dns_name    = "${var.cluster_zone}."
    description = "Cluster Zone for ${var.cluster_id}"
}

resource "google_dns_record_set" "bastion-A" {
    name = "bastion.${google_dns_managed_zone.cluster.dns_name}"
    type = "A"
    ttl  = 300

    managed_zone = "${google_dns_managed_zone.cluster.name}"

    rrdatas = ["${var.bastion_address}"]
}

resource "google_dns_record_set" "api-A" {
    name = "api.${google_dns_managed_zone.cluster.dns_name}"
    type = "A"
    ttl  = 300

    managed_zone = "${google_dns_managed_zone.cluster.name}"

    rrdatas = ["${var.master_lb_address}"]
}

resource "google_dns_record_set" "portal-A" {
    name = "portal.${google_dns_managed_zone.cluster.dns_name}"
    type = "A"
    ttl  = 300

    managed_zone = "${google_dns_managed_zone.cluster.name}"

    rrdatas = ["${var.infra_lb_address}"]
}

resource "google_dns_record_set" "gapi-A" {
    name = "gapi.${google_dns_managed_zone.cluster.dns_name}"
    type = "A"
    ttl  = 300

    managed_zone = "${google_dns_managed_zone.cluster.name}"

    rrdatas = ["${var.infra_lb_address}"]
}

resource "google_dns_record_set" "usage-A" {
    name = "usage.${google_dns_managed_zone.cluster.dns_name}"
    type = "A"
    ttl  = 300

    managed_zone = "${google_dns_managed_zone.cluster.name}"

    rrdatas = ["${var.infra_lb_address}"]
}

##
## Applications Zone
##

resource "google_dns_managed_zone" "apps" {
    count       = "${local.single_zone ? 0 : 1}"
    name        = "${var.cluster_id}-apps-zone"
    dns_name    = "${var.apps_zone}."
    description = "Applications Zone for ${var.cluster_id}"
}

resource "google_dns_record_set" "infra-apps-A" {
    name = "infra.${var.apps_zone}."
    type = "A"
    ttl  = 300

    managed_zone = "${local.single_zone ? google_dns_managed_zone.cluster.name : element(concat(google_dns_managed_zone.apps.*.name, list("")), 0)}"

    rrdatas = ["${var.infra_lb_address}"]
}

resource "google_dns_record_set" "infra-apps-wildcard" {
    name = "*.${var.apps_zone}."
    type = "A"
    ttl  = 300

    managed_zone = "${local.single_zone ? google_dns_managed_zone.cluster.name : element(concat(google_dns_managed_zone.apps.*.name, list("")), 0)}"

    rrdatas = ["${var.infra_lb_address}"]
}

############################################################

output "cluster_zone" {
    value = "${google_dns_managed_zone.cluster.dns_name}"
}

output "cluster_zone_name" {
    value = "${google_dns_managed_zone.cluster.name}"
}

output "cluster_zone_name_servers" {
    value = "${google_dns_managed_zone.cluster.name_servers}"
}

output "apps_zone" {
    value = "${local.single_zone ? google_dns_managed_zone.cluster.dns_name : element(concat(google_dns_managed_zone.apps.*.dns_name, list("")), 0)}"
}

output "apps_zone_name" {
    value = "${local.single_zone ? google_dns_managed_zone.cluster.name : element(concat(google_dns_managed_zone.apps.*.name, list("")), 0)}"
}

// HCL doesn't supports lists in unary operator, thus this ugly hack
output "apps_zone_name_servers" {
    value = "${flatten(google_dns_managed_zone.apps.*.name_servers)}"
}

output "bastion-endpoint" {
    value = "${substr(google_dns_record_set.bastion-A.name, 0, length(google_dns_record_set.bastion-A.name) - 1)}"
}

output "api-endpoint" {
    value = "${substr(google_dns_record_set.api-A.name, 0, length(google_dns_record_set.api-A.name) - 1)}"
}

output "portal-endpoint" {
    value = "${substr(google_dns_record_set.portal-A.name, 0, length(google_dns_record_set.portal-A.name) - 1)}"
}

output "gapi-endpoint" {
    value = "${substr(google_dns_record_set.gapi-A.name, 0, length(google_dns_record_set.gapi-A.name) - 1)}"
}

output "usage-endpoint" {
    value = "${substr(google_dns_record_set.usage-A.name, 0, length(google_dns_record_set.usage-A.name) - 1)}"
}

output "infra-endpoint" {
    value = "${substr(google_dns_record_set.infra-apps-A.name, 0, length(google_dns_record_set.infra-apps-A.name) - 1)}"
}
