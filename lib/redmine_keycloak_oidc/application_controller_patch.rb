# frozen_string_literal: true

module RedmineKeycloakOidc
  module ApplicationControllerPatch
    def find_current_user
      if jwt_before_api_key?
        user = find_current_user_via_jwt
        return user if user
      end
      u = super
      return u if u
      return nil unless jwt_api_enabled?
      find_current_user_via_jwt
    end

    private

    def find_current_user_via_jwt
      return nil unless api_request?
      return nil unless accept_api_auth?
      return nil unless jwt_api_enabled?

      token = bearer_token
      return nil if token.blank?

      RedmineKeycloakOidc::JwtAuth.authenticate(token)
    end

    def jwt_before_api_key?
      s = Setting.plugin_redmine_keycloak_oidc
      s.is_a?(Hash) && s['jwt_before_api_key'].to_s != '0'
    end

    def bearer_token
      auth = request.authorization.to_s
      return nil unless auth.start_with?('Bearer ')
      auth.sub(/\ABearer /, '').strip.presence
    end

    def jwt_api_enabled?
      RedmineKeycloakOidc::SettingsHelper.jwt_api_enabled?
    end
  end
end
