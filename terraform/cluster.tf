# Fetch the access token for the currently authenticated Google account.
# This is used to authenticate the Kubernetes and Helm providers.
data "google_client_config" "default" {}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # We use a separately managed node pool, so we remove the default one.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable Workload Identity for secure pod-level GCP authentication.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.cluster_name}-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
