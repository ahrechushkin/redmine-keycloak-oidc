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
      if intro_endpoint.present?
        claims = introspect(token, intro_endpoint, settings)
      end
      if claims.blank? && settings['jwks_uri'].to_s.present?
        claims = verify_jwt_with_jwks(token, settings['jwks_uri'])
      end
      return nil if claims.blank?
      login_str = claims['preferred_username'].presence || claims['username'].presence || claims['sub'].to_s
      return nil if login_str.blank?
      user = User.find_by_login(login_str)
      if user.nil?
        user = build_user_from_claims(login_str, claims)
        return nil unless user.save
        RedmineKeycloakOidc::GroupSync.sync(user, claims, first_login: true)
      else
        update_user_from_claims(user, claims)
        user.save if user.changed?
        RedmineKeycloakOidc::GroupSync.sync(user, claims, first_login: false)
      end
      user&.active? ? user : nil
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
      return nil if payload.blank?
      exp = payload['exp']
      return nil if exp && Time.at(exp.to_i) < Time.now
      login_str = payload['preferred_username'].presence || payload['sub'].to_s
      return nil if login_str.blank?
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
