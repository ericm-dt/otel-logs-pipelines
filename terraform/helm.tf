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
  count = var.deploy_otel_demo && var.deploy_embedded_collector && var.dt_tenant_url != null ? 1 : 0

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
  # Sensitive credentials are injected via extraEnvs using secretKeyRef
  # (the dynatrace-credentials Kubernetes secret), not via this values block,
  # so they never appear in Helm release state or the Terraform plan output.
  values = [
    yamlencode(
      merge(
        {
          # Apply environment variables to all demo service components
          default = {
            envOverrides = concat(
              # Convert simple name-value pairs from otel_collector_env
              [for name, value in var.otel_collector_env : {
                name  = name
                value = value
              }],
              # Add any additional default env overrides here
              []
            )
          }

          "opentelemetry-collector" = merge(
            {
              enabled = var.deploy_embedded_collector

              # Enable standard collector presets for host and Kubernetes metrics.
              # These presets add the required receivers, processors, and RBAC.
              presets = {
                hostMetrics = {
                  enabled = true
                }
                kubernetesAttributes = {
                  enabled = true
                }
                kubeletMetrics = {
                  enabled = true
                }
                clusterMetrics = {
                  enabled = true
                }
              }

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
                    traces  = { receivers = ["otlp"], processors = ["batch"], exporters = ["otlp"] }
                    metrics = { receivers = ["otlp"], processors = ["batch"], exporters = ["otlp"] }
                    logs    = { receivers = ["otlp"], processors = ["batch"], exporters = ["otlp"] }
                  }
                }
              }
              # Add extra environment variables to the embedded collector
              # (only used when deploy_embedded_collector=true)
              extraEnvs = concat(
                # Add Dynatrace credentials from the kubernetes secret if created
                var.deploy_embedded_collector && var.dt_tenant_url != null ? [
                  {
                    name = "DT_TENANT_URL"
                    valueFrom = {
                      secretKeyRef = {
                        name = kubernetes_secret.dynatrace_credentials[0].metadata[0].name
                        key  = "DT_TENANT_URL"
                      }
                    }
                  },
                  {
                    name = "DT_API_TOKEN"
                    valueFrom = {
                      secretKeyRef = {
                        name = kubernetes_secret.dynatrace_credentials[0].metadata[0].name
                        key  = "DT_API_TOKEN"
                      }
                    }
                  }
                ] : [],
                # Add any additional collector env vars here
                []
              )
            },
            { config = var.otel_collector_config }
          )

          components = {
            accounting = {
              resources = {
                requests = {
                  memory = "128Mi"
                }
                limits = {
                  memory = "256Mi"
                }
              }
            }
          }
        }
      )
    )
  ]

  wait    = false
  timeout = 600

  depends_on = [aws_eks_node_group.primary]
}
