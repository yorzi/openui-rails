# frozen_string_literal: true

module OpenUI
  module Rails
    module Actions
      # The single authorization and execution path for every write-ish call,
      # whether it originated from a component `onAction` or a browser
      # `toolProvider` `Query()`/`Mutation()`. It fails closed: with no
      # authorizer configured, an action is denied.
      #
      # Order of checks (all before any side effect):
      #   1. resolve + validate the submission
      #   2. action is registered (allowlist)
      #   3. args match the schema
      #   4. confirmation when the action is destructive
      #   5. surface revision is current (stale protection)
      #   6. authorizer allows it
      #   7. idempotency claim (duplicates never execute twice)
      class Dispatcher
        Result = Struct.new(:action, :surface_id, :version, :value, :replayed, keyword_init: true) do
          def replayed? = replayed == true

          def to_h
            { action: action, surface_id: surface_id, version: version, value: value, replayed: replayed? }
          end
        end

        def self.from_configuration(configuration = OpenUI::Rails.configuration)
          new(
            registry: configuration.action_registry,
            idempotency_store: configuration.idempotency_store || Idempotency::MemoryStore.new,
            idempotency_ttl: configuration.idempotency_ttl,
            authorize_action: configuration.authorize_action,
            surface_resolver: configuration.surface_resolver,
            idempotency_scope: configuration.idempotency_scope
          )
        end

        def initialize(registry:, idempotency_store:, idempotency_ttl:, authorize_action: nil, surface_resolver: nil,
                       idempotency_scope: nil)
          @registry = registry
          @idempotency_store = idempotency_store
          @idempotency_ttl = idempotency_ttl
          @authorize_action = authorize_action
          @surface_resolver = surface_resolver
          @idempotency_scope = idempotency_scope
        end

        # @param payload [Hash, Submission]
        # @return [Result]
        # @raise [OpenUI::Rails::Error] on any failed gate, before side effects
        def call(payload, actor: nil, surface: nil, tenant: nil, context: {})
          submission = Submission.parse(payload)
          definition = @registry.fetch(submission.action)

          definition.schema.validate!(submission.args)
          check_confirmation!(definition, submission)

          surface ||= resolve_surface(submission.surface_id, actor, context)
          check_version!(submission, surface)

          invocation = Invocation.new(
            action: definition.name,
            args: submission.args,
            actor: actor,
            surface: surface,
            tenant: tenant,
            context: context,
            submission: submission
          )

          authorize!(definition, invocation)

          replayed, stored, key, token = claim_idempotency(submission, invocation)
          return result(submission, stored, replayed: true) if replayed

          value = definition.handler.call(invocation)
          @idempotency_store.record(key, value, claim_token: token)
          result(submission, value, replayed: false)
        end

        private

        def check_confirmation!(definition, submission)
          return if !definition.confirmation || submission.confirmed?

          raise InvalidActionError, "action #{definition.name} requires explicit confirmation"
        end

        def resolve_surface(surface_id, actor, context)
          return nil if @surface_resolver.nil?

          surface = @surface_resolver.call(surface_id, actor: actor, context: context)
          return surface unless surface.nil?

          raise UnauthorizedActionError, "unknown or inaccessible surface"
        end

        def check_version!(submission, surface)
          if surface.respond_to?(:id) && surface.id.to_s != submission.surface_id
            raise UnauthorizedActionError, "resolved surface does not match the submission"
          end
          return if surface.nil? || !surface.respond_to?(:version)
          return if surface.version == submission.version

          raise StaleSurfaceError,
                "surface #{submission.surface_id} is at version #{surface.version}, " \
                "action submitted for #{submission.version}"
        end

        def authorize!(definition, invocation)
          authorizer = definition.authorize || @authorize_action
          if authorizer.nil?
            raise UnauthorizedActionError, "no authorizer configured for action #{definition.name}"
          end

          return if authorizer.call(invocation)

          raise UnauthorizedActionError, "action #{definition.name} is not permitted"
        end

        def claim_idempotency(submission, invocation)
          scope = if @idempotency_scope
            @idempotency_scope.call(invocation)
          else
            [ identity(invocation.tenant), identity(invocation.actor) ]
          end
          key = Digest::SHA256.hexdigest(JSON.generate([ scope, submission.idempotency_key ]))
          digest = Digest::SHA256.hexdigest(JSON.generate(submission.to_h.except(:idempotency_key)))
          status, stored, stored_digest, token = @idempotency_store.claim(key, ttl: @idempotency_ttl, digest: digest)

          return [ false, nil, key, token ] if status == :claimed

          if stored_digest != digest
            raise ReplayError, "idempotency key reused with different arguments"
          end

          raise ReplayError, "duplicate submission is still in progress" if status == :pending
          raise ConfigurationError, "invalid idempotency store status #{status.inspect}" unless status == :replay

          [ true, stored ]
        end

        def identity(record)
          return nil if record.nil?
          return [ record.class.name, record ] if record.is_a?(String) || record.is_a?(Symbol) || record.is_a?(Numeric)
          return [ record.class.name, record.id.to_s ] if record.respond_to?(:id) && !record.id.nil?

          raise ConfigurationError, "actor/tenant needs a stable id; configure idempotency_scope for other identities"
        end

        def result(submission, value, replayed:)
          Result.new(
            action: submission.action,
            surface_id: submission.surface_id,
            version: submission.version,
            value: value,
            replayed: replayed
          )
        end
      end
    end
  end
end
