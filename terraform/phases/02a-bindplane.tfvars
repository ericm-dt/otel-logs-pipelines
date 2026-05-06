# Phase 2a: enable Bindplane Cloud control-plane objects
# Use with: terraform plan/apply -var-file=terraform.tfvars -var-file=phases/02a-bindplane.tfvars

deploy_otel_demo                 = false
deploy_bindplane_controlplane    = true
deploy_bindplane_cloud_bootstrap = false

deploy_embedded_collector = true
