# Dynatrace settings-as-code layer
#
# This layer keeps tenant configuration in Terraform instead of manual UI edits.
# It is disabled by default via deploy_dynatrace_settings_layer=false.

resource "dynatrace_monitored_technologies_python" "environment" {
  count = var.deploy_dynatrace_settings_layer ? 1 : 0

  enabled = var.dynatrace_enable_python_monitored_technology
  host_id = "environment"
}

resource "dynatrace_process_monitoring" "environment" {
  count = var.deploy_dynatrace_settings_layer && var.dynatrace_enable_global_auto_process_monitoring ? 1 : 0

  auto_monitoring = true
  host_group_id   = "environment"
}

resource "dynatrace_process_monitoring_rule" "bank_of_anthos_namespace" {
  count = var.deploy_dynatrace_settings_layer && var.dynatrace_enable_bank_of_anthos_process_rule ? 1 : 0

  enabled = true
  mode    = "MONITORING_ON"

  # Enforce deep monitoring for all processes in the BoA namespace.
  condition {
    item     = "KUBERNETES_NAMESPACE"
    operator = "EQUALS"
    value    = var.bank_of_anthos_namespace
  }
}

resource "dynatrace_process_monitoring_rule" "gunicorn" {
  count = var.deploy_dynatrace_settings_layer && var.dynatrace_enable_gunicorn_process_rule ? 1 : 0

  enabled = true
  mode    = "MONITORING_ON"

  # Explicit include for Python web server processes.
  condition {
    item     = "PROCESS_EXECUTABLE"
    operator = "CONTAINS"
    value    = "gunicorn"
  }
}
