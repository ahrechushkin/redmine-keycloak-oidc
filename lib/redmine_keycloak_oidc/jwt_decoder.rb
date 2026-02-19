# frozen_string_literal: true

module RedmineKeycloakOidc
  class JwtDecoder
    def self.decode_unsigned(token)
      return nil if token.blank?
      parts = token.to_s.split('.')
      return nil unless parts.size >= 2
      payload = parts[1]
      return nil if payload.blank?
      decoded = Base64.urlsafe_decode64(payload + ('=' * (4 - payload.length % 4)))
      JSON.parse(decoded)
    rescue JSON::ParserError, ArgumentError, StandardError
      nil
    end
  end
end
