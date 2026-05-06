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
| `otel_collector_endpoint` | In-cluster OTLP endpoint of the Bindplane-managed collector (set after phase 2) |

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
| `phases/02a-bindplane.tfvars` | `false` | `true` | `true` | Adds Bindplane Cloud pipeline resources |
| `phases/02b-bootstrap-collector.tfvars` | `false` | `true` | `true` | Applies the Bindplane Cloud collector bootstrap manifest |
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
  -var-file=phases/02a-bindplane.tfvars \
  -out=plans/02a-bindplane.tfplan
terraform apply plans/02a-bindplane.tfplan
```

### Bootstrap collectors into the cluster

Bindplane Cloud needs at least one collector running in the cluster before it can route telemetry. This is a separate step because the install manifest is generated from Bindplane Cloud after the control-plane objects exist. Terraform does **not** create the fleet for you. You must create or select a fleet in Bindplane Cloud, make sure that fleet's enrolled collectors match the Terraform-created configuration labels, and then generate the Kubernetes install manifest from Bindplane Cloud.

Make sure you get the configuration name from the terraform output (It should still be visible but run again if you closed your shell):
```bash
terraform output
```

Go to Bindplane Cloud and create a fleet using these settings:

- Platform: Kubernetes
- Agent Type: BDOT 1.x (or the current stable BDOT 1.x release shown in Bindplane Cloud)
- Platform specifics: Node
- Fleet name: anything meaningful for your project; using the cluster name is a reasonable default
- Next:
	- Choose a configuration (the one created by terraform)


Now, Click "Install Agent", choose all the same values that you did for the fleet, and choose the fleet you just created.
Click "Next" and download the kubernetes manifest

If you choose a different platform or agent family here, the generated install manifest will not match the Kubernetes-based collector deployment this repo expects.

You have two options on how to deploy and manage it:

**Option A — Terraform-managed (recommended):**

1. Save it to `terraform/bindplane-agent.yaml`.
2. In your `terraform.tfvars`, confirm `bindplane_bootstrap_manifest_path` matches where you saved the file.
3. Run the bootstrap overlay:

```bash
terraform plan \
  -var-file=terraform.tfvars \
  -var-file=phases/02b-bootstrap-collector.tfvars \
  -out=plans/02b-bootstrap-collector.tfplan
terraform apply plans/02b-bootstrap-collector.tfplan
```

Terraform will run `kubectl apply -f` against the manifest. kubectl must be pointed at the cluster (step 4 kube context).

**Option B — Manual:**

After creating the fleet and generating the Bindplane manifest, apply the same Bindplane-generated manifest yourself:

```bash
kubectl apply -f bindplane-agent.yaml
```

Once collectors are running, find the in-cluster OTLP receiver service that Bindplane deployed and set `otel_collector_endpoint` in `terraform.tfvars`. 

The Kubernetes DNS name for a service follows the pattern:
```
http://<SERVICE_NAME>.<NAMESPACE>.svc.cluster.local:<PORT>
```

List all services to find the Bindplane collector:

```bash
kubectl get svc -A
```

Look for a service in the `bindplane-agent` namespace that exposes port `4318` (HTTP) or `4317` (gRPC). You'll typically see something like:

```
NAMESPACE         NAME                  TYPE      CLUSTER-IP      PORT(S)
bindplane-agent   bindplane-node-agent  ClusterIP 10.100.96.180   4317/TCP,4318/TCP
```

From this, construct your endpoint. For the example above, using HTTP port `4318`:

```hcl
otel_collector_endpoint = "http://bindplane-node-agent.bindplane-agent.svc.cluster.local:4318"
```

## 6. Phase 3: Deploy OTel Demo Apps

With collectors running and `otel_collector_endpoint` set in `terraform.tfvars`:

```bash
terraform plan \
  -var-file=terraform.tfvars \
  -var-file=phases/03-demo-external-collector.tfvars \
  -out=plans/03-demo-external-collector.tfplan
terraform apply plans/03-demo-external-collector.tfplan
```

This deploys the OTel demo chart with the embedded collector disabled, routing all demo service telemetry to your Bindplane-managed collector endpoint.

At this point, you should have a fully running end-to-end bindplane sandbox!

## 7. Verify

- check your bindplane cloud to see that data is passing through the pipeline you created.
- view metrics, logs, and traces in your Dynatrace tenant.

### Demo frontend

If you want to view the exposed frontend of the otel demo:

```bash
kubectl -n otel-demo port-forward svc/frontend-proxy 8080:8080
```

Open `http://localhost:8080`.


```

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
