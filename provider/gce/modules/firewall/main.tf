variable "cluster_id" { }
variable "network" { default = "default" }

locals {
    tag_bastion = "${var.cluster_id}-bastion"
    tag_master = "${var.cluster_id}-master"
    tag_infra = "${var.cluster_id}-infra"
    tag_node = "${var.cluster_id}-node"
}

##
## Bastion
##

resource "google_compute_firewall" "external-to-bastion" {
    name    = "${var.cluster_id}-external-to-bastion"
    network = "${var.network}"
    direction = "INGRESS"

    allow {
        protocol = "icmp"
    }

    allow {
        protocol = "tcp"
        ports    = ["22"]
    }

    source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "bastion-to-any" {
    name    = "${var.cluster_id}-bastion-to-any"
    network = "${var.network}"
    direction = "INGRESS"

    allow {
        protocol = "tcp"
        ports    = ["1-65535"]
    }

    allow {
        protocol = "udp"
        ports    = ["1-65535"]
    }

    allow {
        protocol = "icmp"
    }


    source_tags = ["${local.tag_bastion}"]
    target_tags = ["${local.tag_node}"]
}

##
## Master
##

resource "google_compute_firewall" "node-to-master" {
    name    = "${var.cluster_id}-node-to-master"
    network = "${var.network}"
    direction = "INGRESS"

    allow {
        protocol = "udp"
        ports    = ["8053"]
    }

    allow {
        protocol = "tcp"
        ports    = ["8053"]
    }

    source_tags = ["${local.tag_node}"]
    target_tags = ["${local.tag_master}"]
}

resource "google_compute_firewall" "master-to-node" {
    name    = "${var.cluster_id}-master-to-node"
    network = "${var.network}"
    direction = "INGRESS"

    allow {
        protocol = "tcp"
        ports    = ["10250"]
    }

    source_tags = ["${local.tag_master}"]
    target_tags = ["${local.tag_node}"]
}

resource "google_compute_firewall" "master-to-master" {
    name    = "${var.cluster_id}-master-to-master"
    network = "${var.network}"
    direction = "INGRESS"

    allow {
        protocol = "tcp"
        ports    = ["2379"]
    }

    allow {
        protocol = "tcp"
        ports    = ["2380"]
    }

    source_tags = ["${local.tag_master}"]
    target_tags = ["${local.tag_master}"]
}

resource "google_compute_firewall" "any-to-master" {
    name    = "${var.cluster_id}-any-to-master"
    network = "${var.network}"
    direction = "INGRESS"

    allow {
        protocol = "tcp"
        ports    = ["443"]
    }

    source_ranges = ["0.0.0.0/0"]
    target_tags = ["${local.tag_master}"]
}

##
## Infra
##

resource "google_compute_firewall" "infra-to-infra" {
    name    = "${var.cluster_id}-infra-to-infra"
    network = "${var.network}"
    direction = "INGRESS"

    allow {
        protocol = "tcp"
        ports    = ["9200"]
    }

    allow {
        protocol = "tcp"
        ports    = ["9300"]
    }

    source_ranges = ["0.0.0.0/0"]
    target_tags = ["${local.tag_master}"]
}

resource "google_compute_firewall" "any-to-router" {
    name    = "${var.cluster_id}-any-to-router"
    network = "${var.network}"
    direction = "INGRESS"

    allow {
        protocol = "tcp"
        ports    = ["80"]
    }

    allow {
        protocol = "tcp"
        ports    = ["443"]
    }

    source_ranges = ["0.0.0.0/0"]
    target_tags = ["${local.tag_infra}"]
}

##
## Node
##

resource "google_compute_firewall" "node-to-node" {
    name    = "${var.cluster_id}-node-to-node"
    network = "${var.network}"
    direction = "INGRESS"

    allow {
        protocol = "udp"
        ports    = ["4789"]
    }

    source_tags = ["${local.tag_node}"]
    target_tags = ["${local.tag_node}"]
}

resource "google_compute_firewall" "infra-to-node" {
    name    = "${var.cluster_id}-infra-to-node"
    network = "${var.network}"
    direction = "INGRESS"

    allow {
        protocol = "tcp"
        ports    = ["9100", "10250"]
    }

    source_tags = ["${local.tag_infra}"]
    target_tags = ["${local.tag_node}"]
}
