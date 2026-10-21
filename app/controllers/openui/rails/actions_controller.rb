# frozen_string_literal: true

module OpenUI
  module Rails
    # Single allowlisted endpoint for surface actions. Both a component
    # `onAction` and a browser `toolProvider` `Query()`/`Mutation()` call post
    # here; the {Actions::Dispatcher} applies every gate (allowlist, schema,
    # confirmation, staleness, authorization, idempotency) before any effect.
    #
    # Forged cross-site requests cannot pass Rails' CSRF protection, and a
    # missing/invalid token is reported with the same structured shape as any
    # other failed gate.
    class ActionsController < ApplicationController
      rescue_from ::ActionController::InvalidAuthenticityToken, with: :render_csrf_error
      rescue_from OpenUI::Rails::Error, with: :render_domain_error

      # Reads the JSON/form body only (not path params), so the documented
      # top-level `action` key cannot collide with the Rails route's own
      # `action` param. Only known keys are used; values are validated again by
      # Submission and the action schema.
      PAYLOAD_KEYS = %w[action args surface_id version idempotency_key confirmed].freeze

      def create
        result = dispatcher.call(payload, actor: actor)

        render json: { result: result.to_h }, status: :ok
      end

      private

      def dispatcher
        Actions::Dispatcher.from_configuration
      end

      def payload
        request.request_parameters.slice(*PAYLOAD_KEYS)
      end

      def actor
        resolver = OpenUI::Rails.configuration.actor_resolver
        return resolver.call(self) if resolver

        current_user if respond_to?(:current_user, true)
      end

      def render_csrf_error(_error)
        render json: { error: { code: "csrf_failed", message: "invalid authenticity token" } },
               status: :unprocessable_content
      end

      # Request errors return their own message. Any other gem error is a
      # server-side fault, possibly after the handler ran: log it and return a
      # generic message so configuration details never reach the browser.
      def render_domain_error(error)
        code = error_code(error)
        if code == "error"
          logger&.error("[openui-rails] action failed: #{error.class}: #{error.message}")
          render json: { error: { code: code, message: "action failed" } }, status: :internal_server_error
        else
          render json: { error: { code: code, message: error.message } }, status: error_status(error)
        end
      end

      def error_code(error)
        Instrumentation.action_error_code(error)
      end

      def error_status(error)
        case error
        when UnknownActionError then :not_found
        when UnauthorizedActionError then :forbidden
        when StaleSurfaceError, ReplayError then :conflict
        when InvalidActionError then :unprocessable_content
        else :internal_server_error
        end
      end
    end
  end
end
