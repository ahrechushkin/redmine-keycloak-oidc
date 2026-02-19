# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module RedmineKeycloakOidc
  class OidcClient
    def initialize(settings = nil)
      @settings = settings || RedmineKeycloakOidc::SettingsHelper.raw_hash
    end

    def authorization_url(redirect_uri, state)
      endpoint = @settings['authorization_endpoint'].to_s
      return nil if endpoint.blank?
      params = {
        response_type: 'code',
        client_id: @settings['client_id'],
        redirect_uri: redirect_uri,
        scope: 'openid profile email',
        state: state
      }
      uri = URI(endpoint)
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def exchange_code(code, redirect_uri)
      endpoint = @settings['token_endpoint'].to_s
      return nil if endpoint.blank?
      client_secret = RedmineKeycloakOidc::SettingsHelper.client_secret
      body = {
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: redirect_uri,
        client_id: @settings['client_id'],
        client_secret: client_secret
      }
      post_form(endpoint, body)
    end

    def userinfo(access_token)
      endpoint = @settings['userinfo_endpoint'].to_s
      return nil if endpoint.blank?
      get_json(endpoint, 'Authorization' => "Bearer #{access_token}")
    end

    private

    def post_form(url, form_data)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req['Accept'] = 'application/json'
      req.content_type = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form(form_data)
      resp = do_http(uri, req)
      return nil unless resp.is_a?(Net::HTTPSuccess)
      JSON.parse(resp.body)
    rescue JSON::ParserError, StandardError
      nil
    end

    def get_json(url, headers = {})
      uri = URI(url)
      req = Net::HTTP::Get.new(uri)
      req['Accept'] = 'application/json'
      headers.each { |k, v| req[k] = v }
      resp = do_http(uri, req)
      return nil unless resp.is_a?(Net::HTTPSuccess)
      JSON.parse(resp.body)
    rescue JSON::ParserError, StandardError
      nil
    end

    def do_http(uri, req)
      use_ssl = uri.scheme == 'https'
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl, open_timeout: 10, read_timeout: 10) { |http| http.request(req) }
    end
  end
end
