variable "cluster_id" { }
variable "network" { default = "default" }
variable "count" { default = 3 }
variable "gce_region" { }
variable "gce_zones" { default = [] }
variable "gce_image" { }

variable "gce_instance" {
    type    = "string"
    default = "n1-standard-2"
    description = "Instance type for master node hosts"
}
variable "cluster_zone" {}
variable "cluster_zone_name" {}

variable "default_user" { }
variable "id_rsa_pub_file" { }
variable "disk_type" { default = "pd-ssd" }

resource "google_compute_disk" "boot" {
    count = "${var.count}"
    name  = "${var.cluster_id}-master-boot-disk-${count.index}"
    type  = "pd-standard"
    zone  = "${element(var.gce_zones, count.index)}"
    image = "${var.gce_image}"
}

resource "google_compute_disk" "etcd" {
    count = "${var.count}"
    name  = "${var.cluster_id}-master-etcd-disk-${count.index}"
    type  = "pd-ssd"
    zone  = "${element(var.gce_zones, count.index)}"
    size  = 20
}

resource "google_compute_disk" "containers" {
    count = "${var.count}"
    name  = "${var.cluster_id}-master-containers-disk-${count.index}"
    type  = "${var.disk_type}"
    zone  = "${element(var.gce_zones, count.index)}"
    size  = 100
}

resource "google_compute_disk" "local" {
    count = "${var.count}"
    name  = "${var.cluster_id}-master-local-disk-${count.index}"
    type  = "${var.disk_type}"
    zone  = "${element(var.gce_zones, count.index)}"
    size  = 20
}

resource "google_compute_instance" "master" {
    count = "${var.count}"
    name = "${var.cluster_id}-master-${count.index}"

    boot_disk {
        source = "${element(google_compute_disk.boot.*.name, count.index)}"
        auto_delete = "false"
    }

    machine_type = "${var.gce_instance}"
    zone = "${element(var.gce_zones, count.index)}"

    network_interface {
        network = "${var.network}"
        access_config { }
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
        },
        {
            source      = "${element(google_compute_disk.etcd.*.name, count.index)}"
            device_name = "etcd"
        }
    ]

    description = "GetupEngine node master ${count.index} ${element(var.gce_zones, count.index)}"

    labels = [
        { cluster_id = "${var.cluster_id}" },
        { name = "master-${count.index}" },
        { role = "master" }
    ]

    tags = [
        "${var.cluster_id}-master",
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

    lifecycle {
        ignore_changes = [ "attached_disk" ]
    }
}

resource "google_compute_instance_group" "master" {
    count   = "${length(var.gce_zones)}"
    name    = "${var.cluster_id}-master-${element(var.gce_zones, count.index)}"
    zone    = "${element(var.gce_zones, count.index)}"

    named_port {
        name = "https"
        port = "443"
    }

    instances = ["${matchkeys(
                    google_compute_instance.master.*.self_link,
                    google_compute_instance.master.*.zone,
                    list("${element(var.gce_zones, count.index)}"))}"]
}

## DNS records

resource "google_dns_record_set" "masters" {
    count = "${var.count}"
    name = "master-${count.index}.${var.cluster_zone}"
    type = "A"
    ttl  = 300

    managed_zone = "${var.cluster_zone_name}"

    rrdatas = ["${element(google_compute_instance.master.*.network_interface.0.address, count.index)}"]
}

resource "google_dns_record_set" "masters-SRV" {
    count = "${var.count > 0 ? 1 : 0}"
    name = "masters.${var.cluster_zone}"
    type = "SRV"
    ttl  = 300

    managed_zone = "${var.cluster_zone_name}"

    rrdatas = ["${formatlist("1 10 9100 %s.", google_compute_instance.master.*.name)}"]
}

output "names" {
    value = ["${google_compute_instance.master.*.name}"]
}

output "instance_groups" {
    value = "${google_compute_instance_group.master.*.self_link}"
}
