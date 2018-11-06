variable "cluster_id" { }

resource "random_string" "suffix" {
    length  = 16
    special = false
    upper   = false
}

resource "google_storage_bucket" "registry" {
    name            = "${var.cluster_id}-registry-${random_string.suffix.result}"
    force_destroy   = true
    #location        = "US"
}

resource "google_storage_bucket" "backup" {
    name            = "${var.cluster_id}-backup-${random_string.suffix.result}"
    force_destroy   = false
    #location        = "US"
}

output "registry" {
    value = "${google_storage_bucket.registry.name}"
}

output "backup" {
    value = "${google_storage_bucket.backup.name}"
}
