# frozen_string_literal: true

module RedmineKeycloakOidc
  def self.bootstrap
    require_relative 'redmine_keycloak_oidc/settings_helper'
    require_relative 'redmine_keycloak_oidc/jwt_decoder'
    require_relative 'redmine_keycloak_oidc/group_sync'
    require_relative 'redmine_keycloak_oidc/oidc_client'
    require_relative 'redmine_keycloak_oidc/keycloak_login_hook'
    require_relative 'redmine_keycloak_oidc/hooks'
  end
end
