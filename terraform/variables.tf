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

variable "deploy_otel_demo" {
  description = "Whether to deploy the OpenTelemetry demo Helm chart. Set to false to deploy only infrastructure."
  type        = bool
  default     = false
}

variable "deploy_embedded_collector" {
  description = "Whether to deploy the opentelemetry-demo chart's embedded collector. Set false when using an external collector fleet (for example, Bindplane-managed collectors)."
  type        = bool
  default     = true
}

variable "external_otlp_endpoint" {
  description = "Optional OTLP endpoint used by demo services when deploy_embedded_collector is false (for example, http://otel-collector.otel-demo.svc.cluster.local:4318)."
  type        = string
  default     = null
}

variable "deploy_bindplane_server" {
  description = "Whether to deploy a self-hosted Bindplane server via Helm. Leave false when using Bindplane Cloud."
  type        = bool
  default     = false
}

variable "bindplane_namespace" {
  description = "Kubernetes namespace for Bindplane server resources."
  type        = string
  default     = "bindplane"
}

variable "bindplane_chart_version" {
  description = "Bindplane Helm chart version to deploy."
  type        = string
  default     = "1.34.0"
}

variable "bindplane_admin_username" {
  description = "Initial Bindplane admin username. Required when deploy_bindplane_server is true."
  type        = string
  default     = null
  sensitive   = true
}

variable "bindplane_admin_password" {
  description = "Initial Bindplane admin password. Required when deploy_bindplane_server is true."
  type        = string
  default     = null
  sensitive   = true
}

variable "bindplane_sessions_secret" {
  description = "Random UUID used by Bindplane for session signing. Required when deploy_bindplane_server is true."
  type        = string
  default     = null
  sensitive   = true
}

variable "bindplane_license" {
  description = "Bindplane license key. Required when deploy_bindplane_server is true."
  type        = string
  default     = null
  sensitive   = true
}

variable "bindplane_helm_values" {
  description = "Additional Bindplane Helm values merged over safe defaults. Must explicitly set backend.type when deploy_bindplane_server is true. For sandbox single-instance mode, you can use bbolt with image.tag pinned to v1.98.0 or older."
  type        = any
  default     = {}
}

variable "deploy_bindplane_controlplane" {
  description = "Whether to manage Bindplane pipeline resources (source, destination, configuration) in this same Terraform stack."
  type        = bool
  default     = false
}

variable "bindplane_provider_remote_url" {
  description = "Bindplane API URL used by the Terraform provider. For Bindplane Cloud, set this to your cloud tenant URL. For self-hosted Bindplane, set this to the reachable server URL. Required when deploy_bindplane_controlplane is true."
  type        = string
  default     = null
}

variable "bindplane_provider_api_key" {
  description = "Bindplane API key used by the Terraform provider."
  type        = string
  default     = null
  sensitive   = true
}

variable "bindplane_provider_username" {
  description = "Bindplane username for basic auth (optional when using API key)."
  type        = string
  default     = null
  sensitive   = true
}

variable "bindplane_provider_password" {
  description = "Bindplane password for basic auth (optional when using API key)."
  type        = string
  default     = null
  sensitive   = true
}

variable "bindplane_provider_tls_skip_verify" {
  description = "Set true only for testing with self-signed certificates."
  type        = bool
  default     = false
}

variable "deploy_bindplane_cloud_bootstrap" {
  description = "Whether to apply a Bindplane Cloud-generated Kubernetes collector bootstrap manifest with kubectl."
  type        = bool
  default     = false
}

variable "bindplane_bootstrap_manifest_path" {
  description = "Path to the Bindplane Cloud-generated Kubernetes collector install manifest. Required when deploy_bindplane_cloud_bootstrap is true."
  type        = string
  default     = null
}

variable "bindplane_configuration_name" {
  description = "Name for the Bindplane-managed collector configuration."
  type        = string
  default     = "otel-demo-config"
}

variable "bindplane_collector_platform" {
  description = "Collector platform for Bindplane configuration."
  type        = string
  default     = "linux"
}

variable "bindplane_configuration_labels" {
  description = "Labels attached to the Bindplane configuration."
  type        = map(string)
  default = {
    managed_by = "terraform"
    stack      = "main"
  }
}

variable "bindplane_rollout_enabled" {
  description = "Whether Bindplane configuration updates should roll out automatically."
  type        = bool
  default     = true
}

variable "bindplane_rollout_strategy" {
  description = "Rollout strategy for Bindplane configuration updates."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "progressive"], var.bindplane_rollout_strategy)
    error_message = "bindplane_rollout_strategy must be either 'standard' or 'progressive'."
  }
}

variable "bindplane_rollout_stages" {
  description = "Progressive rollout stages used only when bindplane_rollout_strategy is progressive."
  type = list(object({
    name   = string
    labels = map(string)
  }))

  default = [
    {
      name = "stage"
      labels = {
        env = "stage"
      }
    },
    {
      name = "production"
      labels = {
        env = "production"
      }
    }
  ]
}

variable "bindplane_otlp_source_name" {
  description = "Bindplane source component name for OTLP ingestion."
  type        = string
  default     = "otel-ingest"
}

variable "bindplane_dynatrace_destination_name" {
  description = "Bindplane destination component name for Dynatrace export."
  type        = string
  default     = "dynatrace-otlp"
}

variable "bindplane_dynatrace_api_token" {
  description = "Dynatrace API token used by Bindplane destination. Optional; if null, dt_api_token is reused."
  type        = string
  default     = null
  sensitive   = true
}

variable "dt_tenant_url" {
  description = "Dynatrace tenant base URL (e.g. https://abc12345.live.dynatrace.com). Stored as a Kubernetes secret."
  type        = string
  default     = null
  sensitive   = true
}

variable "dt_api_token" {
  description = "Dynatrace API token with metrics/traces/logs ingest scopes. Stored as a Kubernetes secret."
  type        = string
  default     = null
  sensitive   = true
}
