data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  suffix = random_string.suffix.result

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "DevOpsInterviewPractice"
  }
}

# ---------------------------------------------------------
# Resource Group
# ---------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = local.common_tags
}

# ---------------------------------------------------------
# Virtual Network
# ---------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  address_space = [
    "10.10.0.0/16"
  ]

  tags = local.common_tags
}
# ---------------------------------------------------------
# DevBoard Workload Identity for Azure Key Vault
# ---------------------------------------------------------

resource "azurerm_user_assigned_identity" "devboard_workload" {
  name                = "id-devboard-workload-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Allow the AKS workload identity to READ secrets from Key Vault
resource "azurerm_role_assignment" "devboard_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.devboard_workload.principal_id
}

# Allow the currently logged-in Terraform user to CREATE/UPDATE secrets
resource "azurerm_role_assignment" "current_user_kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Trust the Kubernetes ServiceAccount through AKS OIDC
resource "azurerm_federated_identity_credential" "devboard_workload" {
  name                      = "fic-devboard-workload"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.devboard_workload.id

  subject = "system:serviceaccount:devboard:devboard-workload-sa"
}

# ---------------------------------------------------------
# AKS Subnet
# ---------------------------------------------------------

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name

  address_prefixes = [
    "10.10.0.0/22"
  ]
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}


# ---------------------------------------------------------
# Azure Container Registry
# ---------------------------------------------------------

resource "azurerm_container_registry" "main" {
  name                = "acrdevboard${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku           = "Basic"
  admin_enabled = false

  tags = local.common_tags
}

# ---------------------------------------------------------
# Azure Key Vault
# ---------------------------------------------------------

resource "azurerm_key_vault" "main" {
  name                = "kv-devboard-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tenant_id = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = local.common_tags
}

# ---------------------------------------------------------
# AKS
# ---------------------------------------------------------

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  dns_prefix = "aks-${var.project_name}"

  sku_tier = "Free"

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  role_based_access_control_enabled = true

  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
    os_disk_type   = "Managed"

    upgrade_settings {
      max_surge                     = "10%"
      drain_timeout_in_minutes      = 0
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"

    service_cidr   = "10.20.0.0/16"
    dns_service_ip = "10.20.0.10"

    load_balancer_sku = "standard"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = local.common_tags
}

# ---------------------------------------------------------
# AKS permission to pull from ACR
# ---------------------------------------------------------

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope = azurerm_container_registry.main.id

  role_definition_name = "AcrPull"

  principal_id = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
# ---------------------------------------------------------
# GitHub Actions Workload Identity
# ---------------------------------------------------------

resource "azurerm_user_assigned_identity" "github_actions" {
  name                = "id-devboard-github-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Allow GitHub Actions to push/pull images in ACR
resource "azurerm_role_assignment" "github_actions_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
}

# GitHub Actions -> Azure OIDC federation
resource "azurerm_federated_identity_credential" "github_actions" {
  name                      = "fic-github-actions"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_actions.id

  subject = "repo:bhagya2793@265142970/devboard-hackathon@1329471574:ref:refs/heads/azure-devops-project"
}
