# frozen_string_literal: true

DiscourseKuuMarket::Engine.routes.draw do
  post "/listings" => "listings#create"
  put "/listings/:topic_id" => "listings#update"
  put "/listings/:topic_id/status" => "listings#update_status"
  post "/listings/:topic_id/hand" => "listings#raise_hand"
  delete "/listings/:topic_id/hand" => "listings#cancel_hand"
  put "/hand-alerts/dismiss" => "hand_alerts#dismiss"
  get "/users/:username/listings" => "listings#for_user",
      :constraints => {
        username: RouteFormat.username,
      }
end

Discourse::Application.routes.draw do
  mount ::DiscourseKuuMarket::Engine, at: "kuu-market"
  # 「我的商品」页（Issue #12）直接打开或刷新时，交给 core 的用户页，前端路由再接手
  get "u/:username/market" => "users#show", :constraints => { username: RouteFormat.username }
end
