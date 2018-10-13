variable "zone" { }
variable "enabled" { default = false }
variable "acme_email_address" { }
variable "gce_project" { }
variable "gce_credentials" { }
variable "mode" { default = "staging" }

locals {
    staging_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
    production_url = "https://acme-v02.api.letsencrypt.org/directory"
}

provider "acme" {
    server_url = "${var.mode == "staging" ? local.staging_url : local.production_url}"
}

resource "tls_private_key" "zone" {
    count = "${var.enabled ? 1 : 0}"
    algorithm = "RSA"
}

resource "acme_registration" "zone" {
    count = "${var.enabled ? 1 : 0}"
    account_key_pem = "${tls_private_key.zone.private_key_pem}"
    email_address   = "${var.acme_email_address}"
}

resource "acme_certificate" "zone" {
    count = "${var.enabled ? 1 : 0}"
    account_key_pem             = "${acme_registration.zone.account_key_pem}"
    common_name                 = "${var.zone}"
    subject_alternative_names   = ["*.${var.zone}"]
    min_days_remaining          = 20

    dns_challenge {
        provider = "gcloud"
        config = {
            GCE_PROJECT              = "${var.gce_project}"
            GCE_SERVICE_ACCOUNT_FILE = "${var.gce_credentials}"
        }
    }
}

output "private_key_pem" {
    value = "${length(acme_certificate.zone.*.private_key_pem) > 0 ? element(concat(acme_certificate.zone.*.private_key_pem, list("")), 0) : ""}"
}

output "certificate_pem" {
    value = "${length(acme_certificate.zone.*.certificate_pem) > 0 ? element(concat(acme_certificate.zone.*.certificate_pem, list("")), 0) : ""}"
}

output "issuer_pem" {
    value = "${length(acme_certificate.zone.*.issuer_pem) > 0 ? element(concat(acme_certificate.zone.*.issuer_pem, list("")), 0) : ""}"
}
