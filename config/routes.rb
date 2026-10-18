# frozen_string_literal: true

DiscourseKuuMarket::Engine.routes.draw { post "/listings" => "listings#create" }

Discourse::Application.routes.draw { mount ::DiscourseKuuMarket::Engine, at: "kuu-market" }
