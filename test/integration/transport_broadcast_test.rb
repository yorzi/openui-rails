# frozen_string_literal: true

require "test_helper"

class TransportBroadcastTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "the Action Cable transport broadcasts the real envelope serialization" do
    envelope = OpenUI::Rails::Stream::Envelope.delta(message_id: "real-cable", sequence: 0, delta: "data")
    assert_broadcast_on("openui-transport-test", envelope.to_h) do
      OpenUI::Rails::Stream::Transports::ActionCable.new("openui-transport-test").broadcast(envelope)
    end
  end
end
