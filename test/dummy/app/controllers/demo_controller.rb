# frozen_string_literal: true

class DemoController < ApplicationController
  # This test-only route emulates a static asset server, not a JS controller
  # response. Rails' same-origin JavaScript response check does not apply.
  skip_forgery_protection only: :runtime_asset

  def runtime_asset
    extension = params[:format]
    head :not_found and return unless %w[js css].include?(extension) && ENV["OPENUI_REAL_RUNTIME_DIR"]

    send_file File.join(ENV.fetch("OPENUI_REAL_RUNTIME_DIR"), "openui-browser-bundle-0.2.1.#{extension}"),
      disposition: "inline", type: extension == "js" ? "text/javascript" : "text/css"
  end

  # Exercises the view helper end to end: a static surface plus a streaming one.
  def show
    @surface = OpenUI::Rails::Surface.new(
      id: "surface-1",
      version: 2,
      library_version: OpenUI::Rails.configuration.library_fingerprint || "sha256:abc123",
      response: "root = TextContent(\"Hello from OpenUI\")"
    )

    @streaming_surface = OpenUI::Rails::Surface.new(
      id: "surface-2",
      version: 0,
      library_version: OpenUI::Rails.configuration.library_fingerprint || "sha256:abc123",
      response: "root = TextContent(\"Streaming\")"
    )
  end
end
