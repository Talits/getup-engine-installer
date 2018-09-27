#################################################################
## Outputs
#################################################################

output "CLUSTER_ZONE" {
    value = "${var.cluster_zone}"
}

output "APPS_ZONE" {
    value = "${var.apps_zone}"
}

output "CLUSTER_ZONE_NAME_SERVERS" {
    value = "${module.dns.cluster_zone_name_servers}"
}

output "APPS_ZONE_NAME_SERVERS" {
    value = "${module.dns.apps_zone_name_servers}"
}

output "CLUSTER_REGION" {
    value = "${var.gce_region}"
}

output "DEFAULT_USER" {
    value = "${var.default_user}"
}

output "CLUSTER_ID" {
    value = "${var.cluster_id}"
}

# Endpoints
###########

output "API_ENDPOINT" {
    value = "${module.dns.api-endpoint}"
}

output "PORTAL_ENDPOINT" {
    value = "${module.dns.portal-endpoint}"
}

output "GAPI_ENDPOINT" {
    value = "${module.dns.gapi-endpoint}"
}

output "USAGE_ENDPOINT" {
    value = "${module.dns.usage-endpoint}"
}

output "INFRA_ENDPOINT" {
    value = "${module.dns.infra-endpoint}"
}

output "BASTION_ENDPOINT" {
    value = "${module.dns.bastion-endpoint}"
}

output "BASTION_ADDRESS" {
    value = "${module.bastion.address}"
}

output "MASTER_HOSTNAMES" {
    value = "${module.master.names}"
}

output "INFRA_HOSTNAMES" {
    value = "${module.infra.names}"
}

output "APP_HOSTNAMES" {
    value = "${module.app.names}"
}


# Registry
##########

output "REGISTRY_STORAGE_PROVIDER" {
    value = "gcs"
}

output "REGISTRY_GCS_BUCKET_NAME" {
    value = "${module.buckets.registry}"
}

# Backups
#########

output "GETUPCLOUD_BACKUP_GCS_BUCKET" {
    value = "${module.buckets.backup}"
}

# CERTIFICATES
##############

output "ACME_CLUSTER_PRIVATE_KEY_PEM" {
    value = "${module.cluster-cert.private_key_pem}"
    sensitive = true
}

output "ACME_CLUSTER_CERTIFICATE_PEM" {
    value = "${module.cluster-cert.certificate_pem}"
}

output "ACME_CLUSTER_ISSUER_PEM" {
    value = "${module.cluster-cert.issuer_pem}"
}

output "ACME_APPS_PRIVATE_KEY_PEM" {
    value = "${module.apps-cert.private_key_pem}"
    sensitive = true
}

output "ACME_APPS_CERTIFICATE_PEM" {
    value = "${module.apps-cert.certificate_pem}"
}

output "ACME_APPS_ISSUER_PEM" {
    value = "${module.apps-cert.issuer_pem}"
}
