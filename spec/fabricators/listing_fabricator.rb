# frozen_string_literal: true

Fabricator(:kuu_market_listing, class_name: "DiscourseKuuMarket::Listing") do
  topic { Fabricate(:topic_with_op) }
  kind "sell"
  status "selling"
  active_since { Time.zone.now }
  last_bumped_at { Time.zone.now }
  item_name "宜家书桌"
  price 3000
  location "吉田本校区"
  area "yoshida"
  categories { ["furniture_appliances"] }
  trade_method "pickup"
  upload_ids { [Fabricate(:upload).tap { |upload| upload.save! if upload.new_record? }.id] }
end

Fabricator(:kuu_market_buy_listing, from: :kuu_market_listing) do
  kind "buy"
  status "buying"
  item_name "自行车"
  categories { ["transport_sports"] }
  price nil
  budget_min 5000
  budget_max 10_000
  trade_method nil
  upload_ids []
end
