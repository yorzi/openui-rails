# frozen_string_literal: true

class DemoController < ApplicationController
  # Exercises the view helper end to end with a static, pre-rendered surface.
  def show
    @surface = OpenUI::Rails::Surface.new(
      id: "surface-1",
      version: 2,
      library_version: "sha256:abc123",
      response: "root = TextContent(\"Hello from OpenUI\")"
    )
  end
end
