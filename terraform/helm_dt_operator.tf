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
#
# All Helm chart configuration is passed through via var.dt_operator_helm_values.
# See: https://github.com/Dynatrace/dynatrace-operator/tree/main/config/helm/chart/default
resource "helm_release" "dynatrace_operator" {
  count = var.deploy_dynatrace_operator ? 1 : 0

  name       = "dynatrace-operator"
  repository = "oci://public.ecr.aws/dynatrace"
  chart      = "dynatrace-operator"
  namespace  = kubernetes_namespace.dynatrace[0].metadata[0].name
  atomic     = true
  timeout    = 300

  # Pass caller-supplied values straight through to the chart.
  # No version pin here — control version via dt_operator_helm_values if needed.
  values = [yamlencode(var.dt_operator_helm_values)]

  depends_on = [kubernetes_namespace.dynatrace]
}

# DynaKube custom resource — tells the Operator what to deploy.
#
# Terraform manages only the two fields it owns:
#   apiUrl  — derived from dt_tenant_url
#   tokens  — references the managed Kubernetes Secret
#
# Everything else is supplied by the caller via var.dynakube_spec and merged
# on top. Consult the official DynaKube API reference for all available fields:
#   https://docs.dynatrace.com/docs/setup-and-configuration/setup-on-k8s/reference/dynakube
#
# Example dynakube_spec for cloudNativeFullStack:
#   dynakube_spec = {
#     oneAgent = { cloudNativeFullStack = {} }
#   }
resource "kubernetes_manifest" "dynakube" {
  count = var.deploy_dynakube ? 1 : 0

  manifest = {
    apiVersion = "dynatrace.com/v1beta6"
    kind       = "DynaKube"
    metadata = {
      name      = "dynakube"
      namespace = kubernetes_namespace.dynatrace[0].metadata[0].name
    }
    spec = merge(
      {
        apiUrl = "${var.dt_tenant_url}/api"
        tokens = kubernetes_secret.dynatrace_operator_tokens[0].metadata[0].name
      },
      var.dynakube_spec
    )
  }

  # DynaKube CRD is registered by the Operator Helm chart; wait for it.
  depends_on = [helm_release.dynatrace_operator]
}
