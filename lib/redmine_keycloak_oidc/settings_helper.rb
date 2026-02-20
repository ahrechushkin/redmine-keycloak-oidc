# frozen_string_literal: true

module RedmineKeycloakOidc
  module SettingsHelper
    class << self
      def get(key)
        h = effective_hash
        h[key.to_s]
      end

      def raw
        Setting.plugin_redmine_keycloak_oidc
      end

      def raw_hash
        r = raw
        r.is_a?(Hash) ? r.dup : {}
      end

      def effective_hash
        base = raw_hash
        overrides = env_overrides
        result = base.merge(overrides)
        if result['client_secret'].present? && !overrides.key?('client_secret')
          result['client_secret'] = decrypt_secret(result['client_secret']) || result['client_secret']
        end
        result
      end

      def env_overrides
        h = {}
        h['enabled'] = '1' if ENV['KEYCLOAK_ENABLED'].to_s =~ /\A(1|true|yes)\z/i
        h['jwt_api_enabled'] = '1' if ENV['KEYCLOAK_JWT_API_ENABLED'].to_s =~ /\A(1|true|yes)\z/i
        h['jwt_before_api_key'] = ENV['KEYCLOAK_JWT_BEFORE_API_KEY'].to_s if ENV['KEYCLOAK_JWT_BEFORE_API_KEY'].present?
        h['base_url'] = ENV['KEYCLOAK_BASE_URL'].to_s if ENV['KEYCLOAK_BASE_URL'].present?
        h['realm'] = ENV['KEYCLOAK_REALM'].to_s if ENV['KEYCLOAK_REALM'].present?
        h['client_id'] = ENV['KEYCLOAK_CLIENT_ID'].to_s if ENV['KEYCLOAK_CLIENT_ID'].present?
        h['client_secret'] = ENV['KEYCLOAK_CLIENT_SECRET'].to_s if ENV['KEYCLOAK_CLIENT_SECRET'].present?
        h['group_claim'] = ENV['KEYCLOAK_GROUP_CLAIM'].to_s if ENV['KEYCLOAK_GROUP_CLAIM'].present?
        h['login_button_label'] = ENV['KEYCLOAK_LOGIN_BUTTON_LABEL'].to_s if ENV['KEYCLOAK_LOGIN_BUTTON_LABEL'].present?
        h['authorization_endpoint'] = ENV['KEYCLOAK_AUTHORIZATION_ENDPOINT'].to_s if ENV['KEYCLOAK_AUTHORIZATION_ENDPOINT'].present?
        h['token_endpoint'] = ENV['KEYCLOAK_TOKEN_ENDPOINT'].to_s if ENV['KEYCLOAK_TOKEN_ENDPOINT'].present?
        h['userinfo_endpoint'] = ENV['KEYCLOAK_USERINFO_ENDPOINT'].to_s if ENV['KEYCLOAK_USERINFO_ENDPOINT'].present?
        h['introspection_endpoint'] = ENV['KEYCLOAK_INTROSPECTION_ENDPOINT'].to_s if ENV['KEYCLOAK_INTROSPECTION_ENDPOINT'].present?
        h['jwks_uri'] = ENV['KEYCLOAK_JWKS_URI'].to_s if ENV['KEYCLOAK_JWKS_URI'].present?
        if ENV['KEYCLOAK_GROUP_MAPPING_RULES'].present?
          parsed = parse_group_mapping_rules_env(ENV['KEYCLOAK_GROUP_MAPPING_RULES'])
          h['group_mapping_rules'] = parsed if parsed.is_a?(Array)
        end
        h
      end

      def save(attrs)
        current = raw_hash
        attrs.each do |k, v|
          key = k.to_s
          if key == 'client_secret'
            current['client_secret'] = v.present? ? encrypt_secret(v) : current['client_secret']
          else
            current[key] = v
          end
        end
        Setting.plugin_redmine_keycloak_oidc = current
      end

      def client_secret
        get('client_secret')
      end

      def enabled?
        get('enabled').to_s == '1'
      end

      def jwt_api_enabled?
        get('jwt_api_enabled').to_s == '1'
      end

      private

      def parse_group_mapping_rules_env(json_str)
        arr = JSON.parse(json_str)
        return [] unless arr.is_a?(Array)
        arr.map do |item|
          next unless item.is_a?(Hash)
          pattern = item['pattern'].to_s
          group_id = item['group_id'].to_i
          next if pattern.blank? || group_id <= 0
          { 'priority' => (item['priority'] || 10).to_i, 'pattern' => pattern, 'group_id' => group_id }
        end.compact
      rescue StandardError
        nil
      end

      def encrypt_secret(plain)
        return plain if plain.blank?
        Redmine::Ciphering.encrypt_text(plain)
      rescue StandardError
        plain
      end

      def decrypt_secret(ciphered)
        return nil if ciphered.blank?
        Redmine::Ciphering.decrypt_text(ciphered)
      rescue StandardError
        nil
      end
    end
  end
end
