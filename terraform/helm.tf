resource "kubernetes_namespace" "otel_demo" {
  count = var.deploy_otel_demo ? 1 : 0

  metadata {
    name = var.otel_demo_namespace
  }

  depends_on = [aws_eks_node_group.primary]
}

# Dynatrace credentials are stored in a Kubernetes secret so they are never
# exposed in Helm values or the Helm release state. The collector picks them
# up via envFrom and interpolates them in its config using ${env:VAR} syntax.
resource "kubernetes_secret" "dynatrace_credentials" {
  count = var.deploy_otel_demo && var.dt_tenant_url != null ? 1 : 0

  metadata {
    name      = "dynatrace-credentials"
    namespace = kubernetes_namespace.otel_demo[0].metadata[0].name
  }

  data = {
    DT_TENANT_URL = var.dt_tenant_url
    DT_API_TOKEN  = var.dt_api_token
  }

  type = "Opaque"
}

resource "helm_release" "otel_demo" {
  count = var.deploy_otel_demo ? 1 : 0
  name       = "otel-demo"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-demo"
  version    = var.otel_demo_chart_version
  namespace  = kubernetes_namespace.otel_demo[0].metadata[0].name

  # Merge custom collector configuration with defaults.
  # Sensitive credentials are injected via envFrom (the dynatrace-credentials
  # Kubernetes secret), not via this values block, so they never appear in
  # Helm release state or the Terraform plan output.
  values = [
    yamlencode({
      opentelemetryCollector = merge(
        {
          config = {
            receivers = {
              otlp = {
                protocols = {
                  grpc = {}
                  http = {}
                }
              }
            }
            processors = {
              batch = {}
            }
            exporters = {}
            service = {
              pipelines = {
                traces  = { receivers = ["otlp"], exporters = [] }
                metrics = { receivers = ["otlp"], exporters = [] }
                logs    = { receivers = ["otlp"], exporters = [] }
              }
            }
          }
          # Non-sensitive env vars only. Sensitive values come from the
          # dynatrace-credentials secret via envFrom below.
          env = var.otel_collector_env
        },
        { config = var.otel_collector_config },
        # Mount the Dynatrace secret as envFrom if it was created.
        var.dt_tenant_url != null ? {
          envFrom = [{
            secretRef = { name = "dynatrace-credentials" }
          }]
        } : {}
      )
    })
  ]

  wait    = true
  timeout = 600

  depends_on = [aws_eks_node_group.primary]
}
