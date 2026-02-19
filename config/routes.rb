# frozen_string_literal: true

get 'keycloak_settings', to: 'keycloak_settings#index', as: 'keycloak_settings'
patch 'keycloak_settings', to: 'keycloak_settings#update'
put 'keycloak_settings', to: 'keycloak_settings#update'
post 'keycloak_settings/test_connection', to: 'keycloak_settings#test_connection', as: 'test_keycloak_connection'

get 'auth/keycloak', to: 'keycloak#login', as: 'keycloak_login'
get 'auth/keycloak/callback', to: 'keycloak#callback', as: 'keycloak_callback'
