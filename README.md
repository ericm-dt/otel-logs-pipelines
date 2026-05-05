# otel-logs-pipelines

Deploy an AWS EKS cluster and run the OpenTelemetry Demo with a Bindplane Cloud-managed collector pipeline shipping telemetry to Dynatrace.

## What This Repo Deploys

The Terraform in `terraform/` manages:

1. EKS cluster + node group + IAM
2. VPC/subnets in one of three networking modes
3. Bindplane Cloud control-plane objects (OTLP source, Dynatrace destination, collector configuration)
4. Optional Bindplane Cloud collector bootstrap (applies Bindplane-generated Kubernetes manifest via kubectl)
5. OTel Demo Helm release with external collector routing
6. Dynatrace credentials as a Kubernetes Secret (never in Helm values or plan output)

## Prerequisites

- Terraform `>= 1.5`
- AWS CLI configured (`aws configure`)
- kubectl (required if using Terraform-managed collector bootstrap)
- A Bindplane Cloud account with an API key
- A Dynatrace environment with an API token scoped for:
  - `openTelemetryTrace.ingest`
  - `metrics.ingest`
  - `logs.ingest`

## 1. Configure Terraform Backend

S3 is the preferred backend for any use beyond a single quick run — it keeps state safe if you lose your local directory or move machines.

**Option A — S3 (recommended):**

```bash
cp backend.tfvars.example backend.tfvars
# edit backend.tfvars with your bucket, key, and region
terraform init -backend-config=backend.tfvars
```

**Option B — local state (no S3 required):**

```bash
terraform init -backend=false
```

State is written to `terraform.tfstate` in the working directory. No source files need to be changed. If you later want to move to S3, run `terraform init -migrate-state -backend-config=backend.tfvars`.

## 2. Configure Deployment Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. The file is organized into clear sections — the top **ENVIRONMENT VALUES** section is what you edit. At minimum set:

| Variable | Description |
| --- | --- |
| `region` | AWS region |
| `cluster_name` | EKS cluster name |
| `bindplane_provider_remote_url` | Your Bindplane Cloud tenant URL |
| `bindplane_provider_api_key` | Bindplane Cloud API key |
| `dt_tenant_url` | Dynatrace tenant base URL (environment ID is derived from this) |
| `dt_api_token` | Dynatrace API token |
| `external_otlp_endpoint` | In-cluster OTLP endpoint of the Bindplane-managed collector (set after phase 2) |

The **PHASE-CONTROLLED TOGGLES** section at the bottom of `terraform.tfvars` is shown for reference only — do not edit those values manually. They are overridden by the phase overlay files described in section 4.

### Networking mode

Choose one networking mode in `terraform.tfvars`:

1. **Default VPC + existing subnets** (default): leave all four networking vars `null`
2. **Existing/default VPC + dedicated project subnets**: set `public_subnet_cidrs` and `private_subnet_cidrs`
3. **New custom VPC**: set `vpc_cidr` (subnets auto-derived if not set)

Node group is placed on public subnets in modes 1 and 2. NAT gateway is only created for mode 3.

## 3. Phase Overlays

This repo uses shared phase overlay files in `terraform/phases/` to control deployment-stage toggles. This makes it easier to troubleshoot anytthing that may go wrong and avoids very long-running terraform scripts. You pair one overlay with your `terraform.tfvars` to activate the phase you want to run.

The build is broken down into three phases:

| Phase overlay | `deploy_otel_demo` | `deploy_bindplane_controlplane` | `deploy_embedded_collector` | Purpose |
| --- | --- | --- | --- | --- |
| `phases/01-infra.tfvars` | `false` | `false` | `true` | EKS infrastructure only |
| `phases/02-controlplane.tfvars` | `false` | `true` | `true` | Adds Bindplane Cloud pipeline resources |
| `phases/03-demo-external-collector.tfvars` | `true` | `true` | `false` | Deploys OTel demo apps routed to external collector |

All commands below run from the `terraform/` directory. Create the plans folder once:

```bash
mkdir -p plans
```

## 4. Phase 1: Deploy Infrastructure

```bash
terraform plan \
  -var-file=terraform.tfvars \
  -var-file=phases/01-infra.tfvars \
  -out=plans/01-infra.tfplan
terraform apply plans/01-infra.tfplan
```

Once complete, configure your local kube context:

```bash
aws eks update-kubeconfig --region <region> --name <cluster_name> --alias <context_alias>
kubectl config use-context <context_alias>
```

## 5. Phase 2: Apply Bindplane Cloud Control Plane

This phase creates the Bindplane OTLP source, Dynatrace destination, and collector configuration in your Bindplane Cloud tenant.

```bash
terraform plan \
  -var-file=terraform.tfvars \
  -var-file=phases/02-controlplane.tfvars \
  -out=plans/02-controlplane.tfplan
terraform apply plans/02-controlplane.tfplan
```

### Bootstrap collectors into the cluster

Bindplane Cloud needs at least one collector running in the cluster before it can route telemetry. Two options:

**Option A — Terraform-managed (recommended):**

1. In Bindplane Cloud, generate the Kubernetes collector install manifest.
2. Save it to `terraform/bindplane-agent-bootstrap.yaml`.
3. In your `terraform.tfvars`, the path is already set to `"./bindplane-agent-bootstrap.yaml"` — confirm it matches where you saved the file.
4. Re-run phase 2 with bootstrap enabled by temporarily setting `deploy_bindplane_cloud_bootstrap = true` in your `terraform.tfvars`, then re-run the phase 2 plan/apply above.

Terraform will run `kubectl apply -f` against the manifest. kubectl must be pointed at the cluster (step 4 kube context).

**Option B — Manual:**

Apply the same Bindplane-generated manifest yourself:

```bash
kubectl apply -f bindplane-agent-bootstrap.yaml
```

Once collectors are running, find the in-cluster OTLP receiver service that Bindplane deployed and set `external_otlp_endpoint` in `terraform.tfvars`. The value follows the pattern `http://<service>.<namespace>.svc.cluster.local:<port>` — look it up with:

```bash
kubectl get svc -A | grep -i collector
```

Find the service exposing port `4317` (gRPC) or `4318` (HTTP) and use it. For example:

```hcl
external_otlp_endpoint = "http://otel-collector.otel-demo.svc.cluster.local:4318"
```

## 6. Phase 3: Deploy OTel Demo Apps

With collectors running and `external_otlp_endpoint` set in `terraform.tfvars`:

```bash
terraform plan \
  -var-file=terraform.tfvars \
  -var-file=phases/03-demo-external-collector.tfvars \
  -out=plans/03-demo-external-collector.tfplan
terraform apply plans/03-demo-external-collector.tfplan
```

This deploys the OTel demo chart with the embedded collector disabled, routing all demo service telemetry to your Bindplane-managed collector endpoint.

## 7. Verify

### Demo frontend

```bash
kubectl -n otel-demo port-forward svc/frontend-proxy 8080:8080
```

Open `http://localhost:8080`.

### Kubernetes workload health

```bash
kubectl -n otel-demo get pods
kubectl -n otel-demo get daemonset,deployment,statefulset
```

### Collector export activity

```bash
kubectl -n otel-demo logs daemonset/otel-collector-agent --since=10m | \
  grep -E "otlphttp/dynatrace|Exporting failed|Partial success|401|404"
```

Check in Dynatrace that logs, metrics, and traces are arriving from the OTel demo workloads.

## 8. Clean Up

```bash
terraform destroy
```

If the S3 backend is shared, keep the state bucket but confirm all cluster and network resources are removed.

---

## Reference

### Dynatrace configuration notes

Both the embedded collector and the Bindplane-managed collector send telemetry to:

```text
<dt_tenant_url>/api/v2/otlp
```

Set `dt_tenant_url` to the base URL of your Dynatrace environment — whatever hostname your tenant actually uses. Do not use `.apps` URLs; OTLP ingest uses the environment host directly. Examples:

```text
https://abc12345.live.dynatrace.com
https://abc12345.sprint.dynatracelabs.com
https://my-managed-instance.example.com/e/abc12345
```

### Optional self-hosted Bindplane server

This repo supports deploying a self-hosted Bindplane server via Helm, but it is not the primary path. Enable it only if you are intentionally running Bindplane outside of Bindplane Cloud:

```hcl
deploy_bindplane_server = true
```

Also set `bindplane_admin_username`, `bindplane_admin_password`, `bindplane_sessions_secret`, `bindplane_license`, and `bindplane_helm_values.backend.type` in `terraform.tfvars`. See the **OPTIONAL SELF-HOSTED BINDPLANE** section of `terraform.tfvars.example` for details.

### Custom shipper attributes on logs

This repo stamps logs with:

- `observability.shipper.name = otel-collector-oss`
- `observability.shipper.version = 0.142.0`

### Troubleshooting

**`terraform apply` hangs on Helm upgrade**

```bash
helm -n otel-demo status otel-demo
kubectl -n otel-demo get pods
kubectl -n otel-demo get events --sort-by=.lastTimestamp | tail -50
```

`wait = true` in `terraform/helm.tf` means any unhealthy pod can block completion.

**`Unauthorized` from kubectl/helm during long sessions**

```bash
aws eks update-kubeconfig --region <region> --name <cluster_name> --alias <context_alias>
kubectl config use-context <context_alias>
```

**OOM crash loops in demo services**

```bash
kubectl -n otel-demo get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
```

`OOMKilled` means memory limits are too low for that service.

**Dynatrace receives partial metric success**

Some OTel demo metrics are rejected by Dynatrace metric type constraints. This is expected for certain series — traces and logs may still ingest successfully.
