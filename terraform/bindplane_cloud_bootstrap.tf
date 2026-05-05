resource "terraform_data" "bindplane_cloud_bootstrap" {
  count = var.deploy_bindplane_cloud_bootstrap ? 1 : 0

  lifecycle {
    precondition {
      condition = (
        var.bindplane_bootstrap_manifest_path != null &&
        fileexists(var.bindplane_bootstrap_manifest_path)
      )
      error_message = "When deploy_bindplane_cloud_bootstrap=true, bindplane_bootstrap_manifest_path must point to an existing file."
    }
  }

  # Re-apply only when the manifest or target cluster changes.
  triggers_replace = {
    manifest_path = var.bindplane_bootstrap_manifest_path
    manifest_hash = filebase64sha256(var.bindplane_bootstrap_manifest_path)
    cluster_name  = aws_eks_cluster.primary.name
  }

  provisioner "local-exec" {
    command = "kubectl apply -f \"$MANIFEST\""
    environment = {
      MANIFEST = var.bindplane_bootstrap_manifest_path
    }
  }

  depends_on = [aws_eks_node_group.primary]
}
