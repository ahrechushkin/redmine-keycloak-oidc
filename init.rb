# frozen_string_literal: true

require File.join(__dir__, 'lib', 'redmine_keycloak_oidc')
require File.join(__dir__, 'lib', 'redmine_keycloak_oidc', 'settings_helper')
require File.join(__dir__, 'lib', 'redmine_keycloak_oidc', 'keycloak_login_hook')

Rails.application.config.to_prepare do
  RedmineKeycloakOidc::Hooks.bootstrap
end

Redmine::Plugin.register :redmine_keycloak_oidc do
  name 'Redmine Keycloak OIDC'
  author 'Redmine Keycloak OIDC Plugin Authors'
  description 'Keycloak/OIDC integration: web login, JWT API authentication, group mapping from JWT claims'
  version '0.1.0'
  url 'https://github.com/ahrechushkin/redmine-keycloak-oidc'
  author_url 'https://github.com/ahrechushki/redmine-keycloak-oidc'

  settings default: {
    'enabled' => '0',
    'jwt_api_enabled' => '0',
    'login_button_label' => '',
    'base_url' => '',
    'realm' => 'master',
    'client_id' => '',
    'client_secret' => '',
    'authorization_endpoint' => '',
    'token_endpoint' => '',
    'userinfo_endpoint' => '',
    'introspection_endpoint' => '',
    'jwks_uri' => '',
    'group_claim' => 'realm_access.roles',
    'group_mapping_rules' => [],
    'jwt_before_api_key' => '1'
  }, partial: 'keycloak_settings/form'
end

Redmine::MenuManager.map :admin_menu do |menu|
  menu.push :keycloak_settings,
            { controller: 'keycloak_settings', action: 'index' },
            caption: :label_keycloak,
            icon: 'server-authentication',
            html: { class: 'icon icon-server-authentication' }
end
