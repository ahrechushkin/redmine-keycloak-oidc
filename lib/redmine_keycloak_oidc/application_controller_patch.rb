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
      return nil unless jwt_api_request?
      return nil unless accept_api_auth?
      return nil unless jwt_api_enabled?

      token = bearer_token
      return nil if token.blank?

      RedmineKeycloakOidc::JwtAuth.authenticate(token)
    end

    def jwt_before_api_key?
      s = RedmineKeycloakOidc::SettingsHelper.effective_hash
      s['jwt_before_api_key'].to_s != '0'
    end

    # Redmine's api_request? only checks params[:format]; JSON/XML via Accept may set request.format only.
    def jwt_api_request?
      return true if api_request?

      sym = request.format&.symbol&.to_s
      %w[json xml].include?(sym)
    end

    def authorization_header_value
      v = request.authorization.to_s.presence
      return v if v.present?

      request.headers['Authorization'].to_s.presence ||
        request.env['HTTP_AUTHORIZATION'].to_s.presence
    end

    def bearer_token
      auth = authorization_header_value
      return nil if auth.blank?
      return nil unless auth.match?(/\ABearer\s+/i)

      auth.sub(/\ABearer\s+/i, '').strip.presence
    end

    def jwt_api_enabled?
      RedmineKeycloakOidc::SettingsHelper.jwt_api_enabled?
    end
  end
end
