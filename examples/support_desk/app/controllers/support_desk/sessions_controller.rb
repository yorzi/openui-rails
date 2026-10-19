# frozen_string_literal: true

module SupportDesk # :nodoc:
  class SessionsController < BaseController
    skip_before_action :authenticate

    def create
      user = User.find_by!(name: params[:name])
      reset_session
      session[:support_desk_user_id] = user.id
      redirect_to conversation_path(Conversation.find_by!(user_id: user.id))
    end

    def destroy
      reset_session
      redirect_to root_path
    end
  end
end
