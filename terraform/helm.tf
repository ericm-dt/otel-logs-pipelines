resource "kubernetes_namespace" "otel_demo" {
  metadata {
    name = var.otel_demo_namespace
  }

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "helm_release" "otel_demo" {
  name       = "otel-demo"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-demo"
  version    = var.otel_demo_chart_version
  namespace  = kubernetes_namespace.otel_demo.metadata[0].name

  # Wait for all pods to be ready before marking the release as successful.
  wait    = true
  timeout = 600

  depends_on = [google_container_node_pool.primary_nodes]
}
