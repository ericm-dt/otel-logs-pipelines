# ---------------------------------------------------------------------------
# EasyTrade application deployment
#
# Deploys the official Dynatrace EasyTrade Helm chart from OCI.
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "easytrade" {
  count = var.deploy_easytrade ? 1 : 0

  metadata {
    name = var.easytrade_namespace
  }

  depends_on = [aws_eks_node_group.primary]
}

resource "helm_release" "easytrade" {
  count = var.deploy_easytrade ? 1 : 0

  name       = "easytrade"
  repository = "oci://europe-docker.pkg.dev/dynatrace-demoability/helm"
  chart      = "easytrade"
  namespace  = kubernetes_namespace.easytrade[0].metadata[0].name

  values = [yamlencode(var.easytrade_helm_values)]

  wait    = true
  timeout = 600

  depends_on = [
    aws_eks_node_group.primary,
  ]
}
