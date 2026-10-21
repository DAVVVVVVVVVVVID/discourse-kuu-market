# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::RaisedHand do
  describe ".alerts_for" do
    fab!(:seller, :user)
    fab!(:market, :category)
    fab!(:desk) do
      Fabricate(:kuu_market_listing, topic: Fabricate(:topic, user: seller, category: market))
    end
    fab!(:bike) do
      Fabricate(:kuu_market_buy_listing, topic: Fabricate(:topic, user: seller, category: market))
    end
    fab!(:first_user, :user)
    fab!(:second_user, :user)

    before do
      SiteSetting.kuu_market_enabled = true
      SiteSetting.kuu_market_category = market.id
    end

    def alerts
      described_class.alerts_for(seller)
    end

    it "is nil without new hands" do
      expect(alerts).to be_nil
    end

    it "counts new hands on each listing, in the order they came in" do
      bike.raised_hands.create!(user: first_user)
      desk.raised_hands.create!(user: first_user)
      last = desk.raised_hands.create!(user: second_user)

      expect(alerts).to eq(
        listings: [
          { topic_id: bike.topic_id, kind: "buy", item_name: "自行车", count: 1 },
          { topic_id: desk.topic_id, kind: "sell", item_name: "宜家书桌", count: 2 },
        ],
        up_to_id: last.id,
      )
    end

    it "only counts hands the seller has not been alerted about" do
      desk.raised_hands.create!(user: first_user, alerted_at: 1.hour.ago)
      desk.raised_hands.create!(user: second_user)

      expect(alerts[:listings]).to contain_exactly(include(topic_id: desk.topic_id, count: 1))
    end

    it "leaves out lowered hands and queues that ended" do
      desk.raised_hands.create!(user: first_user, cancelled_at: 1.minute.ago)
      desk.raised_hands.create!(user: second_user, ended_at: 1.minute.ago)

      expect(alerts).to be_nil
    end

    it "leaves out listings that are no longer in progress" do
      desk.raised_hands.create!(user: first_user)
      desk.update!(status: "expired")

      expect(alerts).to be_nil
    end

    it "leaves out deleted topics and topics moved out of the market" do
      desk.raised_hands.create!(user: first_user)
      bike.raised_hands.create!(user: first_user)
      desk.topic.trash!
      bike.topic.update!(category: Fabricate(:category))

      expect(alerts).to be_nil
    end

    it "leaves out other people's listings" do
      desk.raised_hands.create!(user: first_user)

      expect(described_class.alerts_for(first_user)).to be_nil
    end
  end
end
