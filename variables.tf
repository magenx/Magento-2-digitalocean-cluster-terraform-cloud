# Define variables
variable "do_token" {
  description = "DigitakOcean Cloud API token"
  type        = string
}

variable "bearer" {
  description = "Configuration auth password"
  type        = string
}

variable "region" {
  description = "Name of region"
  type        = string
  default     = ""
}

variable "project" {
  description = "The name of the project"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "app" {
  description = "Application name"
  type        = string
}

variable "protection" {
  description = "Enable or disable delete protection"
  type        = bool
}

locals {
  tags = {
    "project" = var.project
    "app"     = var.app
    "env"     = var.env
  }
}

# Create managed databases
## {  mysql = { version = "8" node_count = "1" size = "db-s-2vcpu-4gb" } redis = { version = "6" node_count = "1" size = "db-s-1vcpu-2gb" } }
variable "database" {
  type = map(object({
    version    = string
    node_count = string
    size       = string
  }))
  default = {}
}

## HCL type variable in Terraform Cloud
## { elasticsearch = "s-1vcpu-2gb-intel", rabbitmq = "s-1vcpu-1gb-intel", media = "s-1vcpu-1gb-intel", varnish = "s-1vcpu-2gb-intel", frontend = "s-4vcpu-8gb-intel" }
variable "servers" {
  description = "A map of server types"
  type        = map(string)
  default     = {}
}

variable "domain" {
  description = "Domain"
  type        = string
}

variable "download_magento" {
  description = "Download Magento"
  type        = string
}

variable "version_installed" {
  description = "Magento Version Installed"
  type        = string
}

variable "apply_magento_config" {
  description = "Apply Magento Configuration"
  type        = string
}

variable "php_version" {
  description = "PHP Version"
  type        = string
}

variable "timezone" {
  description = "Timezone"
  type        = string
}

variable "locale" {
  description = "Locale"
  type        = string
}

variable "currency" {
  description = "Currency"
  type        = string
}

variable "admin_first_name" {
  description = "Admin First Name"
  type        = string
}

variable "admin_last_name" {
  description = "Admin Last Name"
  type        = string
}

variable "admin_login" {
  description = "Admin Login"
  type        = string
}

variable "admin_email" {
  description = "Admin Email"
  type        = string
}
