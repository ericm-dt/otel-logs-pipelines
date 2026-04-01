locals {
  # Build --set-host-property args from the map. Each entry becomes a separate
  # installer argument, e.g. { "env" = "prod" } → "--set-host-property=env=prod"
  oneagent_host_property_args = [
    for k, v in var.oneagent_host_properties : "--set-host-property=${k}=${v}"
  ]
}

resource "kubernetes_namespace" "dynatrace" {
  count = var.deploy_dynatrace_operator ? 1 : 0

  metadata {
    name = "dynatrace"
  }

  depends_on = [aws_eks_node_group.primary]
}

# Dynatrace Operator tokens secret.
# The Operator uses `apiToken` for cluster-level API calls and OneAgent
# installation. Use dt_operator_api_token for least-privilege separation.
resource "kubernetes_secret" "dynatrace_operator_tokens" {
  count = var.deploy_dynatrace_operator ? 1 : 0

  metadata {
    name      = "dynatrace-operator-tokens"
    namespace = kubernetes_namespace.dynatrace[0].metadata[0].name
  }

  data = {
    apiToken = var.dt_operator_api_token != null ? var.dt_operator_api_token : var.dt_api_token
  }

  type = "Opaque"
}

# Dynatrace Operator — installed from the official OCI registry.
# The Operator manages the lifecycle of OneAgent and ActiveGate components
# declared in DynaKube custom resources.
resource "helm_release" "dynatrace_operator" {
  count = var.deploy_dynatrace_operator ? 1 : 0

  name       = "dynatrace-operator"
  repository = "oci://public.ecr.aws/dynatrace"
  chart      = "dynatrace-operator"
  version    = trimprefix(var.dynatrace_operator_version, "v")
  namespace  = kubernetes_namespace.dynatrace[0].metadata[0].name
  atomic     = true
  timeout    = 300

  depends_on = [kubernetes_namespace.dynatrace]
}

# DynaKube custom resource — tells the Operator what to deploy.
# The mode field selects the OneAgent deployment strategy:
#   cloudNativeFullStack  — code-level tracing + host/infra (recommended)
#   hostMonitoring        — host/infra metrics only, no code injection
#   classicFullStack      — legacy full-stack (requires kernel module)
resource "kubernetes_manifest" "dynakube" {
  count = var.deploy_dynakube ? 1 : 0

  manifest = {
    apiVersion = "dynatrace.com/v1beta6"
    kind       = "DynaKube"
    metadata = {
      name      = "dynakube"
      namespace = kubernetes_namespace.dynatrace[0].metadata[0].name
    }
    spec = {
      # apiUrl must be the Dynatrace environment API endpoint.
      # For SaaS: https://<environment-id>.live.dynatrace.com/api
      apiUrl = "${var.dt_tenant_url}/api"
      tokens = kubernetes_secret.dynatrace_operator_tokens[0].metadata[0].name
      oneAgent = {
        (var.oneagent_mode) = {
          args = local.oneagent_host_property_args
        }
      }
    }
  }

  # DynaKube CRD is installed by the Operator Helm chart; wait for it.
  depends_on = [helm_release.dynatrace_operator]
}
