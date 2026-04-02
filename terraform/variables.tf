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
# Bank of Anthos
# ---------------------------------------------------------------------------

variable "deploy_bank_of_anthos" {
  description = "Whether to deploy the Bank of Anthos demo application."
  type        = bool
  default     = false
}

variable "bank_of_anthos_namespace" {
  description = "Kubernetes namespace for the Bank of Anthos deployment."
  type        = string
  default     = "bank-of-anthos"
}

variable "bank_of_anthos_version" {
  description = "Bank of Anthos image tag to deploy (e.g. v0.6.5)."
  type        = string
  default     = "v0.6.5"
}

variable "bank_of_anthos_jwt_private_key" {
  description = <<-EOT
    Optional PEM-encoded RSA private key used by userservice to sign JWTs.
    If null, Terraform generates a keypair automatically via tls_private_key.
    Stored as a Kubernetes Secret; never appears in Helm values or plan output.
  EOT
  type      = string
  default   = null
  sensitive = true
}

variable "bank_of_anthos_jwt_public_key" {
  description = <<-EOT
    Optional PEM-encoded RSA public key used by all services to verify JWTs.
    If null, Terraform uses the public key from the generated keypair.
    Stored as a Kubernetes Secret; never appears in Helm values or plan output.
  EOT
  type      = string
  default   = null
  sensitive = true
}

variable "bank_of_anthos_helm_values" {
  description = <<-EOT
    Pass-through Helm values for the Bank of Anthos chart.
    Anything in charts/bank-of-anthos/values.yaml can be overridden here.
    Useful for: pod annotations (OTel injection), service type, resource limits,
    loadgenerator.enabled, DB credentials, image registry overrides, etc.

    Example – enable OTel auto-inject on all pods:
      bank_of_anthos_helm_values = {
        global = {
          podAnnotations = {
            "instrumentation.opentelemetry.io/inject-java"   = "true"
            "instrumentation.opentelemetry.io/inject-python" = "true"
          }
        }
        loadgenerator = { enabled = true }
      }
  EOT
  type    = any
  default = {}
}

# ---------------------------------------------------------------------------
# Legacy OTel demo (kept for backward compatibility; deploy_otel_demo defaults
# to false and these variables are only used when it is true)
# ---------------------------------------------------------------------------

variable "otel_demo_namespace" {
  description = "The Kubernetes namespace in which to deploy the OTel demo."
  type        = string
  default     = "otel-demo"
}

variable "otel_demo_chart_version" {
  description = "The version of the opentelemetry-demo Helm chart to deploy."
  type        = string
  default     = "0.40.5"
}

variable "otel_sdk_disabled" {
  description = "Whether to set OTEL_SDK_DISABLED=true on OTel Demo workloads."
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
  description = "Enable container logs collection on the OTel collector via the filelog receiver."
  type        = bool
  default     = false
}

variable "deploy_otel_demo" {
  description = "Whether to deploy the OpenTelemetry demo Helm chart (legacy; prefer Bank of Anthos)."
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

variable "dt_settings_api_token" {
  description = "Dynatrace API token used by Terraform dynatrace provider for settings-as-code resources (for example monitored technologies and process monitoring rules). If null, Terraform reuses dt_operator_api_token."
  type        = string
  default     = null
  sensitive   = true
}

variable "deploy_dynatrace_settings_layer" {
  description = "Whether to manage Dynatrace tenant settings (Python monitored technology and process monitoring rules) through Terraform."
  type        = bool
  default     = false
}

variable "dynatrace_enable_python_monitored_technology" {
  description = "Enable or disable Python monitored technology at Dynatrace environment scope."
  type        = bool
  default     = true
}

variable "dynatrace_enable_bank_of_anthos_process_rule" {
  description = "Whether to create a process monitoring include rule for the Bank of Anthos Kubernetes namespace."
  type        = bool
  default     = true
}

variable "dynatrace_enable_global_auto_process_monitoring" {
  description = "Whether to enforce global automatic deep process monitoring in Dynatrace environment scope."
  type        = bool
  default     = true
}

variable "dynatrace_enable_gunicorn_process_rule" {
  description = "Whether to create an explicit MONITORING_ON process rule for gunicorn executables."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Dynatrace Operator
#
# Pass-through design: rather than wrapping individual DynaKube fields as
# Terraform variables, Terraform manages only what it MUST own (credentials
# and the on/off toggle), and passes everything else directly to the upstream
# Helm chart and CRD spec. Users consult the official Dynatrace docs instead
# of learning a bespoke convention.
#
# Helm chart reference:
#   https://github.com/Dynatrace/dynatrace-operator/tree/main/config/helm/chart/default
# DynaKube CR reference:
#   https://docs.dynatrace.com/docs/setup-and-configuration/setup-on-k8s/reference/dynakube
# ---------------------------------------------------------------------------

variable "deploy_dynatrace_operator" {
  description = "Whether to deploy the Dynatrace Operator Helm chart."
  type        = bool
  default     = false
}

variable "deploy_dynakube" {
  description = <<-EOT
    Whether to create a DynaKube CR after the Operator is running.
    Two-step workflow: first apply with deploy_dynatrace_operator=true and
    deploy_dynakube=false (lets the Operator CRDs register), then apply again
    with deploy_dynakube=true and dynakube_spec populated.
  EOT
  type    = bool
  default = false
}

variable "dt_operator_helm_values" {
  description = <<-EOT
    Pass-through Helm values for the Dynatrace Operator chart.
    See the full values reference at:
      https://github.com/Dynatrace/dynatrace-operator/tree/main/config/helm/chart/default
    The apiUrl and token secret are managed by Terraform and do not need to be
    set here. Everything else (operator resources, CSI driver settings, etc.)
    can be controlled via this map.
  EOT
  type    = any
  default = {}
}

variable "dynakube_spec" {
  description = <<-EOT
    Full spec for the DynaKube custom resource (minus apiUrl and tokens, which
    are injected from dt_tenant_url and the managed Kubernetes Secret).
    See the full DynaKube API reference at:
      https://docs.dynatrace.com/docs/setup-and-configuration/setup-on-k8s/reference/dynakube

    Minimal cloudNativeFullStack example:
      dynakube_spec = {
        oneAgent = {
          cloudNativeFullStack = {}
        }
      }

    hostMonitoring only (no code injection):
      dynakube_spec = {
        oneAgent = {
          hostMonitoring = {}
        }
      }
  EOT
  type    = any
  default = {}
}
