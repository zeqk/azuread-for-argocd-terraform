data "azuread_client_config" "current" {}

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  application_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
}

data "azuread_group" "argoadmins" {
  display_name = "Argo-Admins"
}

data "azuread_group" "argoreaders" {
  display_name = "Argo-Readers"
}


# https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft/#add-a-new-azure-ad-app-registration
# Add a new Azure AD App registration
resource "azuread_application" "argocd" {
  display_name = "ArgoCD"
  web {
    redirect_uris = ["https://argocd.octubre.org.ar/auth/callback"]
    implicit_grant {
      access_token_issuance_enabled = false
    }
  }

  public_client {
    # https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft/#configure-additional-platform-settings-for-argocd-cli
    # Configure additional platform settings for ArgoCD CLI
    redirect_uris = ["http://localhost:8085/auth/callback"]
  }

  # https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft/#setup-permissions-for-azure-ad-application
  # Setup permissions for Azure AD Application
  required_resource_access {
    resource_app_id = data.azuread_service_principal.msgraph.application_id

    # https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft/#setup-permissions-for-azure-ad-application
    # Setup permissions for Azure AD Application
    resource_access {
      id   = data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["User.Read"]
      type = "Scope"
    }
  }
  optional_claims {
    access_token {
      name                  = "groups"
      additional_properties = []
      essential             = false
    }
    id_token {
      name                  = "groups"
      additional_properties = []
      essential             = false
    }
    saml2_token {
      name                  = "groups"
      additional_properties = []
      essential             = false
    }
  }

  group_membership_claims = ["ApplicationGroup"]

  owners = [data.azuread_client_config.current.object_id]
}

resource "random_uuid" "userrole" {
}

# Add Enterprise Application
resource "azuread_service_principal" "argocd" {
  application_id               = azuread_application.argocd.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

# https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft/#add-credentials-a-new-azure-ad-app-registration
# Add credentials a new Azure AD App registration
resource "azuread_application_password" "argocdsso" {
  display_name          = "ArgoCD-SSO"
  application_object_id = azuread_application.argocd.object_id
  end_date              = "2028-01-01T01:02:03Z"
}

# Grant Admin Consent
resource "azuread_service_principal_delegated_permission_grant" "argocd_userread" {
  service_principal_object_id          = azuread_service_principal.argocd.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["User.Read"]
}

# https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft/#associate-an-azure-ad-group-to-your-azure-ad-app-registration
# Associate an Azure AD group to your Azure AD App registration
resource "azuread_app_role_assignment" "argocd_argoadmins" {
  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = data.azuread_group.argoadmins.object_id
  resource_object_id  = azuread_service_principal.argocd.object_id
}

resource "azuread_app_role_assignment" "argocd_argoreaders" {
  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = data.azuread_group.argoreaders.object_id
  resource_object_id  = azuread_service_principal.argocd.object_id
}



output "client_id" {
  value = azuread_application.argocd.application_id
}

output "client_secret" {
  value = azuread_application_password.argocdsso.value
  sensitive   = true
}
