# ---------------------------------------------------------------------------
# Standalone OTel Collector – deployment mode gateway
#
# Receives OTLP telemetry from Bank of Anthos Python services, enriches spans
# with Kubernetes metadata (pod name, namespace, deployment), then exports to
# Dynatrace via OTLP HTTP.
#
# Service DNS (from bank-of-anthos namespace):
#   http://otel-collector.otel-collector.svc.cluster.local:4318  (HTTP/proto)
#   grpc://otel-collector.otel-collector.svc.cluster.local:4317  (gRPC)
# ---------------------------------------------------------------------------

locals {
  otel_collector_namespace = "otel-collector"
  otel_collector_fullname  = "otel-collector"
}

resource "kubernetes_namespace" "otel_collector" {
  count = var.deploy_otel_collector ? 1 : 0

  metadata {
    name = local.otel_collector_namespace
  }

  depends_on = [aws_eks_node_group.primary]
}

# Dynatrace credentials stored as a Kubernetes secret so they are never
# exposed in Helm values or Terraform plan/state output.
resource "kubernetes_secret" "otel_collector_dynatrace" {
  count = var.deploy_otel_collector && var.dt_tenant_url != null ? 1 : 0

  metadata {
    name      = "dynatrace-credentials"
    namespace = kubernetes_namespace.otel_collector[0].metadata[0].name
  }

  data = {
    DT_TENANT_URL = var.dt_tenant_url
    DT_API_TOKEN  = var.dt_ingest_api_token != null ? var.dt_ingest_api_token : var.dt_api_token
  }

  type = "Opaque"
}

resource "helm_release" "otel_collector" {
  count      = var.deploy_otel_collector ? 1 : 0
  name       = "otel-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.otel_collector_chart_version
  namespace  = kubernetes_namespace.otel_collector[0].metadata[0].name

  values = [
    yamlencode({
      # Gateway / deployment mode: single replicated Deployment + ClusterIP Service.
      mode = "deployment"

      # Pin the release fullname so the Service DNS is predictable:
      #   otel-collector.otel-collector.svc.cluster.local
      fullnameOverride = local.otel_collector_fullname

      replicaCount = 1

      # Chart >=0.113.0 requires image.repository to be set explicitly.
      # opentelemetry-collector-k8s includes k8sattributes, otlphttp, and all
      # standard processors needed for a Kubernetes gateway deployment.
      image = {
        repository = "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s"
      }

      # kubernetesAttributes preset provisions the ClusterRole/ClusterRoleBinding
      # that lets the collector call the k8s API, and injects the k8sattributes
      # processor definition + prepends it to all pipeline processor lists.
      presets = {
        kubernetesAttributes = {
          enabled = true
        }
      }

      # Dynatrace credentials injected from the Kubernetes secret so they
      # never appear in the Helm release state or terraform plan output.
      extraEnvs = var.dt_tenant_url != null ? [
        {
          name = "DT_TENANT_URL"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.otel_collector_dynatrace[0].metadata[0].name
              key  = "DT_TENANT_URL"
            }
          }
        },
        {
          name = "DT_API_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.otel_collector_dynatrace[0].metadata[0].name
              key  = "DT_API_TOKEN"
            }
          }
        }
      ] : []

      config = {
        receivers = {
          otlp = {
            protocols = {
              grpc = { endpoint = "0.0.0.0:4317" }
              http = { endpoint = "0.0.0.0:4318" }
            }
          }
        }

        processors = {
          batch = {}
          # k8sattributes processor is defined and injected by the
          # kubernetesAttributes preset above; no need to declare it here.
        }

        exporters = {
          otlphttp = {
            endpoint = "$${env:DT_TENANT_URL}/api/v2/otlp"
            headers = {
              # Use $${} to produce a literal ${} in the rendered YAML so the
              # collector resolves the env var at runtime, not Terraform at plan time.
              Authorization = "Api-Token $${env:DT_API_TOKEN}"
            }
          }
          debug = {
            verbosity = "basic"
          }
        }

        service = {
          pipelines = {
            traces = {
              receivers  = ["otlp"]
              # preset prepends k8sattributes → [k8sattributes, batch] at render time
              processors = ["batch"]
              exporters  = ["otlphttp", "debug"]
            }
            metrics = {
              receivers  = ["otlp"]
              processors = ["batch"]
              exporters  = ["otlphttp"]
            }
            logs = {
              receivers  = ["otlp"]
              processors = ["batch"]
              exporters  = ["otlphttp"]
            }
          }
        }
      }
    })
  ]

  wait    = true
  timeout = 300

  depends_on = [
    aws_eks_node_group.primary,
    kubernetes_secret.otel_collector_dynatrace,
  ]
}
