# SCOPE — `tf-mod-azuredevops-serviceendpoint-azure`

> **Module type:** `composite`  ·  **Provider:** `microsoft/azuredevops` (`>= 1.0, < 2.0`)  ·  **Scope:** project-scoped

Azure-family service connections (ARM, ACR, Service Bus). Secret fields are write-only — mark sensitive. Consumes project_id.

---

## In-scope resources

Primary resource (`this`): **`azuredevops_serviceendpoint_azurerm`**. Tightly-coupled children are managed via `for_each` over `map(object(...))`.

- `azuredevops_serviceendpoint_azurerm`  ← primary `this`
- `azuredevops_serviceendpoint_azurecr`
- `azuredevops_serviceendpoint_azure_service_bus`

## Out-of-scope resources (consumed by ID)

- `azuredevops_project` — provided as `project_id` by `tf-mod-azuredevops-project`.

## Consumes

| Input | Type | Source module |
|---|---|---|
| `project_id` | string | `tf-mod-azuredevops-project` |

## Required Azure DevOps scopes / auth

| Scope / Role | PAT scope | Service-principal role | Required for |
|---|---|---|---|
| Service Connections | Service Connections (Read, Query & Manage) | Administrator/Creator on the `ServiceEndpoints` security namespace (via Endpoint Administrators) | creating/managing azurerm, azurecr, azure_service_bus endpoints |
| Endpoint Administrators | — | Membership in the project **Endpoint Administrators** group | endpoint security / management |

- **Sharing** an endpoint cross-project requires an **organization-level administrator** — NOT performed by this module.
- This module runs in **manual** mode (caller supplies the identity); it does **not** create Entra app registrations. *Automatic* endpoint creation would also need **Application Developer** / app-registration rights in the Entra tenant.
- **Workload Identity Federation**: the federated credential is created OUTSIDE this module (Entra ID / `hashicorp/azurerm`) using the `workload_identity_federation_issuer` / `_subject` outputs.

## Emits

| Output | Description | Consumed by |
|---|---|---|
| `id` | Primary resource ID (`azuredevops_serviceendpoint_azurerm`) | downstream module references |
| `service_endpoint_id` | Resource-specific ID for cross-module wiring | tf-mod-azuredevops-build-definition, environment, pipeline_checks, serviceendpoint_permissions |
| `name` | Resource name | logging / audit |
| _(secrets)_ | **Never emitted** — service-connection / Key Vault secrets are write-only and `sensitive` | n/a |

## Provider gotchas

- Secret fields are WRITE-ONLY — the provider cannot read them back; mark sensitive and treat as rotation-only:
  - azurerm `credentials.serviceprincipalkey` / `serviceprincipalcertificate`
  - azure_service_bus `connection_string`
- **azurecr stores NO secret** — its `credentials` block carries only `serviceprincipalid` (no key field). `ManagedServiceIdentity` is **not yet implemented** for ACR — the typed enum allows only `ServicePrincipal` / `WorkloadIdentityFederation`.
- **azure_service_bus has no auth scheme** — it is connection-string only (no `service_endpoint_authentication_scheme`).
- **Sensitive `for_each`**: `service_bus_endpoints` is a sensitive variable; Terraform forbids a sensitive value as a `for_each` arg. main.tf iterates `nonsensitive(toset(keys(...)))` and looks up each value by key, keeping `connection_string` sensitive while unwrapping non-secret fields. The `credentials` existence check is guarded with `nonsensitive(var.credentials != null)`.
- Workload identity federation (OIDC) endpoints avoid storing a secret — prefer where supported. `workload_identity_federation_issuer` / `_subject` are only populated for the WIF scheme and feed an Entra federated credential created out-of-band.
- ARM scope is **exclusive**: provide a subscription scope (id + name) OR a management-group scope (id + name), not both/neither.
- `azuredevops_pipeline_authorization` (allow_access) is a separate resource — wire it explicitly to let a pipeline use the endpoint.
- Immutable fields force destroy/recreate: `project_id`, `environment`, `server_url`.
- Validated against provider **v1.15.1**. `terraform validate` + `fmt -check` pass; a two-case offline `plan` confirms the sensitive `for_each` / `nonsensitive()` paths.

## Design decisions

- Composite keystone azuredevops_serviceendpoint_azurerm.this; ACR and Service Bus are the Azure-family siblings.
- Azure family separated from other endpoints because they share workload-identity / ARM auth patterns.

---

> Regenerate the RAG index after editing this file: `ingest_internal_standards_azuredevops.py`.
