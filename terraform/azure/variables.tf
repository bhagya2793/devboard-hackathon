variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "Central India"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "devboard"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "node_vm_size" {
  description = "AKS node VM size"
  type        = string
  default     = "Standard_B4ms"
}
