# frozen_string_literal: true

class KeycloakController < ApplicationController
  self.main_menu = false
  skip_before_action :check_if_login_required
  skip_before_action :check_password_change
  skip_before_action :check_twofa_activation

  def login
    unless RedmineKeycloakOidc::SettingsHelper.enabled?
      redirect_to signin_path, flash: { error: l(:notice_account_invalid_credentials) }
      return
    end
    state = SecureRandom.urlsafe_base64(32)
    session[:keycloak_oidc_state] = state
    session[:keycloak_oidc_back_url] = params[:back_url]
    redirect_uri = keycloak_callback_url
    client = RedmineKeycloakOidc::OidcClient.new
    url = client.authorization_url(redirect_uri, state)
    if url.blank?
      redirect_to signin_path, flash: { error: l(:error_keycloak_misconfigured) }
      return
    end
    redirect_to url, allow_other_host: true
  end

  def callback
    if params[:error]
      redirect_to signin_path, flash: { error: "#{l(:notice_account_invalid_credentials)}: #{params[:error_description].presence || params[:error]}" }
      return
    end
    state = session.delete(:keycloak_oidc_state)
    if state.blank? || params[:state] != state
      redirect_to signin_path, flash: { error: l(:error_keycloak_invalid_state) }
      return
    end
    code = params[:code]
    if code.blank?
      redirect_to signin_path, flash: { error: l(:notice_account_invalid_credentials) }
      return
    end
    redirect_uri = keycloak_callback_url
    client = RedmineKeycloakOidc::OidcClient.new
    token_response = client.exchange_code(code, redirect_uri)
    unless token_response && token_response['access_token']
      redirect_to signin_path, flash: { error: l(:notice_account_invalid_credentials) }
      return
    end
    access_token = token_response['access_token']
    userinfo = client.userinfo(access_token) || {}
    id_token = token_response['id_token']
    claims = userinfo.dup
    if id_token.present?
      id_claims = RedmineKeycloakOidc::JwtDecoder.decode_unsigned(id_token)
      claims = claims.merge(id_claims) if id_claims.is_a?(Hash)
    end
    unless claims.is_a?(Hash) && (claims['preferred_username'].present? || claims['sub'].present?)
      redirect_to signin_path, flash: { error: l(:notice_account_invalid_credentials) }
      return
    end
    login_str = claims['preferred_username'].presence || claims['sub'].to_s
    if login_str.blank?
      redirect_to signin_path, flash: { error: l(:notice_account_invalid_credentials) }
      return
    end
    user = User.find_by_login(login_str)
    if user.nil?
      user = build_user_from_userinfo(login_str, claims)
      unless user.save
        redirect_to signin_path, flash: { error: user.errors.full_messages.join(' ') }
        return
      end
      RedmineKeycloakOidc::GroupSync.sync(user, claims, first_login: true)
    else
      update_user_from_userinfo(user, claims)
      user.save if user.changed?
      RedmineKeycloakOidc::GroupSync.sync(user, claims, first_login: false)
    end
    unless user.active?
      redirect_to signin_path, flash: { error: user.registered? ? l(:notice_account_pending) : l(:notice_account_locked) }
      return
    end
    if user.twofa_active?
      token = Token.create(user: user, action: 'twofa_session')
      session[:twofa_session_token] = token.value
      session[:twofa_tries_counter] = 1
      session[:twofa_back_url] = params[:back_url]
      session[:user_id] = user.id
      session[:tk] = user.generate_session_token
      twofa = Redmine::Twofa.for_user(user)
      twofa.send_code(controller: 'account', action: 'twofa') if twofa.respond_to?(:send_code)
      flash[:notice] = l('twofa_code_sent') if twofa.respond_to?(:send_code)
      redirect_to account_twofa_confirm_path
      return
    end
    successful_authentication(user)
  end

  private

  def build_user_from_userinfo(login_str, claims)
    User.new(
      login: login_str,
      firstname: claims['given_name'].presence || login_str,
      lastname: claims['family_name'].presence || '-',
      mail: claims['email'].to_s.strip.presence || "#{login_str}@keycloak.local",
      language: Setting.default_language,
      status: User::STATUS_ACTIVE
    )
  end

  def update_user_from_userinfo(user, claims)
    user.firstname = claims['given_name'] if claims['given_name'].present?
    user.lastname = claims['family_name'] if claims['family_name'].present?
    user.mail = claims['email'] if claims['email'].present?
  end

  def successful_authentication(user)
    logger.info "Successful Keycloak authentication for '#{user.login}' from #{request.remote_ip} at #{Time.now.utc}"
    self.logged_user = user
    call_hook(:controller_account_success_authentication_after, { user: user })
    back_url = session.delete(:keycloak_oidc_back_url)
    redirect_to(back_url.presence || my_page_path)
  end
end
