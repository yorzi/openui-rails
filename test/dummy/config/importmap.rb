# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# The engine's Stimulus controllers, served from the host asset path the engine
# registers (see OpenUI::Rails::Engine).
pin_all_from OpenUI::Rails::Engine.root.join("app/javascript/openui"), under: "openui"
