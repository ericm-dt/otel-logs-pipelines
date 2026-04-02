# otel-logs-pipelines

Deploy an AWS EKS cluster and run the OpenTelemetry Demo with a configurable collector pipeline (including Dynatrace export).

## What This Repo Deploys

The Terraform in `terraform/` manages:

1. EKS cluster + node group + IAM
2. VPC/subnets in one of three networking modes
3. OTel Demo Helm release (optional/staged)
4. Dynatrace credentials as a Kubernetes Secret (not in Helm values)
5. OTel collector customization (exporters, pipelines, env vars, presets)
6. Dynatrace Operator + DynaKube CR (optional; deploys OneAgent)

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
- `otel_sdk_disabled` (optional; defaults to `false`)
- `otel_collector_config` (if using OTel collector for shipping)
- `dt_tenant_url`
- `dt_ingest_api_token` (for OTel collector OTLP export)
- `dt_operator_api_token` (for Dynatrace Operator/OneAgent deployment, if enabled)
- `dt_settings_api_token` (optional, for Dynatrace settings-as-code via Terraform provider)

Legacy compatibility:
- `dt_api_token` still works as a single shared token fallback, but split tokens are recommended.

Dynatrace settings-as-code compatibility:
- If you enable `deploy_dynatrace_settings_layer = true`, Terraform manages Dynatrace tenant settings directly.
- `dt_settings_api_token` should include `settings.read` and `settings.write` scopes.
- If `dt_settings_api_token` is null, Terraform falls back to `dt_operator_api_token`.

### Instrumentation vs. Shipping

This repo separates **how telemetry is produced** from **where it goes**:

- **`otel_sdk_disabled`**: Explicitly toggles `OTEL_SDK_DISABLED` on OTel Demo workloads.
  - `false` (default): workloads use in-app OTel SDK
  - `true`: workloads disable SDK emission

  > **Note:** `otel_sdk_disabled = true` only toggles the app env var. It does **not** deploy OneAgent. Set `deploy_dynatrace_operator = true` (section 6) to install the Dynatrace Operator and DynaKube CR that actually provisions OneAgent on the cluster.
  
- **`otel_collector_config`**: Defines the in-cluster collector's receivers, exporters, and pipelines. Completely user-controlled. Build any combination:
  - Multiple exporters (Dynatrace, Prometheus, Datadog, etc.)
  - Per-signal routing (traces → one place, metrics → another, logs → third)
  - Custom processors and receivers

### Deployment Profiles

Primary scenarios:

**1) Pure OTel (SDK -> Collector -> Dynatrace)** (default):
```hcl
otel_sdk_disabled = false

otel_collector_config = {
  exporters = {
    "otlphttp/dynatrace" = {
      endpoint = "$${env:DT_TENANT_URL}/api/v2/otlp"
      headers = { Authorization = "Api-Token $${env:DT_API_TOKEN}" }
    }
  }
  service = {
    pipelines = {
      traces  = { receivers = ["otlp"], exporters = ["otlphttp/dynatrace"] }
      metrics = { receivers = ["otlp"], exporters = ["otlphttp/dynatrace"] }
      logs    = { receivers = ["otlp"], exporters = ["otlphttp/dynatrace"] }
    }
  }
}
```

**2) OneAgent for traces/metrics + Collector for logs (recommended in OneAgent mode):**
```hcl
otel_sdk_disabled = true
collector_logs_collection_enabled = true

otel_collector_config = {
  exporters = {
    "otlphttp/dynatrace" = {
      endpoint = "$${env:DT_TENANT_URL}/api/v2/otlp"
      headers = { Authorization = "Api-Token $${env:DT_API_TOKEN}" }
    }
  }
  processors = {
    "attributes/log_static_kv" = {
      actions = [
        { key = "observability.shipper.name", action = "upsert", value = "otel-collector-oss" },
        { key = "observability.shipper.version", action = "upsert", value = "0.142.0" }
      ]
    }
    batch = {}
  }
  service = {
    pipelines = {
      logs = { receivers = ["filelog"], processors = ["attributes/log_static_kv", "batch"], exporters = ["otlphttp/dynatrace"] }
    }
  }
}
```

Advanced / atypical scenarios:

**OneAgent mode with collector OTLP log receiver (`receivers = ["otlp"]`)**

This is only valid if some workload still emits OTLP logs to the collector.

Important behavior in this repo:
- When `otel_sdk_disabled = true`, the chart sets `OTEL_SDK_DISABLED=true` on demo workloads.
- OneAgent does not forward its collected traces/metrics to the OTel collector over OTLP.
- Because of that, OneAgent mode typically pairs with `filelog` collection for logs, not OTLP app emission.

If you intentionally keep a workload emitting OTLP logs, this profile is possible:

```hcl
otel_sdk_disabled = true

otel_collector_config = {
  exporters = {
    "otlphttp/dynatrace" = {
      endpoint = "$${env:DT_TENANT_URL}/api/v2/otlp"
      headers = { Authorization = "Api-Token $${env:DT_API_TOKEN}" }
    }
  }
  service = {
    pipelines = {
      logs = { receivers = ["otlp"], exporters = ["otlphttp/dynatrace"] }
    }
  }
}
```

Notes:
- Set `collector_logs_collection_enabled = true` to enable the `logsCollection` preset, which adds RBAC and hostPath mounts for `/var/log/containers/`
- Use `filelog` receiver in the pipeline (not `otlp`) to read container logs from the node filesystem
- OneAgent handles traces and metrics directly to Dynatrace; it does not relay those signals to collector OTLP

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

## 6. Dynatrace Operator

Set `deploy_dynatrace_operator = true` to install the Dynatrace Operator (via OCI Helm chart from `public.ecr.aws/dynatrace`) and apply a `DynaKube` custom resource that provisions OneAgent on every node.

```hcl
deploy_dynatrace_operator  = true
deploy_dynakube            = false
dynatrace_operator_version = "v1.8.1"

# cloudNativeFullStack: code-level tracing + host/infra (recommended)
# hostMonitoring:       host/infra metrics only, no code injection
# classicFullStack:     legacy full-stack
oneagent_mode = "cloudNativeFullStack"

# Custom host-level resource attributes attached to all telemetry on each node.
# Passed as --set-host-property=key=value to the OneAgent installer.
oneagent_host_properties = {
  "observability.environment" = "dev"
  "team"                      = "platform"
}
```

### Two-step apply for clean operator installation

`DynaKube` is a custom resource provided by the Dynatrace Operator CRD. A fresh cluster should install the operator first, then create the `DynaKube` resource on a second apply.

Step 1: install the operator and CRDs

```hcl
deploy_dynatrace_operator = true
deploy_dynakube           = false
```

Run:

```bash
terraform plan
terraform apply
```

Step 2: create the `DynaKube` resource

```hcl
deploy_dynakube = true
```

Run again:

## 7. Dynatrace Settings Layer (No UI Drift)

You can optionally manage Dynatrace monitored technologies and process monitoring rules through Terraform:

```hcl
deploy_dynatrace_settings_layer              = true
dynatrace_enable_python_monitored_technology = true
dynatrace_enable_bank_of_anthos_process_rule = true

# Recommended dedicated token (fallback is dt_operator_api_token)
dt_settings_api_token = "dt0c01.<your-settings-token>"
```

What this layer currently manages:

- Python monitored technology (environment scope)
- A process monitoring include rule for the Bank of Anthos namespace (`MONITORING_ON`)

Required API token scopes for this layer:

- `settings.read`
- `settings.write`

```bash
terraform plan
terraform apply
```

This split is the most portable and user-friendly workflow because it avoids CRD planning failures on first deployment.

### Token scopes for Dynatrace Operator

`dt_operator_api_token` requires these deployment scopes:

- `WriteConfig`
- `ReadConfig`
- `InstallerDownload` (for OneAgent installer download)
- `DataExport` (for Kubernetes monitoring)

### Host-level resource attributes

`oneagent_host_properties` sets custom properties via `--set-host-property=key=value` on each OneAgent DaemonSet pod. These become flat host-level resource attributes on **all** telemetry (traces, metrics, logs) leaving that host. Keys must not use the `dt.` prefix except for `dt.security_context`, `dt.cost.costcenter`, and `dt.cost.product`.

### Advanced DynaKube configuration

Terraform creates a single `DynaKube` CR named `dynakube` in the `dynatrace` namespace. For advanced configuration (namespaceSelector, resource limits, ActiveGate, log monitoring, etc.) refer to the [DynaKube parameter reference](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/reference/dynakube-parameters).

## 7. Dynatrace OTel Configuration Notes

### Token scope matrix

Use this as a quick reference for least-privilege token setup:

| Capability | Required scopes |
| --- | --- |
| Dynatrace Operator + DynaKube deployment | `ReadConfig`, `WriteConfig`, `InstallerDownload`, `DataExport` |
| OTLP ingest from OTel Collector | `openTelemetryTrace.ingest`, `metrics.ingest`, `logs.ingest` |
| Single shared token (deployment + ingest) | All scopes above |

Recommended: use separate tokens for deployment and ingest.

Why `DataExport` is not in the OTLP ingest token:
- `DataExport` is required by Dynatrace Kubernetes monitoring/Operator workflows.
- OTLP ingest from the OTel collector only needs the three `*.ingest` scopes.

The collector exporter endpoint is built as:

```text
${env:DT_TENANT_URL}/api/v2/otlp
```

Use tenant URL host format in `dt_tenant_url`, for example:

```text
https://<environment-id>.live.dynatrace.com
```

Do not use `.apps` URLs for OTLP ingest.

Token scopes required for Dynatrace OTLP export:

- `openTelemetryTrace.ingest`
- `metrics.ingest`
- `logs.ingest`

## 8. Verify Deployment

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

## 9. Common Troubleshooting

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

## 10. Clean Up

```bash
terraform destroy
```

If backend is shared, keep the state bucket but confirm all cluster/network resources are removed.
