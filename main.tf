###############################################################################
# tf_mod_azuredevops_serviceendpoint_azure — main
#
# Keystone: azuredevops_serviceendpoint_azurerm.this
# Children: azuredevops_serviceendpoint_azurecr.azurecr
# (for_each over var.azurecr_endpoints — no count)
# azuredevops_serviceendpoint_azure_service_bus.service_bus
# (for_each over nonsensitive() keys of var.service_bus_endpoints)
#
# main.tf is a pure projection of the typed input onto provider blocks: dynamic
# blocks for every optional block, try(x, null) on every optional nested field.
###############################################################################

locals {
 # for_each cannot iterate a sensitive collection. The handles (map keys) are
 # caller-supplied and not secret, so unwrap them for iteration; the values
 # (which carry connection_string) are looked up — and kept — sensitive.
 service_bus_keys = nonsensitive(toset(keys(var.service_bus_endpoints)))
}

###############################################################################
# Primary — Azure Resource Manager (ARM) service connection
###############################################################################

resource "azuredevops_serviceendpoint_azurerm" "this" {
 project_id = var.project_id
 service_endpoint_name = var.name
 description = var.description

 azurerm_spn_tenantid = var.azurerm_spn_tenantid
 service_endpoint_authentication_scheme = var.service_endpoint_authentication_scheme

 azurerm_subscription_id = var.azurerm_subscription_id
 azurerm_subscription_name = var.azurerm_subscription_name
 azurerm_management_group_id = var.azurerm_management_group_id
 azurerm_management_group_name = var.azurerm_management_group_name

 environment = var.environment
 server_url = var.server_url
 resource_group = var.resource_group

 # credentials is a sensitive variable — guard the existence check with
 # nonsensitive() so the secret value never lands in for_each.
 dynamic "credentials" {
 for_each = nonsensitive(var.credentials != null) ? [1]: []
 content {
 serviceprincipalid = var.credentials.serviceprincipalid
 serviceprincipalkey = try(var.credentials.serviceprincipalkey, null)
 serviceprincipalcertificate = try(var.credentials.serviceprincipalcertificate, null)
 }
 }

 dynamic "features" {
 for_each = var.features != null ? [var.features]: []
 content {
 validate = try(features.value.validate, false)
 }
 }

 dynamic "timeouts" {
 for_each = length([for k, v in var.timeouts: v if v != null]) > 0 ? [var.timeouts]: []
 content {
 create = try(timeouts.value.create, null)
 read = try(timeouts.value.read, null)
 update = try(timeouts.value.update, null)
 delete = try(timeouts.value.delete, null)
 }
 }
}

###############################################################################
# Child — Azure Container Registry (ACR) service connections
###############################################################################

resource "azuredevops_serviceendpoint_azurecr" "azurecr" {
 for_each = var.azurecr_endpoints

 project_id = var.project_id
 service_endpoint_name = coalesce(try(each.value.service_endpoint_name, null), each.key)
 description = each.value.description

 resource_group = each.value.resource_group
 azurecr_spn_tenantid = each.value.azurecr_spn_tenantid
 azurecr_name = each.value.azurecr_name
 azurecr_subscription_id = each.value.azurecr_subscription_id
 azurecr_subscription_name = each.value.azurecr_subscription_name
 service_endpoint_authentication_scheme = each.value.service_endpoint_authentication_scheme

 dynamic "credentials" {
 for_each = try(each.value.credentials, null) != null ? [each.value.credentials]: []
 content {
 serviceprincipalid = credentials.value.serviceprincipalid
 }
 }

 dynamic "timeouts" {
 for_each = length([for k, v in try(each.value.timeouts, {}): v if v != null]) > 0 ? [each.value.timeouts]: []
 content {
 create = try(timeouts.value.create, null)
 read = try(timeouts.value.read, null)
 update = try(timeouts.value.update, null)
 delete = try(timeouts.value.delete, null)
 }
 }
}

###############################################################################
# Child — Azure Service Bus service connections
#
# var.service_bus_endpoints is sensitive (carries connection_string). for_each
# cannot iterate a sensitive collection, so iterate the nonsensitive() key set
# and look up each (still-sensitive) value by key.
###############################################################################

resource "azuredevops_serviceendpoint_azure_service_bus" "service_bus" {
 for_each = local.service_bus_keys

 project_id = var.project_id
 # Only connection_string is a true secret. The remaining fields inherited the
 # sensitive mark from the bundling variable — unwrap them so plans stay
 # readable; connection_string alone is passed through sensitive.
 service_endpoint_name = nonsensitive(coalesce(try(var.service_bus_endpoints[each.key].service_endpoint_name, null), each.key))
 description = nonsensitive(var.service_bus_endpoints[each.key].description)

 queue_name = nonsensitive(var.service_bus_endpoints[each.key].queue_name)
 connection_string = var.service_bus_endpoints[each.key].connection_string

 dynamic "timeouts" {
 for_each = length([for k, v in nonsensitive(var.service_bus_endpoints[each.key].timeouts): v if v != null]) > 0 ? [nonsensitive(var.service_bus_endpoints[each.key].timeouts)]: []
 content {
 create = try(timeouts.value.create, null)
 read = try(timeouts.value.read, null)
 update = try(timeouts.value.update, null)
 delete = try(timeouts.value.delete, null)
 }
 }
}
