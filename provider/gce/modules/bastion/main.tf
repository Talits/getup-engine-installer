variable "cluster_id" { }
variable "network" { default = "default" }
variable "count" { default = "1" }
variable "gce_region" { }
variable "gce_zones" { default = [] }
variable "gce_image" { }

variable "gce_instance" {
    type    = "string"
    default = "g1-small"
    description = "Instance type for bastion hosts"
}

variable "default_user" { }
variable "id_rsa_pub_file" { }

resource "google_compute_disk" "boot" {
    count = "${var.count}"
    name  = "${var.cluster_id}-bastion-boot-disk-${count.index}"
    type  = "pd-standard"
    zone  = "${element(var.gce_zones, count.index)}"
    image = "${var.gce_image}"
}

resource "google_compute_address" "bastion" {
  name = "${var.cluster_id}-bastion"
}

resource "google_compute_instance" "bastion" {
    count = "${var.count}"
    name = "${var.cluster_id}-bastion-${count.index}"

    boot_disk {
        source = "${element(google_compute_disk.boot.*.name, count.index)}"
        auto_delete = "false"
    }

    machine_type = "${var.gce_instance}"
    zone = "${element(var.gce_zones, count.index)}"

    network_interface {
        network = "${var.network}"

        access_config {
            nat_ip = "${google_compute_address.bastion.address}"
        }
    }

    allow_stopping_for_update = "true"

    description = "GetupEngine bastion ${count.index} ${element(var.gce_zones, count.index)}"

    labels = [
        { cluster_id = "${var.cluster_id}" },
        { name = "bastion-${count.index}" },
        { role = "bastion" }
    ]

    tags = [ "${var.cluster_id}-bastion" ]

    metadata = {
        sshKeys = "${var.default_user}:${file(var.id_rsa_pub_file)}"
    }

    scheduling {
        on_host_maintenance = "MIGRATE"
        automatic_restart = "true"
    }
}

output "address" {
    value = "${google_compute_address.bastion.address}"
}
