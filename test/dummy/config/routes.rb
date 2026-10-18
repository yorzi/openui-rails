# frozen_string_literal: true

Rails.application.routes.draw do
  mount OpenUI::Rails::Engine => "/openui-rails"

  get "/demo", to: "demo#show"
  post "/expired-session", to: redirect("/demo", status: 302)
  if ENV["OPENUI_REAL_RUNTIME_DIR"]
    get "/audit-runtime/runtime.:format", to: "demo#runtime_asset", constraints: { format: /js|css/ }
  end
end
