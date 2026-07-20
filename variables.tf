###############################################################################
# tf_mod_azuredevops_serviceendpoint_azure — variables
#
# Composite module. Primary resource (`this`):
# azuredevops_serviceendpoint_azurerm (Azure Resource Manager service connection)
#
# Optional child collections (for_each over map(object(...)), no count):
# azuredevops_serviceendpoint_azurecr (Azure Container Registry)
# azuredevops_serviceendpoint_azure_service_bus (Azure Service Bus)
#
# Variable order (house style):
# name -> project_id -> required identity refs -> optional config (primary) ->
# child collections -> timeouts
#
# Secret fields (serviceprincipalkey, serviceprincipalcertificate,
# connection_string) are WRITE-ONLY — the provider cannot read them back. The
# containing variables are marked `sensitive = true` and treated as rotation-only.
###############################################################################

variable "name" {
 description = <<EOT
The Service Endpoint name for the primary Azure Resource Manager (ARM) service
connection (azuredevops_serviceendpoint_azurerm). Required.

This is the name pipelines reference in the `azureSubscription` task input.
EOT
 type = string

 validation {
 condition = length(trimspace(var.name)) > 0
 error_message = "name must be a non-empty string."
 }
}

variable "project_id" {
 description = <<EOT
The ID of the project these service connections belong to. IMMUTABLE — changing
this forces destroy/recreate of every endpoint. Wire from
tf_mod_azuredevops_project (project_id output).
EOT
 type = string

 validation {
 condition = length(trimspace(var.project_id)) > 0
 error_message = "project_id must be a non-empty string (wire from tf_mod_azuredevops_project)."
 }
}

variable "azurerm_spn_tenantid" {
 description = <<EOT
The Microsoft Entra (Azure AD) Tenant ID of the service principal / managed
identity backing the ARM service connection. Required.
EOT
 type = string

 validation {
 condition = length(trimspace(var.azurerm_spn_tenantid)) > 0
 error_message = "azurerm_spn_tenantid must be a non-empty string."
 }
}

###############################################################################
# Primary ARM endpoint — optional configuration
###############################################################################

variable "service_endpoint_authentication_scheme" {
 description = <<EOT
Authentication scheme for the primary ARM service connection. One of:
 - "ServicePrincipal" (default; uses the `credentials` block)
 - "WorkloadIdentityFederation" (OIDC — preferred; no stored secret)
 - "ManagedServiceIdentity" (MI on the agent; no stored secret)

Prefer WorkloadIdentityFederation where the org is enrolled — it avoids storing
a service-principal secret at all (see SCOPE.md provider gotchas).
EOT
 type = string
 default = "ServicePrincipal"

 validation {
 condition = contains(["ServicePrincipal", "WorkloadIdentityFederation", "ManagedServiceIdentity"], var.service_endpoint_authentication_scheme)
 error_message = "service_endpoint_authentication_scheme must be one of: ServicePrincipal, WorkloadIdentityFederation, ManagedServiceIdentity."
 }
}

variable "description" {
 description = "Description of the primary ARM service connection."
 type = string
 default = "Managed by Terraform"
}

variable "azurerm_subscription_id" {
 description = <<EOT
Subscription ID the ARM service connection targets. Set this together with
azurerm_subscription_name for a Subscription-scoped connection.

NOTE: the provider requires EITHER a Subscription scope
(azurerm_subscription_id + azurerm_subscription_name) OR a Management Group
scope (azurerm_management_group_id + azurerm_management_group_name).
EOT
 type = string
 default = null
}

variable "azurerm_subscription_name" {
 description = "Subscription Name the ARM service connection targets. Pair with azurerm_subscription_id."
 type = string
 default = null
}

variable "azurerm_management_group_id" {
 description = <<EOT
Management Group ID the ARM service connection targets. Set this together with
azurerm_management_group_name for a Management Group-scoped connection (instead
of a Subscription scope).
EOT
 type = string
 default = null
}

variable "azurerm_management_group_name" {
 description = "Management Group Name the ARM service connection targets. Pair with azurerm_management_group_id."
 type = string
 default = null
}

variable "environment" {
 description = <<EOT
The Azure cloud environment the ARM service connection targets. IMMUTABLE —
changing this forces a new resource. One of: AzureCloud, AzureChinaCloud,
AzureUSGovernment, AzureGermanCloud, AzureStack.
EOT
 type = string
 default = "AzureCloud"

 validation {
 condition = contains(["AzureCloud", "AzureChinaCloud", "AzureUSGovernment", "AzureGermanCloud", "AzureStack"], var.environment)
 error_message = "environment must be one of: AzureCloud, AzureChinaCloud, AzureUSGovernment, AzureGermanCloud, AzureStack."
 }
}

variable "server_url" {
 description = <<EOT
The server URL of the ARM service connection. IMMUTABLE — changing this forces a
new resource. Only set for AzureStack or other non-default endpoints.
EOT
 type = string
 default = null
}

variable "resource_group" {
 description = "The resource group used for the scope of an automatic ARM service connection. Optional."
 type = string
 default = null
}

variable "credentials" {
 description = <<EOT
Service-principal credentials for the primary ARM service connection. Required
only when service_endpoint_authentication_scheme = "ServicePrincipal". Omit for
WorkloadIdentityFederation / ManagedServiceIdentity (which store no secret).

{
 serviceprincipalid = string # SP application (client) ID — required when set
 serviceprincipalkey = optional(string) # SP client secret — WRITE-ONLY, sensitive
 serviceprincipalcertificate = optional(string) # SP certificate (PEM) — WRITE-ONLY, sensitive
}

For WorkloadIdentityFederation you may still supply only serviceprincipalid
(the federated identity's client ID) with no key/certificate.

NOTE: serviceprincipalkey / serviceprincipalcertificate cannot be read back from
the API — treat as rotation-only. The whole variable is marked sensitive.
EOT
 type = object({
 serviceprincipalid = string
 serviceprincipalkey = optional(string)
 serviceprincipalcertificate = optional(string)
 })
 default = null
 sensitive = true
}

variable "features" {
 description = <<EOT
Optional behavioural features for the primary ARM service connection.

{
 validate = optional(bool, false) # validate the connection against Azure on create/update
}

Omit (null) to skip the features block entirely.
EOT
 type = object({
 validate = optional(bool, false)
 })
 default = null
}

###############################################################################
# Child collection — Azure Container Registry (ACR) service connections
###############################################################################

variable "azurecr_endpoints" {
 description = <<EOT
Map of Azure Container Registry (ACR) service connections, keyed by a
caller-supplied stable handle. The handle is the default service_endpoint_name.

{
 "<handle>" = {
 service_endpoint_name = optional(string) # defaults to the map key
 resource_group = string # RG of the registry (required)
 azurecr_spn_tenantid = string # SP tenant ID (required)
 azurecr_name = string # ACR name (required)
 azurecr_subscription_id = string # target subscription ID (required)
 azurecr_subscription_name = string # target subscription name (required)
 service_endpoint_authentication_scheme = optional(string, "ServicePrincipal") # or "WorkloadIdentityFederation"
 description = optional(string, "Managed by Terraform")
 credentials = optional(object({
 serviceprincipalid = string # SP application (client) ID — no secret stored for ACR
 }))
 timeouts = optional(object({
 create = optional(string) # default 2m
 read = optional(string) # default 1m
 update = optional(string) # default 2m
 delete = optional(string) # default 2m
 }), {})
 }
}

NOTE: the ACR endpoint stores NO service-principal secret — the `credentials`
block carries only serviceprincipalid. ManagedServiceIdentity is not yet
implemented by the provider for ACR.
EOT
 type = map(object({
 service_endpoint_name = optional(string)
 resource_group = string
 azurecr_spn_tenantid = string
 azurecr_name = string
 azurecr_subscription_id = string
 azurecr_subscription_name = string
 service_endpoint_authentication_scheme = optional(string, "ServicePrincipal")
 description = optional(string, "Managed by Terraform")
 credentials = optional(object({
 serviceprincipalid = string
 }))
 timeouts = optional(object({
 create = optional(string)
 read = optional(string)
 update = optional(string)
 delete = optional(string)
 }), {})
 }))
 default = {}

 validation {
 condition = alltrue([
 for k, v in var.azurecr_endpoints: contains(["ServicePrincipal", "WorkloadIdentityFederation"], v.service_endpoint_authentication_scheme)
 ])
 error_message = "Each azurecr_endpoints entry's service_endpoint_authentication_scheme must be one of: ServicePrincipal, WorkloadIdentityFederation (ManagedServiceIdentity is not implemented for ACR)."
 }

 validation {
 condition = alltrue([
 for k, v in var.azurecr_endpoints:
 length(trimspace(v.resource_group)) > 0 &&
 length(trimspace(v.azurecr_spn_tenantid)) > 0 &&
 length(trimspace(v.azurecr_name)) > 0 &&
 length(trimspace(v.azurecr_subscription_id)) > 0 &&
 length(trimspace(v.azurecr_subscription_name)) > 0
 ])
 error_message = "Each azurecr_endpoints entry must set non-empty resource_group, azurecr_spn_tenantid, azurecr_name, azurecr_subscription_id, and azurecr_subscription_name."
 }
}

###############################################################################
# Child collection — Azure Service Bus service connections (SENSITIVE)
###############################################################################

variable "service_bus_endpoints" {
 description = <<EOT
Map of Azure Service Bus service connections, keyed by a caller-supplied stable
handle. The handle is the default service_endpoint_name.

{
 "<handle>" = {
 service_endpoint_name = optional(string) # defaults to the map key
 queue_name = string # Service Bus queue name (required)
 connection_string = string # Service Bus connection string (required) — WRITE-ONLY, sensitive
 description = optional(string, "Managed by Terraform")
 timeouts = optional(object({
 create = optional(string) # default 2m
 read = optional(string) # default 1m
 update = optional(string) # default 2m
 delete = optional(string) # default 2m
 }), {})
 }
}

NOTE: connection_string is a secret the provider cannot read back — treat as
rotation-only. The ENTIRE variable is marked sensitive; main.tf iterates over
nonsensitive() endpoint keys so the secret values never leave the sensitive
domain.
EOT
 type = map(object({
 service_endpoint_name = optional(string)
 queue_name = string
 connection_string = string
 description = optional(string, "Managed by Terraform")
 timeouts = optional(object({
 create = optional(string)
 read = optional(string)
 update = optional(string)
 delete = optional(string)
 }), {})
 }))
 default = {}
 sensitive = true

 validation {
 condition = nonsensitive(alltrue([
 for k, v in var.service_bus_endpoints:
 length(trimspace(v.queue_name)) > 0 && length(trimspace(v.connection_string)) > 0
 ]))
 error_message = "Each service_bus_endpoints entry must set a non-empty queue_name and connection_string."
 }
}

###############################################################################
# Timeouts — primary ARM endpoint
###############################################################################

variable "timeouts" {
 description = <<EOT
Optional Terraform operation timeouts for the primary ARM service connection.
{
 create = optional(string) # default 2m
 read = optional(string) # default 1m
 update = optional(string) # default 2m
 delete = optional(string) # default 2m
}
EOT
 type = object({
 create = optional(string)
 read = optional(string)
 update = optional(string)
 delete = optional(string)
 })
 default = {}
}
