variable "region" {
  description = "The AWS region in which to create resources."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
  default     = "otel-demo-cluster"
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.29"
}

variable "node_count" {
  description = "The desired number of worker nodes in the managed node group."
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "The EC2 instance type to use for cluster nodes."
  type        = string
  default     = "t3.medium"
}

variable "disk_size_gb" {
  description = "The disk size (in GB) for each cluster node."
  type        = number
  default     = 50
}

variable "otel_demo_namespace" {
  description = "The Kubernetes namespace in which to deploy the OTel demo."
  type        = string
  default     = "otel-demo"
}

variable "otel_demo_chart_version" {
  description = "The version of the opentelemetry-demo Helm chart to deploy."
  type        = string
  default     = "0.33.0"
}
