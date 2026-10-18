# frozen_string_literal: true

module OpenUI
  module Rails
    # Preserve the host's authentication filters and current-user helpers.
    class ApplicationController < ::ApplicationController
      protect_from_forgery with: :exception
    end
  end
end
