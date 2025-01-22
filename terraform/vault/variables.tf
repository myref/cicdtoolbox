variable "client_secret" {
  description = "Required: OIDC Client secret for Hashicorp Vault"
  type        = string
  default     = ""
}

variable "client_id" {
  description = "Required: OIDC Client ID for Hashicorp Vault"
  type        = string
  default     = ""
}

variable "discovery_url" {
  description = "OIDC Discovery endpoint"
  type        = string
  default     = "https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443/realms/cicdtoolbox"
}

variable "authorized_redirects" {
  description = "List of authorized redirects for CICD Toolbox OIDC"
  type        = list(string)
  default     = ["http://localhost:8250/oidc/callback", "https://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200/ui/vault/auth/oidc/oidc/callback"]
}
