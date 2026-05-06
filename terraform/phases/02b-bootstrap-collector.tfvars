# Phase 2b: apply the Bindplane Cloud agent manifest
# Use after Phase 2 has created the Bindplane source/destination/configuration
# and after you have generated the Kubernetes agent manifest in Bindplane Cloud.

deploy_otel_demo                 = false
deploy_bindplane_controlplane    = true
deploy_bindplane_cloud_bootstrap = true

deploy_embedded_collector = true
otel_collector_endpoint   = null