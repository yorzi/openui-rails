# frozen_string_literal: true

# Host application files use public APIs only. No support-desk or dummy fixtures.
require "fileutils"
File.write("config/initializers/openui.rb", <<~'RUBY')
  OpenUI::Rails.configure do |config|
    config.library_spec_path = Rails.root.join("config/openui/library.spec.json")
    config.prompt_path = Rails.root.join("config/openui/library.prompt.txt")
    config.actor_resolver = ->(_controller) { Struct.new(:id).new(1) }
    config.surface_resolver = ->(id, actor:, **) { HostRecord.find_by(id: id, actor_id: actor.id) if actor }
    config.authorize_action = ->(call) { call.actor.id == call.surface.actor_id && call.action == "continue_conversation" }
  end
  Rails.application.config.action_controller.allow_forgery_protection = true
  # 0.1 sends no continuation metadata; 0.3+ forwards it. Accept both for rollback.
  OpenUI::Rails.actions.register "continue_conversation", schema: ->(args) {
    args.empty? || ((args.keys - %w[message context form_name form_state]).empty? && args["message"] == "confirm")
  }, handler: ->(call) {
    call.surface.with_lock { call.surface.increment!(:effects) }
    { "effects" => call.surface.reload.effects }
  }
RUBY
File.write("app/models/host_record.rb", <<~'RUBY')
  class HostRecord < ActiveRecord::Base
    def surface
      OpenUI::Rails::Surface.new(id: id, version: 0, response: response, library_version: library_version,
        context: { "saved_note" => draft })
    end
  end
RUBY
File.write("app/controllers/host_controller.rb", <<~'RUBY')
  class HostController < ApplicationController
    def show
      @record = HostRecord.find(1)
      @surface = @record.surface
      if params[:mismatch]
        @surface = OpenUI::Rails::Surface.new(id: 1, response: @record.response, library_version: "foreign-library")
      end
    end
  end
RUBY
FileUtils.mkdir_p("app/views/host")
File.write("app/views/host/show.html.erb", <<~'ERB')
  <h1>Public API consumer</h1>
  <p>Saved note: <%= @surface.context&.fetch("saved_note", nil) %></p>
  <% begin %>
    <%= openui_surface(surface: @surface, label: "Release readiness") %>
  <% rescue OpenUI::Rails::LibraryVersionError %>
    <p role="alert">Saved interface uses a different library. Review canonical records before regenerating.</p>
  <% end %>
  <p role="status" id="result">Effects: <%= @record.effects %></p>
  <p role="alert" id="error"></p>
ERB
File.write("app/views/layouts/application.html.erb", <<~'ERB')
  <!doctype html><html lang="en"><head><title>Public API consumer</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <%= csrf_meta_tags %><%= openui_stylesheet_tag %><%= javascript_importmap_tags %>
  </head><body><main><%= yield %></main></body></html>
ERB
File.write("config/routes.rb", 'Rails.application.routes.draw { mount OpenUI::Rails::Engine => "/openui-rails"; root "host#show" }')
File.write("config/importmap.rb", <<~'RUBY')
  pin "application"
  pin "@hotwired/stimulus", to: "stimulus.min.js"
  pin_all_from OpenUI::Rails::Engine.root.join("app/javascript/openui"), under: "openui"
RUBY
FileUtils.mkdir_p("app/javascript")
File.write("app/javascript/application.js", <<~'JS')
  import { Application } from "@hotwired/stimulus"
  import OpenUIController from "openui/rails/openui_controller"
  Application.start().register("openui", OpenUIController)
  document.addEventListener("openui:action", ({detail}) => {
    document.querySelector("#result").textContent = `Effects: ${detail.result.value.effects}`
  })
  document.addEventListener("openui:error", ({detail}) => {
    document.querySelector("#error").textContent = detail.code || "render failed"
  })
JS
