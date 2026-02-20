# frozen_string_literal: true

require 'net/http'
require 'uri'

class KeycloakSettingsController < ApplicationController
  layout 'admin'
  self.main_menu = false
  menu_item :keycloak_settings

  before_action :require_admin

  def index
    @settings = settings_hash
  end

  def update
    permitted = params.require(:settings).permit(
      :enabled, :jwt_api_enabled, :login_button_label,
      :base_url, :realm, :client_id, :client_secret,
      :authorization_endpoint, :token_endpoint, :userinfo_endpoint,
      :introspection_endpoint, :jwks_uri,
      :group_claim, :jwt_before_api_key,
      group_rule_priorities: [], group_rule_patterns: [], group_rule_group_ids: []
    ).to_h
    priorities = permitted.delete('group_rule_priorities') || []
    patterns = permitted.delete('group_rule_patterns') || []
    group_ids = permitted.delete('group_rule_group_ids') || []
    triples = priorities.zip(patterns, group_ids).reject { |_pr, p, g| p.blank? || g.blank? }
    permitted['group_mapping_rules'] = triples.map { |pr, p, g| { 'priority' => (pr.blank? ? 10 : pr.to_i), 'pattern' => p.strip, 'group_id' => g.to_i } }

    RedmineKeycloakOidc::SettingsHelper.save(permitted)
    flash[:notice] = l(:notice_successful_update)
    redirect_to keycloak_settings_path
  end

  def test_connection
    settings = RedmineKeycloakOidc::SettingsHelper.raw_hash
    intro = settings['introspection_endpoint'].to_s
    if intro.present?
      uri = URI(intro)
      req = Net::HTTP::Post.new(uri)
      req['Accept'] = 'application/json'
      req.content_type = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form(
        token: 'test',
        client_id: settings['client_id'],
        client_secret: RedmineKeycloakOidc::SettingsHelper.client_secret
      )
      use_ssl = uri.scheme == 'https'
      resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl, open_timeout: 5, read_timeout: 5) { |h| h.request(req) }
      if resp.is_a?(Net::HTTPSuccess) || resp.code.to_i == 401
        flash[:notice] = l(:notice_successful_connection)
      else
        flash[:error] = l(:error_unable_to_connect, value: "#{resp.code} #{resp.message}")
      end
    else
      base = settings['base_url'].to_s
      if base.blank?
        flash[:error] = l(:error_keycloak_configure_endpoints)
        redirect_to keycloak_settings_path
        return
      end
      base_uri = base.end_with?('/') ? base : "#{base}/"
      uri = URI.join(base_uri, '.well-known/openid-configuration')
      use_ssl = uri.scheme == 'https'
      resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl, open_timeout: 5, read_timeout: 5) { |h| h.get(uri.request_uri) }
      if resp.is_a?(Net::HTTPSuccess)
        flash[:notice] = l(:notice_successful_connection)
      else
        flash[:error] = l(:error_unable_to_connect, value: "#{resp.code} #{resp.message}")
      end
    end
    redirect_to keycloak_settings_path
  rescue StandardError => e
    flash[:error] = l(:error_unable_to_connect, value: e.message)
    redirect_to keycloak_settings_path
  end

  private

  def settings_hash
    s = RedmineKeycloakOidc::SettingsHelper.raw_hash
    s['client_secret'] = '' if s['client_secret'].present?
    if s['group_mapping_rules'].blank? && s['group_mapping'].present?
      s['group_mapping_rules'] = s['group_mapping'].map { |pattern, gid| { 'priority' => 10, 'pattern' => pattern.to_s, 'group_id' => gid.to_i } }
    end
    s
  end
end
