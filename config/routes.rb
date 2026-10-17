# frozen_string_literal: true

OpenUI::Rails::Engine.routes.draw do
  post "actions", to: "actions#create", as: :actions
end
