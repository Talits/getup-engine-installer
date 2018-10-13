resource "google_compute_backend_service" "master" {
    name                = "${var.cluster_id}-master"
    description         = "Master Load Balancer"
    protocol            = "TCP"
    timeout_sec         = 1800
    enable_cdn          = false
    session_affinity    = "CLIENT_IP"
    port_name           = "https"

    health_checks = ["${google_compute_health_check.master.self_link}"]

    ##
    ## Workaround for dynamic backend{} blocks
    ##

    backend{group="${var.master_instance_groups[0]}"} backend{group="${var.master_instance_groups[1]}"} backend{group="${var.master_instance_groups[2]}"} 
}
