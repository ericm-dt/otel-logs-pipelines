output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The URL of the EKS cluster's Kubernetes API server."
  value       = aws_eks_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The base64-encoded certificate authority data for the EKS cluster."
  value       = aws_eks_cluster.primary.certificate_authority[0].data
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl for the new cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.primary.name}"
}

output "otel_demo_namespace" {
  description = "The Kubernetes namespace containing the OTel demo deployment (only output if deployed)."
  value       = var.deploy_otel_demo ? kubernetes_namespace.otel_demo[0].metadata[0].name : null
}

output "bindplane_namespace" {
  description = "The Kubernetes namespace containing Bindplane server resources (only output if deployed)."
  value       = var.deploy_bindplane_server ? kubernetes_namespace.bindplane[0].metadata[0].name : null
}

output "bindplane_server_url" {
  description = "In-cluster Bindplane server URL (only output if deployed)."
  value       = var.deploy_bindplane_server ? "http://bindplane.${kubernetes_namespace.bindplane[0].metadata[0].name}.svc.cluster.local:3001" : null
}

output "bindplane_opamp_url" {
  description = "In-cluster Bindplane OpAMP WebSocket URL (only output if deployed)."
  value       = var.deploy_bindplane_server ? "ws://bindplane.${kubernetes_namespace.bindplane[0].metadata[0].name}.svc.cluster.local:3001/v1/opamp" : null
}

output "bindplane_configuration_name" {
  description = "Name of the managed Bindplane collector configuration (only output if control-plane management is enabled)."
  value       = var.deploy_bindplane_controlplane ? bindplane_configuration_v2.otel_demo[0].name : null
}

output "bindplane_configuration_match_labels" {
  description = "Computed labels used by Bindplane to match managed agents (only output if control-plane management is enabled)."
  value       = var.deploy_bindplane_controlplane ? bindplane_configuration_v2.otel_demo[0].match_labels : null
}
