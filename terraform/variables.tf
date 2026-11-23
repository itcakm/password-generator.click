variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "password-generator.click"
}

variable "www_subdomain" {
  description = "www subdomain — redirects to apex"
  type        = string
  default     = "www.password-generator.click"
}
