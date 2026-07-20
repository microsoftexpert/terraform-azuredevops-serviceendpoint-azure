###############################################################################
# tf_mod_azuredevops_serviceendpoint_azure — outputs
#
# Primary output is `id`; the resource-specific `service_endpoint_id` is also
# emitted for cross-module wiring (build_definition, environment,
# pipeline_checks, serviceendpoint_permissions). Child endpoint IDs are emitted
# as maps keyed by the caller's handle.
#
# No secret is ever emitted — service_principal_key / certificate /
# connection_string are WRITE-ONLY and must never appear in outputs or logs.
###############################################################################

output "id" {
 description = "The ID of the primary ARM service connection (azuredevops_serviceendpoint_azurerm)."
 value = azuredevops_serviceendpoint_azurerm.this.id
}

output "service_endpoint_id" {
 description = "The primary ARM service connection ID — consumed by tf_mod_azuredevops_build_definition, environment, pipeline_checks, and serviceendpoint_permissions."
 value = azuredevops_serviceendpoint_azurerm.this.id
}

output "name" {
 description = "The name of the primary ARM service connection."
 value = azuredevops_serviceendpoint_azurerm.this.service_endpoint_name
}

output "project_id" {
 description = "The project ID these service connections belong to (echoed for downstream convenience)."
 value = azuredevops_serviceendpoint_azurerm.this.project_id
}

output "service_principal_id" {
 description = "The application (client) ID of the service principal backing the ARM connection. Not a secret."
 value = azuredevops_serviceendpoint_azurerm.this.service_principal_id
}

output "workload_identity_federation_issuer" {
 description = <<EOT
The OIDC issuer of the ARM connection when
service_endpoint_authentication_scheme = "WorkloadIdentityFederation". Wire this
into an azurerm_federated_identity_credential.issuer. Empty for other schemes.
EOT
 value = try(azuredevops_serviceendpoint_azurerm.this.workload_identity_federation_issuer, null)
}

output "workload_identity_federation_subject" {
 description = <<EOT
The OIDC subject of the ARM connection when
service_endpoint_authentication_scheme = "WorkloadIdentityFederation". Wire this
into an azurerm_federated_identity_credential.subject. Empty for other schemes.
EOT
 value = try(azuredevops_serviceendpoint_azurerm.this.workload_identity_federation_subject, null)
}

###############################################################################
# Child endpoints
###############################################################################

output "azurecr_endpoint_ids" {
 description = "Map of Azure Container Registry service connection IDs, keyed by the azurecr_endpoints handle."
 value = { for k, e in azuredevops_serviceendpoint_azurecr.azurecr: k => e.id }
}

output "azurecr_endpoints" {
 description = <<EOT
Map of Azure Container Registry service connections created by this module,
keyed by the azurecr_endpoints handle. Each value exposes id, name, and
service_principal_id.
EOT
 value = {
 for k, e in azuredevops_serviceendpoint_azurecr.azurecr: k => {
 id = e.id
 name = e.service_endpoint_name
 service_principal_id = e.service_principal_id
 }
 }
}

output "service_bus_endpoint_ids" {
 description = "Map of Azure Service Bus service connection IDs, keyed by the service_bus_endpoints handle."
 value = { for k, e in azuredevops_serviceendpoint_azure_service_bus.service_bus: k => e.id }
}

output "service_bus_endpoints" {
 description = <<EOT
Map of Azure Service Bus service connections created by this module, keyed by
the service_bus_endpoints handle. Each value exposes id and name. The secret
connection_string is never emitted.
EOT
 value = {
 for k, e in azuredevops_serviceendpoint_azure_service_bus.service_bus: k => {
 id = e.id
 name = e.service_endpoint_name
 }
 }
}

output "service_endpoint_ids" {
 description = <<EOT
All service connection IDs managed by this module in one map: the primary ARM
connection under key "azurerm", plus every ACR and Service Bus child keyed by
its handle. Convenient for bulk wiring into serviceendpoint_permissions.
EOT
 value = merge({ azurerm = azuredevops_serviceendpoint_azurerm.this.id },
 { for k, e in azuredevops_serviceendpoint_azurecr.azurecr: k => e.id },
 { for k, e in azuredevops_serviceendpoint_azure_service_bus.service_bus: k => e.id },)
}
