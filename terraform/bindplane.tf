locals {
  bindplane_secret_name = "bindplane-server-credentials"
  bindplane_backend_type = try(var.bindplane_helm_values.backend.type, null)
}

resource "kubernetes_namespace" "bindplane" {
  count = var.deploy_bindplane_server ? 1 : 0

  metadata {
    name = var.bindplane_namespace
  }

  depends_on = [aws_eks_node_group.primary]
}

resource "kubernetes_secret" "bindplane_credentials" {
  count = var.deploy_bindplane_server ? 1 : 0

  metadata {
    name      = local.bindplane_secret_name
    namespace = kubernetes_namespace.bindplane[0].metadata[0].name
  }

  data = {
    username        = var.bindplane_admin_username
    password        = var.bindplane_admin_password
    sessions_secret = var.bindplane_sessions_secret
    license         = var.bindplane_license
  }

  type = "Opaque"
}

resource "helm_release" "bindplane" {
  count = var.deploy_bindplane_server ? 1 : 0

  name             = "bindplane"
  repository       = "https://observiq.github.io/bindplane-op-helm"
  chart            = "bindplane"
  version          = var.bindplane_chart_version
  namespace        = kubernetes_namespace.bindplane[0].metadata[0].name
  create_namespace = false

  values = [
    yamlencode(
      merge(
        {
          config = {
            accept_eula      = true
            secret           = kubernetes_secret.bindplane_credentials[0].metadata[0].name
            licenseUseSecret = true
          }
        },
        var.bindplane_helm_values
      )
    )
  ]

  wait    = true
  timeout = 900

  lifecycle {
    precondition {
      condition = !var.deploy_bindplane_server || (
        var.bindplane_admin_username != null &&
        var.bindplane_admin_password != null &&
        var.bindplane_sessions_secret != null &&
        var.bindplane_license != null
      )
      error_message = "When deploy_bindplane_server=true, set bindplane_admin_username, bindplane_admin_password, bindplane_sessions_secret, and bindplane_license."
    }

    precondition {
      condition     = !var.deploy_bindplane_server || local.bindplane_backend_type != null
      error_message = "When deploy_bindplane_server=true, set bindplane_helm_values.backend.type explicitly (for example, bbolt or postgres)."
    }
  }

  depends_on = [aws_eks_node_group.primary]
}
