variable "cluster_id" { }
variable "network" { default = "default" }
variable "master_instance_groups" { default = []  }
variable "infra_instances" { default = []  }
variable "gce_zones" { default = [] }

## MASTER

resource "google_compute_health_check" "master" {
    name                = "${var.cluster_id}-master"
    check_interval_sec  = 5
    timeout_sec         = 4

    https_health_check {
        request_path    = "/healthz"
    }
}

resource "google_compute_target_tcp_proxy" "master" {
    name            = "${var.cluster_id}-master"
    description     = "Master Load Balancer"
    proxy_header    = "NONE"
    backend_service = "${google_compute_backend_service.master.self_link}"
}

resource "google_compute_global_address" "master" {
    name = "${var.cluster_id}-master"
}

resource "google_compute_global_forwarding_rule" "master" {
    name        = "${var.cluster_id}-master-https"
    ip_address  = "${google_compute_global_address.master.address}"
    ip_protocol = "TCP"
    target      = "${google_compute_target_tcp_proxy.master.self_link}"
    port_range  = "443"
}

### INFRA

resource "google_compute_http_health_check" "infra" {
    name                = "${var.cluster_id}-infra"
    port                = 1936
    request_path        = "/healthz"
    check_interval_sec  = 5
    timeout_sec         = 4
}

resource "google_compute_target_pool" "infra" {
    name = "${var.cluster_id}-infra"

    instances = ["${var.infra_instances}"]

    health_checks = [
        "${google_compute_http_health_check.infra.self_link}",
    ]
}

resource "google_compute_address" "infra" {
    name = "${var.cluster_id}-infra"
}

resource "google_compute_forwarding_rule" "infra-http" {
    name        = "${var.cluster_id}-infra-http"
    ip_address  = "${google_compute_address.infra.address}"
    ip_protocol = "TCP"
    target      = "${google_compute_target_pool.infra.self_link}"
    port_range  = "80"
}

resource "google_compute_forwarding_rule" "infra-https" {
    name        = "${var.cluster_id}-infra-https"
    ip_address  = "${google_compute_address.infra.address}"
    ip_protocol = "TCP"
    target      = "${google_compute_target_pool.infra.self_link}"
    port_range  = "443"
}

output "master_lb_address" {
    value = "${google_compute_global_address.master.address}"
}

output "infra_lb_address" {
    value = "${google_compute_address.infra.address}"
}
