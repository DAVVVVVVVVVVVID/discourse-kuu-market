# frozen_string_literal: true

DiscourseKuuMarket::Engine.routes.draw {}

Discourse::Application.routes.draw { mount ::DiscourseKuuMarket::Engine, at: "kuu-market" }
