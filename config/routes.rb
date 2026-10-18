# frozen_string_literal: true

DiscourseKuuMarket::Engine.routes.draw do
  post "/listings" => "listings#create"
  put "/listings/:topic_id" => "listings#update"
  put "/listings/:topic_id/status" => "listings#update_status"
end

Discourse::Application.routes.draw { mount ::DiscourseKuuMarket::Engine, at: "kuu-market" }
