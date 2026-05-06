# Phase 1: infrastructure only
# Use with: terraform plan/apply -var-file=terraform.tfvars -var-file=phases/01-infra.tfvars

deploy_otel_demo                 = false
deploy_bindplane_controlplane    = false
deploy_bindplane_cloud_bootstrap = false

deploy_embedded_collector = true