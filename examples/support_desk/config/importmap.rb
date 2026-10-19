pin "support_desk", to: "support_desk.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin_all_from OpenUI::Rails::Engine.root.join("app/javascript/openui"), under: "openui"
