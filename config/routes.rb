# frozen_string_literal: true

DiscourseKuuMarket::Engine.routes.draw do
  post "/listings" => "listings#create"
  put "/listings/:topic_id" => "listings#update"
  put "/listings/:topic_id/status" => "listings#update_status"
  post "/listings/:topic_id/hand" => "listings#raise_hand"
  delete "/listings/:topic_id/hand" => "listings#cancel_hand"
  put "/hand-alerts/dismiss" => "hand_alerts#dismiss"
end

Discourse::Application.routes.draw { mount ::DiscourseKuuMarket::Engine, at: "kuu-market" }
