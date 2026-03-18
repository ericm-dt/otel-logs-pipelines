# otel-logs-pipelines

Send logs from the OTel demo app via various shippers and routes (Cribl, et al).

## Infrastructure

The `terraform/` directory contains Terraform configurations that:

1. **Create a GKE Kubernetes cluster** – a regional cluster with a configurable node pool.
2. **Deploy the OpenTelemetry Demo app** – using the official [`opentelemetry-demo`](https://github.com/open-telemetry/opentelemetry-demo) Helm chart.

Additional observability components (instrumentation agents, log shippers, etc.) will be added to `terraform/helm.tf` in future iterations.

### Prerequisites

| Tool | Version |
|------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.5 |
| [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install) | latest |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | latest |

You must be authenticated to GCP with sufficient permissions to create GKE clusters:

```bash
gcloud auth application-default login
```

### Usage

```bash
cd terraform

# Initialize providers
terraform init

# Review the plan (supply your GCP project ID)
terraform plan -var="project_id=<YOUR_PROJECT_ID>"

# Apply
terraform apply -var="project_id=<YOUR_PROJECT_ID>"
```

After `apply` completes, configure `kubectl` using the printed command:

```bash
gcloud container clusters get-credentials otel-demo-cluster \
  --region us-central1 \
  --project <YOUR_PROJECT_ID>
```

### Variables

| Name | Description | Default |
|------|-------------|---------|
| `project_id` | GCP project ID | *(required)* |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `otel-demo-cluster` |
| `node_count` | Nodes per zone | `2` |
| `machine_type` | GCE machine type | `e2-standard-4` |
| `disk_size_gb` | Node disk size (GB) | `50` |
| `otel_demo_namespace` | Kubernetes namespace for OTel demo | `otel-demo` |
| `otel_demo_chart_version` | `opentelemetry-demo` Helm chart version | `0.33.0` |

### Outputs

| Name | Description |
|------|-------------|
| `cluster_name` | Name of the GKE cluster |
| `cluster_endpoint` | API server IP (sensitive) |
| `cluster_ca_certificate` | Root CA certificate (sensitive) |
| `kubeconfig_command` | `gcloud` command to configure `kubectl` |
| `otel_demo_namespace` | Namespace containing the OTel demo |
