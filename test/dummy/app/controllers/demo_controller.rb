# frozen_string_literal: true

class DemoController < ApplicationController
  # Exercises the view helper end to end: a static surface plus a streaming one.
  def show
    @surface = OpenUI::Rails::Surface.new(
      id: "surface-1",
      version: 2,
      library_version: "sha256:abc123",
      response: "root = TextContent(\"Hello from OpenUI\")"
    )

    @streaming_surface = OpenUI::Rails::Surface.new(
      id: "surface-2",
      version: 0,
      library_version: "sha256:abc123",
      response: "root = TextContent(\"Streaming\")"
    )
  end
end
