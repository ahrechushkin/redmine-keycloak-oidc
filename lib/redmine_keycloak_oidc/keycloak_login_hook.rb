# frozen_string_literal: true

module RedmineKeycloakOidc
  class KeycloakLoginHook < Redmine::Hook::ViewListener
    def view_account_login_keycloak(context)
      return '' unless RedmineKeycloakOidc::SettingsHelper.enabled?
      back_url = context[:request]&.params&.[](:back_url)
      label = RedmineKeycloakOidc::SettingsHelper.get('login_button_label').to_s.presence || l(:label_keycloak_login)
      inner = (back_url.present? ? hidden_field_tag(:back_url, back_url) : ''.html_safe) + submit_tag(label, id: 'keycloak-login-submit', class: 'keycloak-login', tabindex: 6)
      content_tag(:p, form_tag(keycloak_login_path, method: :get, id: 'keycloak-login-form', style: 'margin-top: 0.75em; margin-bottom: 0;') { inner }, id: 'keycloak-login', class: 'keycloak-login-wrapper')
    end
  end
end
