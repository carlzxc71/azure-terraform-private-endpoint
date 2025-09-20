variable "location" {
  description = "The Azure region to deploy resources in."
  type        = string
}

variable "location_short" {
  description = "Short code for the Azure region."
  type        = string
}

variable "environment" {
  description = "The environment for the resources (e.g., dev, prd)."
  type        = string
}
