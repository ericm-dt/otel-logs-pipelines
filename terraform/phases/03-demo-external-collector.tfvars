# Phase 3: deploy demo apps with embedded collector exporting to Bindplane
# Use with: terraform plan/apply -var-file=terraform.tfvars -var-file=phases/03-demo-external-collector.tfvars

deploy_otel_demo                 = true
deploy_bindplane_controlplane    = true
deploy_bindplane_cloud_bootstrap = false

deploy_embedded_collector = true
# The embedded collector is configured via otel_collector_config in terraform.tfvars
# to export to the Bindplane collector service.