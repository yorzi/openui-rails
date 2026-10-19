# frozen_string_literal: true

module SupportDesk # :nodoc:
  class BaseController < ::ApplicationController
    protect_from_forgery with: :exception
    layout "support_desk/application"
    before_action :local_demo_only
    before_action :authenticate
    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: { code: "not_found", message: "inaccessible conversation" } }, status: :not_found
    end
    rescue_from OpenUI::Rails::Error do |error|
      status = error.is_a?(OpenUI::Rails::StaleSurfaceError) ? :conflict : :unprocessable_content
      code = error.is_a?(OpenUI::Rails::StaleSurfaceError) ? "stale_surface" : "invalid_state"
      render json: { error: { code: code, message: "request rejected" } }, status: status
    end

    private

    def current_actor
      @current_actor ||= User.find_by(id: session[:support_desk_user_id])
    end
    helper_method :current_actor

    def local_demo_only
      head :forbidden unless [ "127.0.0.1", "::1" ].include?(request.remote_ip)
    end

    def authenticate
      render json: { error: { code: "unauthorized", message: "sign in to the local demo" } }, status: :unauthorized unless current_actor
    end

    def conversation
      @conversation ||= Conversation.find_by!(id: params[:id], user_id: current_actor.id, tenant_id: current_actor.tenant_id)
    end
  end
end
