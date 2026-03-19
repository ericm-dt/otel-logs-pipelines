resource "kubernetes_namespace" "otel_demo" {
  metadata {
    name = var.otel_demo_namespace
  }

  depends_on = [aws_eks_node_group.primary]
}

resource "helm_release" "otel_demo" {
  name       = "otel-demo"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-demo"
  version    = var.otel_demo_chart_version
  namespace  = kubernetes_namespace.otel_demo.metadata[0].name

  # Merge custom collector configuration with defaults
  values = [
    yamlencode({
      opentelemetryCollector = merge(
        # Default collector configuration (applied when custom config not specified)
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
                traces = {
                  receivers = ["otlp"]
                  exporters = []
                }
                metrics = {
                  receivers = ["otlp"]
                  exporters = []
                }
                logs = {
                  receivers = ["otlp"]
                  exporters = []
                }
              }
            }
          }
          env = {}
        },
        # Custom overrides
        {
          config = var.otel_collector_config
          env = var.otel_collector_env
        }
      )
    })
  ]

  wait    = true
  timeout = 600

  depends_on = [aws_eks_node_group.primary]
}
