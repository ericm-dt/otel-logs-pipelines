# ---------------------------------------------------------------------------
# Bank of Anthos application deployment
#
# Uses a local Helm chart (charts/bank-of-anthos/) since there is no official
# chart for this application. The chart closely mirrors the upstream Kustomize
# manifests at:
#   https://github.com/GoogleCloudPlatform/bank-of-anthos
# ---------------------------------------------------------------------------

# Default JWT keypair for Bank of Anthos auth tokens.
# Users can still override with bank_of_anthos_jwt_private_key/
# bank_of_anthos_jwt_public_key when they need stable external keys.
resource "tls_private_key" "bank_of_anthos_jwt" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

locals {
  bank_of_anthos_effective_jwt_private_key = coalesce(var.bank_of_anthos_jwt_private_key, tls_private_key.bank_of_anthos_jwt.private_key_pem)
  bank_of_anthos_effective_jwt_public_key  = coalesce(var.bank_of_anthos_jwt_public_key, tls_private_key.bank_of_anthos_jwt.public_key_pem)
}

resource "kubernetes_namespace" "bank_of_anthos" {
  count = var.deploy_bank_of_anthos ? 1 : 0

  metadata {
    name = var.bank_of_anthos_namespace
  }

  depends_on = [aws_eks_node_group.primary]
}

resource "helm_release" "bank_of_anthos" {
  count = var.deploy_bank_of_anthos ? 1 : 0

  name      = "bank-of-anthos"
  chart     = "${path.module}/../charts/bank-of-anthos"
  namespace = kubernetes_namespace.bank_of_anthos[0].metadata[0].name

  # Pin the app version to match the chart's default image tag.
  # Override individual service images via bank_of_anthos_helm_values.
  set {
    name  = "global.imageTag"
    value = var.bank_of_anthos_version
  }

  # JWT keys are passed as sensitive values so they never appear in the
  # Helm release state or Terraform plan output.
  set_sensitive {
    name  = "jwtKey.privateKey"
    value = local.bank_of_anthos_effective_jwt_private_key
  }

  set_sensitive {
    name  = "jwtKey.publicKey"
    value = local.bank_of_anthos_effective_jwt_public_key
  }

  # Pass-through for any additional chart values. This allows callers to
  # override service replicas, resource limits, image registry, DB credentials,
  # pod annotations (for OTel injection), service type, etc. — anything
  # documented in charts/bank-of-anthos/values.yaml.
  # yamlencode({}) produces a valid empty YAML map and is a no-op to Helm.
  values = [yamlencode(var.bank_of_anthos_helm_values)]

  wait    = true
  timeout = 600

  depends_on = [
    aws_eks_node_group.primary,
    aws_eks_addon.ebs_csi_driver,
  ]
}
