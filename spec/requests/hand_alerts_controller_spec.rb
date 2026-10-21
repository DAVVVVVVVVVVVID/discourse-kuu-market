# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::HandAlertsController do
  fab!(:seller, :user)
  fab!(:buyer, :user)
  fab!(:late_buyer, :user)
  fab!(:market, :category)
  fab!(:listing) do
    Fabricate(:kuu_market_listing, topic: Fabricate(:topic, user: seller, category: market))
  end
  fab!(:hand) { listing.raised_hands.create!(user: buyer) }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
  end

  def current_user_alerts
    get "/session/current.json"
    response.parsed_body["current_user"]["kuu_market_hand_alerts"]
  end

  it "tells the seller about new hands when the forum loads" do
    sign_in(seller)

    expect(current_user_alerts).to eq(
      "listings" => [
        { "topic_id" => listing.topic_id, "kind" => "sell", "item_name" => "宜家书桌", "count" => 1 },
      ],
      "up_to_id" => hand.id,
      "chat_channel_id" => nil,
    )
  end

  describe "#dismiss" do
    it "requires login" do
      put "/kuu-market/hand-alerts/dismiss.json", params: { up_to_id: hand.id }

      expect(response.status).to eq(403)
    end

    it "stops alerting about the hands that were shown, but not later ones" do
      sign_in(seller)
      later = listing.raised_hands.create!(user: late_buyer)

      put "/kuu-market/hand-alerts/dismiss.json", params: { up_to_id: hand.id }

      expect(response.status).to eq(204)
      expect(hand.reload.alerted_at).to be_present
      expect(later.reload.alerted_at).to be_nil
      expect(current_user_alerts["listings"]).to contain_exactly(include("count" => 1))
      expect(current_user_alerts["up_to_id"]).to eq(later.id)
    end

    it "does not touch other people's alerts" do
      sign_in(buyer)

      put "/kuu-market/hand-alerts/dismiss.json", params: { up_to_id: hand.id }

      expect(response.status).to eq(204)
      expect(hand.reload.alerted_at).to be_nil
    end

    it "needs to know which hands were shown" do
      sign_in(seller)

      put "/kuu-market/hand-alerts/dismiss.json"

      expect(response.status).to eq(400)
    end
  end
end
