# frozen_string_literal: true

Rails.application.routes.draw do
  mount OpenUI::Rails::Engine => "/openui-rails"
end
