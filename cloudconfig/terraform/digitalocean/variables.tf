# cloudconfigs/terraform/digitalocean/variables.tf

variable "do_token" {
  description = "Your DigitalOcean API token."
  type        = string
  sensitive   = true
}

variable "do_region" {
  description = "The DigitalOcean region to deploy resources in."
  type        = string
  default     = "nyc1"
}

variable "cluster_name" {
  description = "The name of the DOKS cluster."
  type        = string
  default     = "discordlinked-cluster"
}
