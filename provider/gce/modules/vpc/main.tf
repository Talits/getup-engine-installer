variable "cluster_id" { }

resource "google_compute_network" "network" {
    name = "${var.cluster_id}"
    auto_create_subnetworks = "true"
}

output "network" {
    value = "${google_compute_network.network.name}"
}
