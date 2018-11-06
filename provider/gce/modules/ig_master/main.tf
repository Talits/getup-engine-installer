variable "network" { default = "default" }
variable "count" { default = "3" }
variable "gce_region" { }
variable "gce_zones" { default = [] }
variable "gce_image" { }

variable "gce_instance" {
    type    = "string"
    default = "n1-standard-2"
    description = "Instance type for master node hosts"
}

resource "google_compute_instance_template" "master" {
    name_prefix = "master-"
    region = "${var.gce_region}"

    disk {
        disk_type  = "pd-ssd"
        source_image = "${var.gce_image}"
        auto_delete = false
        boot = true
        type = "PERSISTENT"
    }

    disk {
        disk_type  = "pd-ssd"
        disk_size_gb  = 100
        type = "SCRATCH"
    }

    disk {
        disk_type  = "pd-ssd"
        disk_size_gb  = 100
        type = "SCRATCH"
    }

    disk {
        disk_type  = "pd-ssd"
        disk_size_gb  = 20
        type = "SCRATCH"
    }

    machine_type = "${var.gce_instance}"

    network_interface {
        network = "${var.network}"
    }

    description = "GetupEngine node master ${count.index} ${element(var.gce_zones, count.index)}"

    labels = [
        { role = "master" }
    ]

    tags = [ "master", "node" ]

    scheduling {
        on_host_maintenance = "MIGRATE"
        automatic_restart = "true"
    }

    metadata {
        startup-script = "${file("setup-node.sh")}"
    }

    service_account {
        scopes = ["compute-rw"]
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "google_compute_region_instance_group_manager" "master" {
    name                = "master"
    base_instance_name  = "master"
    instance_template   = "${google_compute_instance_template.master.self_link}"
    region              = "${var.gce_region}"
    distribution_policy_zones  = "${var.gce_zones}"
    update_strategy = "NONE"

    target_size = "${var.count}"
    wait_for_instances = true

    named_port {
        name = "https"
        port = 443
    }
}

output "instance_group" {
    value = "${google_compute_region_instance_group_manager.master.instance_group}"
}
