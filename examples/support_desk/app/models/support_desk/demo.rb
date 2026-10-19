# frozen_string_literal: true

module SupportDesk # :nodoc:
  class Demo
    def self.seed!
      [ [ "Alice", "north", "agent" ], [ "Bob", "south", "agent" ], [ "Reader", "north", "reader" ] ].each do |name, tenant, role|
        user = User.find_or_create_by!(name: name) { |record| record.tenant_id = tenant; record.role = role }
        next if Conversation.exists?(user_id: user.id)

        ticket = Ticket.create!(tenant_id: tenant, title: "#{tenant.capitalize} delivery question")
        Conversation.create!(user: user, ticket: ticket, tenant_id: tenant)
      end
    end
  end
end
