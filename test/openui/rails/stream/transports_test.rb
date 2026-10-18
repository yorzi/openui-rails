# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Stream
      class TransportsTest < ActiveSupport::TestCase
        class FakeCable
          def broadcast(*); end
        end

        test "builds the memory transport" do
          assert_instance_of Transports::Memory, Transports.build(:memory)
        end

        test "builds the Action Cable transport" do
          transport = Transports.build(:action_cable, stream_name: "openui:1", cable: FakeCable.new)
          assert_instance_of Transports::ActionCable, transport
          assert_equal "openui:1", transport.stream_name
        end

        test "builds the Turbo Streams transport under either alias" do
          [ :turbo, :turbo_streams ].each do |name|
            transport = Transports.build(name, stream: "s", target: "t", turbo: :fake)
            assert_instance_of Transports::TurboStreams, transport
          end
        end

        test "rejects an unknown transport" do
          error = assert_raises(ConfigurationError) { Transports.build(:smoke_signals) }
          assert_match(/unsupported transport/, error.message)
        end
      end
    end
  end
end
