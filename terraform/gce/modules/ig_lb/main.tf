variable "master_instance_group" { }
variable "infra_instance_group_name" { }

## MASTER

resource "google_compute_health_check" "master" {
    name               = "master"
    check_interval_sec = 5
    timeout_sec        = 4

    tcp_health_check {
        port = "443"
    }
}

resource "google_compute_backend_service" "master" {
    name        = "master"
    description = "Master Load Balancer"
    protocol    = "TCP"
    timeout_sec = 120
    enable_cdn  = false

    backend {
        group = "${var.master_instance_group}"
    }

    health_checks = ["${google_compute_health_check.master.self_link}"]
}

resource "google_compute_target_tcp_proxy" "master" {
    name = "master"
    description = "Master Load Balancer"
    backend_service = "${google_compute_backend_service.master.self_link}"
}

resource "google_compute_global_address" "master" {
    name = "master"
}

resource "google_compute_global_forwarding_rule" "master" {
    name = "master-https"
    ip_address = "${google_compute_global_address.master.address}"
    ip_protocol = "TCP"
    target = "${google_compute_target_tcp_proxy.master.self_link}"
    port_range = "443"
}

resource "google_compute_firewall" "master-443" {
  name    = "master-443"
  network = "default"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  target_tags = [ "master" ]
}

## INFRA

data "google_compute_region_instance_group" "infra" {
    name = "${var.infra_instance_group_name}"
}

resource "google_compute_http_health_check" "infra" {
    name               = "infra"
    request_path       = "/healthz"
    check_interval_sec = 5
    timeout_sec        = 4
}

resource "google_compute_target_pool" "infra" {
    name = "infra"

    instances = ["${data.google_compute_region_instance_group.infra.instances.*.instance}"]

    health_checks = [
        "${google_compute_http_health_check.infra.self_link}",
    ]
}

