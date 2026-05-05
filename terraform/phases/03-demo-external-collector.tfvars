# Phase 3: deploy demo apps and route telemetry to external collector
# Use with: terraform plan/apply -var-file=terraform.tfvars -var-file=phases/03-demo-external-collector.tfvars

deploy_otel_demo                 = true
deploy_bindplane_controlplane    = true
deploy_bindplane_cloud_bootstrap = false

deploy_embedded_collector = false
# Set external_otlp_endpoint in terraform.tfvars for your environment.