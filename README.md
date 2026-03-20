# otel-logs-pipelines

Deploy an AWS EKS cluster and run the OpenTelemetry Demo with a configurable collector pipeline (including Dynatrace export).

## What This Repo Deploys

The Terraform in `terraform/` manages:

1. EKS cluster + node group + IAM
2. VPC/subnets in one of three networking modes
3. OTel Demo Helm release (optional/staged)
4. Dynatrace credentials as a Kubernetes Secret (not in Helm values)
5. OTel collector customization (exporters, pipelines, env vars, presets)

## Prerequisites

- Terraform `>= 1.5`
- AWS CLI
- kubectl
- Helm CLI (optional, but handy for manual inspection/debugging)

You also need AWS permissions to create/manage EKS, EC2 networking, IAM roles, and to read/write the Terraform S3 backend.

Authenticate first:

```bash
aws configure
```

## 1. Configure Terraform Backend

This repo uses an S3 backend (`backend "s3" {}` in `terraform/providers.tf`).

Create backend vars from the template:

```bash
cd terraform
cp backend.tfvars.example backend.tfvars
```

Edit `backend.tfvars` with your S3 bucket/key/region.

Initialize:

```bash
terraform init -backend-config=backend.tfvars
```

## 2. Configure Deployment Variables

Create your deployment vars:

```bash
cp terraform.tfvars.example terraform.tfvars
```

At minimum, set:

- `cluster_name`
- `region`
- `deploy_otel_demo`
- `dt_tenant_url` and `dt_api_token` (if exporting to Dynatrace)

Important defaults in current template:

- `kubernetes_version = "1.32"`
- `node_count = 3`
- `instance_type = "t3.large"` (recommended for OTel demo)
- `otel_demo_chart_version = "0.40.5"`

## 3. Choose Networking Mode

Configure one of these in `terraform.tfvars`:

1. Default VPC + existing subnets:
	- `vpc_cidr = null`
	- `existing_vpc_id = null`
	- `public_subnet_cidrs = null`
	- `private_subnet_cidrs = null`
2. Existing/default VPC + dedicated project subnets:
	- Set `public_subnet_cidrs` and `private_subnet_cidrs`
3. New custom VPC:
	- Set `vpc_cidr`
	- Optional explicit subnet CIDRs

Notes:

- Node group is intentionally placed on public subnets in project-subnet mode.
- NAT gateway is only created for custom VPC mode.

## 4. Recommended Staged Deployment

### How `deploy_otel_demo` works

`deploy_otel_demo` is a feature flag that controls whether Kubernetes/Helm resources are created.

- When `deploy_otel_demo = false`:
	- Terraform creates only AWS infrastructure (EKS, networking, node group, IAM).
	- It does not create the `otel-demo` namespace, Dynatrace secret, or Helm release.
- When `deploy_otel_demo = true`:
	- Terraform also creates the Kubernetes namespace/secret and deploys the OTel demo Helm chart.

This allows you to bootstrap the cluster first, then deploy workloads in a second pass.

### Why use two phases

Two phases make troubleshooting much easier:

- You can isolate cloud provisioning problems (IAM, subnets, quotas, node group) from Helm/app problems.
- You can validate cluster access (`kubectl`) before involving Helm.
- Re-running app-only changes is faster and safer once base infrastructure is stable.

### Phase A: Infrastructure only

Set:

```hcl
deploy_otel_demo = false
```

Then:

```bash
terraform plan
terraform apply
```

Configure kube context:

```bash
aws eks update-kubeconfig --region <region> --name <cluster_name> --alias <context_alias>
kubectl config use-context <context_alias>
```

### Phase B: Deploy OTel Demo + Collector config

Set:

```hcl
deploy_otel_demo = true
```

Then:

```bash
terraform plan
terraform apply
```

## 5. Access the Demo Frontend

```bash
kubectl -n otel-demo port-forward svc/frontend-proxy 8080:8080
```

Open `http://localhost:8080`.

Stop forwarding with `Ctrl+C`.

## 6. Dynatrace Configuration Notes

The collector exporter endpoint is built as:

```text
${env:DT_TENANT_URL}/api/v2/otlp
```

Use tenant URL host format in `dt_tenant_url`, for example:

```text
https://<environment-id>.live.dynatrace.com
```

Do not use `.apps` URLs for OTLP ingest.

Token scopes required:

- `openTelemetryTrace.ingest`
- `metrics.ingest`
- `logs.ingest`

## 7. Verify Deployment

### Kubernetes workload health

```bash
kubectl -n otel-demo get pods
kubectl -n otel-demo get daemonset,deployment,statefulset
```

### Collector config rendered in cluster

```bash
kubectl -n otel-demo get configmap -l app.kubernetes.io/name=opentelemetry-collector -o yaml
```

### Export activity/errors

```bash
kubectl -n otel-demo logs daemonset/otel-collector-agent --since=10m | \
grep -E "otlphttp/dynatrace|Exporting failed|Partial success|401|404"
```

### Custom shipper attributes on logs

This repo stamps logs with:

- `observability.shipper.name = otel-collector-oss`
- `observability.shipper.version = 0.142.0`

## 8. Common Troubleshooting

### `terraform apply` hangs on Helm upgrade

If `helm_release.otel_demo` is stuck, check:

```bash
helm -n otel-demo status otel-demo
kubectl -n otel-demo get pods
kubectl -n otel-demo get events --sort-by=.lastTimestamp | tail -50
```

`wait = true` in `terraform/helm.tf` means any unhealthy pod can block completion.

### `Unauthorized` from kubectl/helm during long sessions

Refresh kube auth:

```bash
aws eks update-kubeconfig --region <region> --name <cluster_name> --alias <context_alias>
kubectl config use-context <context_alias>
```

### OOM crash loops in demo services

Check reason:

```bash
kubectl -n otel-demo get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
```

`OOMKilled` means limits are too low for that service profile.

### Dynatrace receives partial metric success

Some OTel demo metrics are rejected by Dynatrace metric type constraints. This is expected for certain series. Traces/logs may still ingest successfully.

## 9. Clean Up

```bash
terraform destroy
```

If backend is shared, keep the state bucket but confirm all cluster/network resources are removed.
