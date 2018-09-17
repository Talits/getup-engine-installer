variable "cluster_id" { }
variable "network" { default = "default" }
variable "count" { default = 3 }
variable "gce_region" { }
variable "gce_zones" { default = [] }
variable "gce_image" { }
variable "cluster_zone" {}
variable "cluster_zone_name" {}

variable "gce_instance" {
    type    = "string"
    default = "n1-standard-4"
    description = "Instance type"
}

variable "default_user" { }
variable "id_rsa_pub_file" { }
variable "disk_type" { default = "pd-ssd" }

resource "google_compute_disk" "boot" {
    count = "${var.count}"
    name  = "${var.cluster_id}-app-boot-disk-${count.index}"
    type  = "pd-standard"
    zone  = "${element(var.gce_zones, count.index)}"
    image = "${var.gce_image}"
}

resource "google_compute_disk" "containers" {
    count = "${var.count}"
    name  = "${var.cluster_id}-app-containers-disk-${count.index}"
    type  = "${var.disk_type}"
    zone  = "${element(var.gce_zones, count.index)}"
    size  = 100
}

resource "google_compute_disk" "local" {
    count = "${var.count}"
    name  = "${var.cluster_id}-app-local-disk-${count.index}"
    type  = "${var.disk_type}"
    zone  = "${element(var.gce_zones, count.index)}"
    size  = 20
}

resource "google_compute_instance" "app" {
    count = "${var.count}"
    name = "${var.cluster_id}-app-${count.index}"

    boot_disk {
        source = "${element(google_compute_disk.boot.*.name, count.index)}"
        auto_delete = "false"
    }

    machine_type = "${var.gce_instance}"
    zone = "${element(var.gce_zones, count.index)}"

    network_interface {
        network = "${var.network}"
        access_config {}
    }

    allow_stopping_for_update = "true"

    attached_disk = [
        {
            source      = "${element(google_compute_disk.local.*.name, count.index)}"
            device_name = "local"
        },
        {
            source      = "${element(google_compute_disk.containers.*.name, count.index)}"
            device_name = "containers"
        }
    ]

    description = "GetupEngine node app ${count.index} ${element(var.gce_zones, count.index)}"

    labels = [
        { cluster_id = "${var.cluster_id}" },
        { name = "app-${count.index}" },
        { role = "app" }
    ]

    tags = [
        "${var.cluster_id}-app",
        "${var.cluster_id}-node",
        "${var.cluster_id}ocp"
    ]

    scheduling {
        on_host_maintenance = "MIGRATE"
        automatic_restart = "true"
    }

    metadata {
        startup-script = "${file("setup-node.sh")}"
        sshKeys = "${var.default_user}:${file(var.id_rsa_pub_file)}"
    }

    service_account {
        scopes = [
            "userinfo-email",
            "compute-rw",
            "storage-ro",
            "logging-write",
            "monitoring-write",
            "service-management",
            "service-control"
        ]
    }
}

resource "google_dns_record_set" "apps" {
    count = "${var.count}"
    name = "app-${count.index}.${var.cluster_zone}"
    type = "A"
    ttl  = 300

    managed_zone = "${var.cluster_zone_name}"

    rrdatas = ["${element(google_compute_instance.app.*.network_interface.0.address, count.index)}"]
}

resource "google_dns_record_set" "apps-SRV" {
    count = "${var.count > 0 ? 1 : 0}"
    name = "apps.${var.cluster_zone}"
    type = "SRV"
    ttl  = 300

    managed_zone = "${var.cluster_zone_name}"

    rrdatas = ["${formatlist("1 10 9100 %s.", google_compute_instance.app.*.network_interface.0.address)}"]
}

output "names" {
    value = ["${google_compute_instance.app.*.name}"]
}
