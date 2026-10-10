// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>
console.log('Vite ⚡️ Rails')

// If using a TypeScript entrypoint file:
//     <%= vite_typescript_tag 'application' %>
//
// If you want to use .jsx or .tsx, add the extension:
//     <%= vite_javascript_tag 'application.jsx' %>

console.log('Visit the guide for more information: ', 'https://vite-ruby.netlify.app/guide/rails')

// Example: Load Rails libraries in Vite.
//
import '@hotwired/turbo-rails'

import { Application } from "@hotwired/stimulus"
import BankSelectController from "../controllers/bank_select_controller"
import ToggleController from "../controllers/toggle_controller"
import FlashController from "../controllers/flash_controller"
import RecommendationProgressController from "../controllers/recommendation_progress_controller"

const application = Application.start()
application.register("bank-select", BankSelectController)
application.register("toggle", ToggleController)
application.register("flash", FlashController)
application.register("recommendation-progress", RecommendationProgressController)

import './application.css'
