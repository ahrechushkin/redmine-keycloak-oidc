# frozen_string_literal: true

module RedmineKeycloakOidc
  class JwtAuth
    def self.authenticate(token)
      new.authenticate(token)
    end

    def authenticate(token)
      claims = nil
      settings = RedmineKeycloakOidc::SettingsHelper.effective_hash
      intro_endpoint = RedmineKeycloakOidc::SettingsHelper.effective_introspection_endpoint
      jwks_explicit = settings['jwks_uri'].to_s

      if intro_endpoint.blank? && jwks_explicit.blank?
        log_warn(
          'Cannot validate JWT: no introspection URL and no JWKS URI. Set Keycloak Base URL + realm (or userinfo/token URL), or KEYCLOAK_INTROSPECTION_ENDPOINT'
        )
        return nil
      end

      if intro_endpoint.present?
        claims = introspect(token, intro_endpoint, settings)
      end
      if claims.blank? && jwks_explicit.present?
        claims = verify_jwt_with_jwks(token, jwks_explicit)
      end
      return nil if claims.blank?
      login_str = claims['preferred_username'].presence || claims['username'].presence || claims['sub'].to_s
      if login_str.blank?
        log_warn('JWT claims contain no preferred_username, username, or sub')
        return nil
      end
      user = User.find_by_login(login_str)
      if user.nil?
        user = build_user_from_claims(login_str, claims)
        unless user.save
          log_warn("Could not create user from JWT: #{user.errors.full_messages.join(', ')}")
          return nil
        end
        RedmineKeycloakOidc::GroupSync.sync(user, claims, first_login: true)
      else
        update_user_from_claims(user, claims)
        user.save if user.changed?
        RedmineKeycloakOidc::GroupSync.sync(user, claims, first_login: false)
      end
      unless user&.active?
        log_warn("JWT user '#{user&.login}' is not active")
        return nil
      end
      user
    end

    private

    def introspect(token, endpoint, settings)
      if settings['client_id'].to_s.blank?
        log_warn('JWT introspection skipped: client_id is blank')
        return nil
      end
      if RedmineKeycloakOidc::SettingsHelper.client_secret.to_s.blank?
        log_warn('JWT introspection skipped: client_secret is blank')
        return nil
      end
      client_secret = RedmineKeycloakOidc::SettingsHelper.client_secret
      body = {
        token: token,
        client_id: settings['client_id'],
        client_secret: client_secret
      }
      resp = post_form(endpoint, body, context: 'introspect')
      unless resp.is_a?(Hash)
        log_warn("JWT introspection: no JSON response from #{endpoint}")
        return nil
      end
      unless resp['active'] == true
        log_warn('JWT introspection: token not active')
        return nil
      end
      resp
    end

    def post_form(url, form_data, context: 'post_form')
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req['Accept'] = 'application/json'
      req.content_type = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form(form_data)
      resp = do_http(uri, req)
      unless resp.is_a?(Net::HTTPSuccess)
        log_warn("#{context}: HTTP #{resp.code} from #{uri.scheme}://#{uri.host}#{uri.path}")
        return nil
      end
      JSON.parse(resp.body)
    rescue JSON::ParserError => e
      log_warn("#{context}: invalid JSON — #{e.class}")
      nil
    rescue StandardError => e
      log_warn("#{context}: #{e.class} — #{e.message}")
      nil
    end

    def verify_jwt_with_jwks(token, jwks_uri)
      payload = RedmineKeycloakOidc::JwtDecoder.decode_unsigned(token)
      if payload.blank?
        log_warn('JWT (JWKS fallback): could not decode token payload')
        return nil
      end
      exp = payload['exp']
      if exp && Time.at(exp.to_i) < Time.now
        log_warn('JWT (JWKS fallback): token expired')
        return nil
      end
      login_str = payload['preferred_username'].presence || payload['sub'].to_s
      if login_str.blank?
        log_warn('JWT (JWKS fallback): no preferred_username or sub in token')
        return nil
      end
      payload
    end

    def do_http(uri, req)
      use_ssl = uri.scheme == 'https'
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl, open_timeout: 10, read_timeout: 10) { |http| http.request(req) }
    end

    def build_user_from_claims(login_str, claims)
      User.new(
        login: login_str,
        firstname: claims['given_name'].presence || login_str,
        lastname: claims['family_name'].presence || '-',
        mail: claims['email'].to_s.strip.presence || "#{login_str}@keycloak.local",
        language: Setting.default_language,
        status: User::STATUS_ACTIVE
      )
    end

    def update_user_from_claims(user, claims)
      user.firstname = claims['given_name'] if claims['given_name'].present?
      user.lastname = claims['family_name'] if claims['family_name'].present?
      user.mail = claims['email'] if claims['email'].present?
    end

    def log_warn(message)
      return unless defined?(Rails) && Rails.logger

      Rails.logger.warn("[redmine_keycloak_oidc] #{message}")
    end
  end
end
