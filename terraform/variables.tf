variable "project_id" {
  description = "The GCP project ID in which to create resources."
  type        = string
}

variable "region" {
  description = "The GCP region in which to create resources."
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster."
  type        = string
  default     = "otel-demo-cluster"
}

variable "node_count" {
  description = "The number of nodes per zone in the default node pool. For a regional cluster spanning 3 zones, the total node count will be node_count * 3."
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "The GCE machine type to use for cluster nodes."
  type        = string
  default     = "e2-standard-4"
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
