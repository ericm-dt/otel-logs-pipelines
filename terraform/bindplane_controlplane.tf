locals {
  bindplane_effective_dynatrace_api_token = coalesce(var.bindplane_dynatrace_api_token, var.dt_api_token)
  bindplane_effective_configuration_name  = coalesce(var.bindplane_configuration_name, var.cluster_name)
}

resource "bindplane_source" "otlp" {
  count = var.deploy_bindplane_controlplane ? 1 : 0

  rollout = true
  name    = var.bindplane_otlp_source_name
  type    = "otlp"

  depends_on = [helm_release.bindplane]
}

resource "bindplane_destination" "dynatrace" {
  count = var.deploy_bindplane_controlplane ? 1 : 0

  rollout = true
  name    = var.bindplane_dynatrace_destination_name
  type    = "otlp_grpc"

  parameters_json = jsonencode([
    {
      name  = "telemetry_types"
      value = ["Logs", "Metrics", "Traces"]
    },
    {
      name  = "hostname"
      value = replace(var.dt_tenant_url, "https://", "")
    },
    {
      name  = "protocol"
      value = "http"
    },
    {
      name  = "http_port"
      value = 443
    },
    {
      name  = "enable_tls"
      value = true
    },
    {
      name  = "http_path_prefix"
      value = "/api/v2/otlp"
    },
    {
      name  = "headers"
      value = {
        "Authorization" = "Api-Token ${local.bindplane_effective_dynatrace_api_token}"
      }
    }
  ])

  depends_on = [helm_release.bindplane]
}

resource "bindplane_configuration_v2" "otel_demo" {
  count = var.deploy_bindplane_controlplane ? 1 : 0

  lifecycle {
    precondition {
      condition     = !var.deploy_bindplane_controlplane || var.bindplane_provider_remote_url != null
      error_message = "When deploy_bindplane_controlplane=true, set bindplane_provider_remote_url to a reachable Bindplane API URL."
    }

    precondition {
      condition = !var.deploy_bindplane_controlplane || (
        var.bindplane_provider_api_key != null ||
        (var.bindplane_provider_username != null && var.bindplane_provider_password != null)
      )
      error_message = "When deploy_bindplane_controlplane=true, set bindplane_provider_api_key or both bindplane_provider_username and bindplane_provider_password."
    }

    precondition {
      condition     = !var.deploy_bindplane_controlplane || var.dt_tenant_url != null
      error_message = "When deploy_bindplane_controlplane=true, set dt_tenant_url to your full Dynatrace tenant URL (e.g. https://<env>.live.dynatrace.com)."
    }

    precondition {
      condition     = !var.deploy_bindplane_controlplane || local.bindplane_effective_dynatrace_api_token != null
      error_message = "When deploy_bindplane_controlplane=true, set bindplane_dynatrace_api_token (or dt_api_token for fallback)."
    }
  }

  rollout  = var.bindplane_rollout_enabled
  name     = local.bindplane_effective_configuration_name
  platform = var.bindplane_collector_platform
  labels   = var.bindplane_configuration_labels

  source {
    name = bindplane_source.otlp[0].name

    route {
      route_id       = "logs-to-dynatrace"
      telemetry_type = "logs"
      components = [
        "destinations/${bindplane_destination.dynatrace[0].id}"
      ]
    }

    route {
      route_id       = "metrics-to-dynatrace"
      telemetry_type = "metrics"
      components = [
        "destinations/${bindplane_destination.dynatrace[0].id}"
      ]
    }

    route {
      route_id       = "traces-to-dynatrace"
      telemetry_type = "traces"
      components = [
        "destinations/${bindplane_destination.dynatrace[0].id}"
      ]
    }
  }

  destination {
    name     = bindplane_destination.dynatrace[0].name
    route_id = bindplane_destination.dynatrace[0].id
  }

  dynamic "rollout_options" {
    for_each = var.bindplane_rollout_strategy == "standard" ? [1] : []
    content {
      type = "standard"
    }
  }

  dynamic "rollout_options" {
    for_each = var.bindplane_rollout_strategy == "progressive" ? [1] : []
    content {
      type = "progressive"
      parameters {
        name = "stages"

        dynamic "value" {
          for_each = var.bindplane_rollout_stages
          content {
            name   = value.value.name
            labels = value.value.labels
          }
        }
      }
    }
  }

  depends_on = [helm_release.bindplane]
}
