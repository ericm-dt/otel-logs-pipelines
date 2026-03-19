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
