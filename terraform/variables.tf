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

# ---------------------------------------------------------------------------
# EasyTrade
# ---------------------------------------------------------------------------

variable "deploy_easytrade" {
  description = "Whether to deploy the Dynatrace EasyTrade demo application."
  type        = bool
  default     = false
}

variable "easytrade_namespace" {
  description = "Kubernetes namespace for EasyTrade."
  type        = string
  default     = "easytrade"
}

variable "easytrade_helm_values" {
  description = <<-EOT
    Pass-through Helm values for the EasyTrade chart.
    Anything supported by the official chart can be set here.
  EOT
  type    = any
  default = {}
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

variable "otel_sdk_disabled" {
  description = "Whether to set OTEL_SDK_DISABLED=true on OTel Demo workloads. This only toggles app SDK emission and does not deploy OneAgent."
  type        = bool
  default     = false
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

variable "collector_logs_collection_enabled" {
  description = "Enable container logs collection on the OTel collector via the filelog receiver. Requires logsCollection preset which adds necessary RBAC and volume mounts."
  type        = bool
  default     = false
}

variable "deploy_otel_demo" {
  description = "Whether to deploy the OpenTelemetry demo Helm chart. Set to false to deploy only infrastructure."
  type        = bool
  default     = false
}

variable "dt_tenant_url" {
  description = "Dynatrace tenant base URL (e.g. https://abc12345.live.dynatrace.com). Stored as a Kubernetes secret."
  type        = string
  default     = null
  sensitive   = true
}

variable "dt_api_token" {
  description = "(Legacy) Shared Dynatrace API token for both Operator deployment and OTLP ingest. Prefer dt_operator_api_token and dt_ingest_api_token."
  type        = string
  default     = null
  sensitive   = true
}

variable "dt_ingest_api_token" {
  description = "Dynatrace API token for OTLP ingest from the OTel collector (openTelemetryTrace.ingest, metrics.ingest, logs.ingest). Stored as a Kubernetes secret."
  type        = string
  default     = null
  sensitive   = true
}

variable "dt_operator_api_token" {
  description = "Dynatrace API token for Dynatrace Operator/DynaKube/OneAgent deployment (ReadConfig, WriteConfig, InstallerDownload, DataExport). Stored as a Kubernetes secret."
  type        = string
  default     = null
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Dynatrace Operator
# ---------------------------------------------------------------------------

variable "deploy_dynatrace_operator" {
  description = "Whether to deploy the Dynatrace Operator and create a DynaKube CR. Requires dt_tenant_url and dt_api_token."
  type        = bool
  default     = false
}

variable "deploy_dynakube" {
  description = "Whether to create the DynaKube custom resource. Keep false on the first apply when installing the Dynatrace Operator so the CRD can be created first."
  type        = bool
  default     = false
}

variable "dynatrace_operator_version" {
  description = "Version of the Dynatrace Operator Helm chart to deploy (e.g. v1.8.1)."
  type        = string
  default     = "v1.8.1"
}

variable "oneagent_mode" {
  description = "OneAgent deployment mode for the DynaKube CR. 'cloudNativeFullStack' (recommended: code-level + host monitoring), 'hostMonitoring' (host/infra only, no code injection), or 'classicFullStack' (legacy full-stack)."
  type        = string
  default     = "cloudNativeFullStack"

  validation {
    condition     = contains(["cloudNativeFullStack", "hostMonitoring", "classicFullStack"], var.oneagent_mode)
    error_message = "oneagent_mode must be one of: cloudNativeFullStack, hostMonitoring, classicFullStack."
  }
}

variable "oneagent_host_properties" {
  description = "Custom host-level resource attributes to set on OneAgent nodes via --set-host-property. These appear on all telemetry (traces, metrics, logs) emitted from each host."
  type        = map(string)
  default     = {}
}
