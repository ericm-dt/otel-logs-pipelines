# Phase 2: enable Bindplane Cloud control-plane objects
# Use with: terraform plan/apply -var-file=terraform.tfvars -var-file=phases/02-controlplane.tfvars

deploy_otel_demo                 = false
deploy_bindplane_controlplane    = true
deploy_bindplane_cloud_bootstrap = false

deploy_embedded_collector = true
external_otlp_endpoint    = null