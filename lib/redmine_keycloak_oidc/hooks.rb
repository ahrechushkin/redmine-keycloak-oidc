# frozen_string_literal: true

module RedmineKeycloakOidc
  class Hooks < Redmine::Hook::Listener
    class << self
      def bootstrap
        require_relative 'jwt_auth'
        require_relative 'application_controller_patch'
        ApplicationController.prepend(RedmineKeycloakOidc::ApplicationControllerPatch)
      end
    end
  end
end
