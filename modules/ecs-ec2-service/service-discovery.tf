resource "aws_service_discovery_service" "this" {
  count = var.enable_service_discovery ? 1 : 0

  name        = var.service_name
  description = var.service_discovery_description

  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      type = "A"
      ttl  = var.service_discovery_dns_ttl
    }
  }

  dynamic "health_check_custom_config" {
    for_each = var.service_discovery_health_check_failure_threshold == null ? [] : [1]
    content {
      failure_threshold = var.service_discovery_health_check_failure_threshold
    }
  }
}
