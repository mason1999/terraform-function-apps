################################################################################
# Tenant ID
################################################################################
data "azurerm_client_config" "current" {}

################################################################################
# Managed Identity
################################################################################
resource "azurerm_user_assigned_identity" "default_mi" {
  location            = var.location
  resource_group_name = var.function_app_resource_group_name
  name                = "default-mi"
  tags                = var.tags
}

################################################################################
# Jumpbox
################################################################################
module "function_push_virtual_machine" {
  source = "git::https://github.com/mason1999/terraform-linux-vm?ref=feat/function-apps"

  resource_group_name           = var.function_app_resource_group_name
  location                      = var.location
  suffix                        = "push"
  subnet_id                     = var.private_endpoint_subnet_id
  enable_public_ip_address      = true
  private_ip_address_allocation = "Static"
  private_ip_address            = "10.0.1.11"
  admin_username                = "testuser"
  admin_password                = "WeakPassword123"
  run_init_script               = true

  identity = {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.default_mi.id]
  }
}

################################################################################
# Function App Storage Account
################################################################################
resource "azurerm_storage_account" "function_app_storage_account" {
  name                            = var.function_app_storage_account_name
  resource_group_name             = var.function_app_resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  shared_access_key_enabled       = true
  default_to_oauth_authentication = true
  public_network_access_enabled   = var.public_access_enabled # TODO
  tags                            = var.tags
  provisioner "local-exec" {
    when    = create
    command = <<EOF
    az storage share-rm create \
      --resource-group ${var.function_app_resource_group_name} \
      --storage-account ${self.name} \
      --name ${var.file_share_name} \
      --quota 100000
    EOF
  }
}

################################################################################
# Private DNS zone and endpoint (blob) for Function App Storage Account
################################################################################
resource "azurerm_private_dns_zone" "blob_dns_zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.shared_resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_dns_zone_vnet_link" {
  name                  = "blob-link-function-app"
  resource_group_name   = var.shared_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob_dns_zone.name
  virtual_network_id    = regex("(/subscriptions/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/resourceGroups/[\\w-]{1,90}/providers/Microsoft.Network/virtualNetworks/[\\w-]{2,64})/subnets/[\\w-]{2,64}", var.private_endpoint_subnet_id)[0]
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "function_app_blob" {
  name                = "blob-private-endpoint-function-app"
  location            = var.location
  resource_group_name = var.function_app_resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "blob-private-service-connection-function-app"
    private_connection_resource_id = azurerm_storage_account.function_app_storage_account.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "blob-dns-zone-group-function-app"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob_dns_zone.id]
  }
  tags = var.tags
}

################################################################################
# Private DNS zone and endpoint (file) for Function App Storage Account
################################################################################
resource "azurerm_private_dns_zone" "file_dns_zone" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.shared_resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "file_dns_zone_vnet_link" {
  name                  = "file-link-function-app"
  resource_group_name   = var.shared_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.file_dns_zone.name
  virtual_network_id    = regex("(/subscriptions/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/resourceGroups/[\\w-]{1,90}/providers/Microsoft.Network/virtualNetworks/[\\w-]{2,64})/subnets/[\\w-]{2,64}", var.private_endpoint_subnet_id)[0]
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "function_app_file" {
  name                = "file-private-endpoint-function-app"
  location            = var.location
  resource_group_name = var.function_app_resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "file-private-service-connection-function-app"
    private_connection_resource_id = azurerm_storage_account.function_app_storage_account.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "file-dns-zone-group-function-app"
    private_dns_zone_ids = [azurerm_private_dns_zone.file_dns_zone.id]
  }
  tags = var.tags
}


################################################################################
# Private DNS zone and endpoint (table) for Function App Storage Account
################################################################################
resource "azurerm_private_dns_zone" "table_dns_zone" {
  name                = "privatelink.table.core.windows.net"
  resource_group_name = var.shared_resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "table_dns_zone_vnet_link" {
  name                  = "table-link-function-app"
  resource_group_name   = var.shared_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.table_dns_zone.name
  virtual_network_id    = regex("(/subscriptions/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/resourceGroups/[\\w-]{1,90}/providers/Microsoft.Network/virtualNetworks/[\\w-]{2,64})/subnets/[\\w-]{2,64}", var.private_endpoint_subnet_id)[0]
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "function_app_table" {
  name                = "table-private-endpoint-function-app"
  location            = var.location
  resource_group_name = var.function_app_resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "table-private-service-connection-function-app"
    private_connection_resource_id = azurerm_storage_account.function_app_storage_account.id
    subresource_names              = ["table"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "table-dns-zone-group-function-app"
    private_dns_zone_ids = [azurerm_private_dns_zone.table_dns_zone.id]
  }
  tags = var.tags
}


################################################################################
# Private DNS zone and endpoint (queue) for Function App Storage Account
################################################################################
resource "azurerm_private_dns_zone" "queue_dns_zone" {
  name                = "privatelink.queue.core.windows.net"
  resource_group_name = var.shared_resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "queue_dns_zone_vnet_link" {
  name                  = "queue-link-function-app"
  resource_group_name   = var.shared_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.queue_dns_zone.name
  virtual_network_id    = regex("(/subscriptions/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/resourceGroups/[\\w-]{1,90}/providers/Microsoft.Network/virtualNetworks/[\\w-]{2,64})/subnets/[\\w-]{2,64}", var.private_endpoint_subnet_id)[0]
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "function_app_queue" {
  name                = "queue-private-endpoint-function-app"
  location            = var.location
  resource_group_name = var.function_app_resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "queue-private-service-connection-function-app"
    private_connection_resource_id = azurerm_storage_account.function_app_storage_account.id
    subresource_names              = ["queue"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "queue-dns-zone-group-function-app"
    private_dns_zone_ids = [azurerm_private_dns_zone.queue_dns_zone.id]
  }
  tags = var.tags
}


################################################################################
# Shared storage account
################################################################################
resource "azurerm_storage_account" "shared_storage_account" {
  name                            = var.shared_storage_account_name
  resource_group_name             = var.shared_resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  shared_access_key_enabled       = false
  public_network_access_enabled   = true # TODO
  default_to_oauth_authentication = true
  tags                            = var.tags
}

################################################################################
# Private DNS zone and endpoint (table) for Shared Storage Account
################################################################################
resource "azurerm_private_endpoint" "function_app_table_shared_storage" {
  name                = "table-private-endpoint-shared-storage"
  location            = var.location
  resource_group_name = var.shared_resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "table-private-service-connection-shared-storage"
    private_connection_resource_id = azurerm_storage_account.shared_storage_account.id
    subresource_names              = ["table"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "table-dns-zone-group-shared-storage"
    private_dns_zone_ids = [azurerm_private_dns_zone.table_dns_zone.id]
  }
  tags = var.tags
}

################################################################################
# Private DNS zone and endpoint (queue) for Shared Storage Account
################################################################################
resource "azurerm_private_endpoint" "function_app_queue_shared_storage" {
  name                = "queue-private-endpoint-shared-storage"
  location            = var.location
  resource_group_name = var.shared_resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "queue-private-service-connection-shared-storage"
    private_connection_resource_id = azurerm_storage_account.shared_storage_account.id
    subresource_names              = ["queue"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "queue-dns-zone-group-shared-storage"
    private_dns_zone_ids = [azurerm_private_dns_zone.queue_dns_zone.id]
  }
  tags = var.tags
}


################################################################################
# Key Vault And Private DNS Zone / Private Endpoints
################################################################################
resource "azurerm_key_vault" "shared_key_vault" {
  name                          = "mason-shared-key-vault-1"
  location                      = var.location
  resource_group_name           = var.shared_resource_group_name
  sku_name                      = "standard"
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption   = true
  purge_protection_enabled      = false
  enable_rbac_authorization     = true
  public_network_access_enabled = var.public_access_enabled # TODO
  soft_delete_retention_days    = 7
  tags                          = var.tags

  depends_on = [
    azurerm_storage_account.function_app_storage_account
  ]

  provisioner "local-exec" {
    when    = create
    command = <<EOF
    az keyvault secret set \
      --vault-name ${self.name} \
      --name ${var.connection_name_secret} \
      --value "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.function_app_storage_account.name};AccountKey=${azurerm_storage_account.function_app_storage_account.primary_access_key};EndpointSuffix=core.windows.net"
    EOF
  }
}

resource "terraform_data" "destroy_connection_name_secret" {
  count = var.destroy_connection_name_secret ? 1 : 0

  provisioner "local-exec" {
    when    = create
    command = <<EOF
    az keyvault secret delete \
      --vault-name ${azurerm_key_vault.shared_key_vault.name} \
      --name ${var.connection_name_secret}

    az keyvault secret purge \
      --vault-name ${azurerm_key_vault.shared_key_vault.name} \
      --name ${var.connection_name_secret}
    EOF
  }

}

resource "azurerm_private_dns_zone" "keyvault_dns_zone" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.shared_resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_dns_zone_vnet_link" {
  name                  = "keyvault-link"
  resource_group_name   = var.shared_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault_dns_zone.name
  virtual_network_id    = regex("(/subscriptions/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/resourceGroups/[\\w-]{1,90}/providers/Microsoft.Network/virtualNetworks/[\\w-]{2,64})/subnets/[\\w-]{2,64}", var.private_endpoint_subnet_id)[0]
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "shared_keyvault" {
  name                = "keyvault-private-endpoint"
  location            = var.location
  resource_group_name = var.function_app_resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "keyvault-private-service-connection"
    private_connection_resource_id = azurerm_key_vault.shared_key_vault.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "keyvault-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault_dns_zone.id]
  }
  tags = var.tags
}

################################################################################
# App Service Plan
################################################################################
resource "azurerm_service_plan" "asp_testingapp" {
  name                         = "asp-testingapp"
  resource_group_name          = var.function_app_resource_group_name
  location                     = var.location
  os_type                      = "Windows"
  sku_name                     = "EP2"
  maximum_elastic_worker_count = 10
  worker_count                 = 5
  zone_balancing_enabled       = true
  tags                         = var.tags
}

################################################################################
# Function App
################################################################################

resource "azurerm_windows_function_app" "fa_testingapp" {
  name                = "fa-masonapp"
  resource_group_name = var.function_app_resource_group_name
  location            = var.location

  storage_account_name            = azurerm_storage_account.function_app_storage_account.name
  storage_account_access_key      = azurerm_storage_account.function_app_storage_account.primary_access_key
  key_vault_reference_identity_id = azurerm_user_assigned_identity.default_mi.id

  service_plan_id           = azurerm_service_plan.asp_testingapp.id
  virtual_network_subnet_id = var.function_app_subnet_id

  functions_extension_version = "~4"
  https_only                  = true
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.default_mi.id]
  }

  public_network_access_enabled = var.public_access_enabled # TODO

  app_settings = {

    ####################################################################################################################################
    # Arhives files and mounts it as a read only section to C:\home\site\wwwroot. Mutually exclusive to SCM_DO_BUILD_DURING_DEPLOYMENT #
    ####################################################################################################################################
    WEBSITE_RUN_FROM_PACKAGE = 1

    #############################################
    # Tenants which are allowed to authenticate #
    #############################################
    WEBSITE_AUTH_ADD_ALLOWED_TENANTS = data.azurerm_client_config.current.tenant_id

    #################################################################################################################################################
    # Default backend storage account: These values will get populated automatically, so we must intentionally put them in the code to hide secrets #
    #################################################################################################################################################
    AzureWebJobsStorage = "@Microsoft.KeyVault(SecretUri=https://${azurerm_key_vault.shared_key_vault.name}.vault.azure.net/secrets/${var.connection_name_secret})" # Connection string for storage account where the function app code is stored.

    #########################################################################
    # Shared storage account connection: Covers Blob, Queue and Table URI's #
    #########################################################################
    SharedStorageAccount__credential  = "managedidentity"
    SharedStorageAccount__clientId    = azurerm_user_assigned_identity.default_mi.client_id
    SharedStorageAccount__accountName = azurerm_storage_account.shared_storage_account.name


    ####################################################################################################################################################
    # Azure files share: Set the share name, the authentication,  and ignore validation because of the key vault reference (cannot resolve at runtime).#
    ####################################################################################################################################################
    WEBSITE_CONTENTSHARE                     = var.file_share_name                                                                                                                       # The name of the file share which is used for the backend function app code.
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = "@Microsoft.KeyVault(SecretUri=https://${azurerm_key_vault.shared_key_vault.name}.vault.azure.net/secrets/${var.connection_name_secret})" # Connection string for storage account where the function app code is stored.
    WEBSITE_CONTENTOVERVNET                  = 1                                                                                                                                         # Equivalent to th site setting vnetContentShareEnabled (not available in Terraform). It allows function app to properly communicate with file share.
    WEBSITE_SKIP_CONTENTSHARE_VALIDATION     = 1
  }
  site_config {
    pre_warmed_instance_count = 5
    application_stack {
      dotnet_version              = "v8.0"
      use_dotnet_isolated_runtime = true
    }
    vnet_route_all_enabled = true # This replaces the legacy app_setting WEBSITE_VNET_ROUTE_ALL. Route all outbound traffic through vnet.
  }
  auth_settings_v2 {
    auth_enabled           = true
    require_authentication = true
    unauthenticated_action = "Return401"
    active_directory_v2 {
      client_id            = azurerm_user_assigned_identity.default_mi.client_id # This should be an app registration so it won't be picked up. It doesn't matter what this is though.
      tenant_auth_endpoint = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}"
      allowed_audiences    = ["https://management.azure.com/"]
      allowed_applications = [azurerm_user_assigned_identity.default_mi.client_id] # This is the important field => This has to be the managed identity which requests the bearer token.
    }
    login {
      token_store_enabled = false
    }
  }
  builtin_logging_enabled = false # should disable AzureWebJobsDashboard
  depends_on = [
    azurerm_storage_account.function_app_storage_account,
    azurerm_key_vault.shared_key_vault
  ]
  tags = var.tags
}


################################################################################
# Function App Private Endpoint and DNS zones
################################################################################

resource "azurerm_private_dns_zone" "function_app_dns_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.shared_resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "function_app_dns_zone_vnet_link" {
  name                  = "function_app-link"
  resource_group_name   = var.shared_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.function_app_dns_zone.name
  virtual_network_id    = regex("(/subscriptions/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/resourceGroups/[\\w-]{1,90}/providers/Microsoft.Network/virtualNetworks/[\\w-]{2,64})/subnets/[\\w-]{2,64}", var.private_endpoint_subnet_id)[0]
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "function_app" {
  name                = "function-app-private-endpoint"
  location            = var.location
  resource_group_name = var.function_app_resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "function-app-private-service-connection"
    private_connection_resource_id = azurerm_windows_function_app.fa_testingapp.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "function-app-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.function_app_dns_zone.id]
  }
  tags = var.tags
}

################################################################################
# Function App Managed Identity RBAC for Shared Storage Account
################################################################################
resource "azurerm_role_assignment" "blob_data_contributor_shared_storage" {
  scope                = azurerm_storage_account.shared_storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.default_mi.principal_id
}

resource "azurerm_role_assignment" "table_data_contributor_shared_storage" {
  scope                = azurerm_storage_account.shared_storage_account.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_user_assigned_identity.default_mi.principal_id

}

resource "azurerm_role_assignment" "queue_data_contributor_shared_storage" {
  scope                = azurerm_storage_account.shared_storage_account.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_user_assigned_identity.default_mi.principal_id
}

resource "azurerm_role_assignment" "storage_account_contributor_shared_storage" {
  scope                = azurerm_storage_account.shared_storage_account.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_user_assigned_identity.default_mi.principal_id
}


################################################################################
# Function App Managed Identity RBAC for Key Vault
################################################################################

resource "azurerm_role_assignment" "key_vault_administrator" {
  scope                = azurerm_key_vault.shared_key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azurerm_user_assigned_identity.default_mi.principal_id
}

################################################################################
# Function App Managed Identity RBAC for function app (to publish)
################################################################################

resource "azurerm_role_assignment" "function_app_contributor" {
  scope                = azurerm_windows_function_app.fa_testingapp.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.default_mi.principal_id
}
