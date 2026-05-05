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
                    traces  = { receivers = ["otlp"], exporters = [] }
                    metrics = { receivers = ["otlp"], exporters = [] }
                    logs    = { receivers = ["otlp"], exporters = [] }
                  }
                }
              }
              # Add extra environment variables: non-sensitive vars directly,
              # and sensitive Dynatrace credentials via secret references.
              extraEnvs = concat(
                # Convert simple name-value pairs from otel_collector_env
                [for name, value in var.otel_collector_env : {
                  name  = name
                  value = value
                }],
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
                ] : []
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
        },
        var.external_otlp_endpoint != null ? {
          # Point all demo services at a Bindplane-managed (or otherwise external)
          # collector endpoint when the embedded collector is disabled.
          default = {
            env = [
              {
                name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
                value = var.external_otlp_endpoint
              }
            ]
          }
        } : {}
      )
    )
  ]

  wait    = true
  timeout = 600

  lifecycle {
    precondition {
      condition = !(var.deploy_otel_demo && !var.deploy_embedded_collector) || (
        var.external_otlp_endpoint != null || var.deploy_bindplane_cloud_bootstrap
      )
      error_message = "When deploy_otel_demo=true and deploy_embedded_collector=false, set external_otlp_endpoint or enable deploy_bindplane_cloud_bootstrap."
    }
  }

  depends_on = [aws_eks_node_group.primary]
}
