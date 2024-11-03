variable "function_app_resource_group_name" {
  description = "(Required) The name of the resource group to create the resources for the function app."
  type        = string
}

variable "shared_resource_group_name" {
  description = "(Required) The name of the shared resource group to create and reference shared resources (like databases and keyvaults etc)."
  type        = string
}

variable "location" {
  description = "(Optional) The Azure region to place your resources in. Defaults to australiaeast."
  type        = string
  default     = "australiaeast"
}

variable "function_app_subnet_id" {
  description = "(Required) The subnet id for the function app."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "(Required) The subnet id for the private endpoints."
  type        = string
}

variable "function_app_storage_account_name" {
  description = "(Required) The name of the storage account to used by the function app."
  type        = string
}

variable "file_share_name" {
  description = "(Required) The name of the file share to be referenced in the storage account of the function app. Ensure that this exists."
  type        = string
}

variable "shared_storage_account_name" {
  description = "(Required) The name of the shared storage account."
  type        = string
}

variable "tags" {
  description = "(Optional) The tags to assign to each infrastructure resource."
  type        = map(string)
  default     = {}
}
