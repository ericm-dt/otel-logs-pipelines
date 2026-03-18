# otel-logs-pipelines

Send logs from the OTel demo app via various shippers and routes (Cribl, et al).

## Infrastructure

The `terraform/` directory contains Terraform configurations that:

1. **Create an EKS Kubernetes cluster** – a managed AWS EKS cluster with a VPC, public/private subnets, and a managed node group.
2. **Deploy the OpenTelemetry Demo app** – using the official [`opentelemetry-demo`](https://github.com/open-telemetry/opentelemetry-demo) Helm chart.

Additional observability components (instrumentation agents, log shippers, etc.) will be added to `terraform/helm.tf` in future iterations.

### Prerequisites

| Tool | Version |
|------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.5 |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | latest |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | latest |

You must be authenticated to AWS with sufficient permissions to create EKS clusters and the associated VPC/IAM resources:

```bash
aws configure
# or use environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
```

### Usage

```bash
cd terraform

# Initialize providers
terraform init

# Review the plan
terraform plan

# Apply
terraform apply
```

After `apply` completes, configure `kubectl` using the printed command:

```bash
aws eks update-kubeconfig --region us-east-1 --name otel-demo-cluster
```

### Variables

| Name | Description | Default |
|------|-------------|---------|
| `region` | AWS region | `us-east-1` |
| `cluster_name` | EKS cluster name | `otel-demo-cluster` |
| `kubernetes_version` | Kubernetes version for the EKS cluster | `1.29` |
| `node_count` | Desired number of worker nodes | `2` |
| `instance_type` | EC2 instance type for worker nodes | `t3.medium` |
| `disk_size_gb` | Node disk size (GB) | `50` |
| `otel_demo_namespace` | Kubernetes namespace for OTel demo | `otel-demo` |
| `otel_demo_chart_version` | `opentelemetry-demo` Helm chart version | `0.33.0` |

### Outputs

| Name | Description |
|------|-------------|
| `cluster_name` | Name of the EKS cluster |
| `cluster_endpoint` | API server URL (sensitive) |
| `cluster_ca_certificate` | Root CA certificate data (sensitive) |
| `kubeconfig_command` | `aws eks` command to configure `kubectl` |
| `otel_demo_namespace` | Namespace containing the OTel demo |
