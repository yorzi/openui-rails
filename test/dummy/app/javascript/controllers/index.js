// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import OpenUIController from "openui/rails/openui_controller"
import OpenUIEnvelopeController from "openui/rails/openui_envelope_controller"

eagerLoadControllersFrom("controllers", application)

// The engine's controllers are registered explicitly: they are not under
// app/javascript/controllers, so the eager loader cannot discover them.
application.register("openui", OpenUIController)
application.register("openui-envelope", OpenUIEnvelopeController)
