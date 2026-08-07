# frozen_string_literal: true

RailsTablePreferences::Engine.routes.draw do
  scope "preferences/:table_key", constraints: { table_key: %r{[^/]+} } do
    get "/", to: "preferences#index", as: nil
    post "/", to: "preferences#create", as: nil
    get "/:name", to: "preferences#show", as: nil
    patch "/:name", to: "preferences#update", as: nil
    put "/:name", to: "preferences#update", as: nil
    delete "/:name", to: "preferences#destroy", as: nil
  end
end
