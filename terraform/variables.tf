variable "region" {
  description = "The AWS region in which to create resources."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. If not provided, uses the default VPC."
  type        = string
  default     = null
}

variable "existing_vpc_id" {
  description = "Optional existing VPC ID to use when vpc_cidr is null. If null, default VPC is used."
  type        = string
  default     = null
}

variable "public_subnet_cidrs" {
  description = "Optional CIDR blocks for public subnets. If set (with private_subnet_cidrs), dedicated subnets are created in the selected VPC."
  type        = list(string)
  default     = null
}

variable "private_subnet_cidrs" {
  description = "Optional CIDR blocks for private subnets. If set (with public_subnet_cidrs), dedicated subnets are created in the selected VPC."
  type        = list(string)
  default     = null
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

variable "otel_collector_config" {
  description = "OpenTelemetry collector configuration (receivers, processors, exporters, service pipelines). Merged with Helm chart defaults."
  type        = any
  default     = {}
}

variable "otel_collector_env" {
  description = "Environment variables to set on the OpenTelemetry collector container."
  type        = map(string)
  default     = {}
}
