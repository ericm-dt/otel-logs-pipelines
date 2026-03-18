output "cluster_name" {
  description = "The name of the GKE cluster."
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The IP address of the GKE cluster's Kubernetes API server."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The base64-encoded public certificate that is the root of trust for the cluster."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl for the new cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
}

output "otel_demo_namespace" {
  description = "The Kubernetes namespace containing the OTel demo deployment."
  value       = kubernetes_namespace.otel_demo.metadata[0].name
}
