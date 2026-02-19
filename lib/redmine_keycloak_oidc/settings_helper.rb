# frozen_string_literal: true

module RedmineKeycloakOidc
  module SettingsHelper
    class << self
      def get(key)
        h = raw
        return nil unless h.is_a?(Hash)
        v = h[key.to_s]
        return v unless key.to_s == 'client_secret' && v.present?
        decrypt_secret(v)
      end

      def raw
        Setting.plugin_redmine_keycloak_oidc
      end

      def raw_hash
        r = raw
        r.is_a?(Hash) ? r.dup : {}
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
