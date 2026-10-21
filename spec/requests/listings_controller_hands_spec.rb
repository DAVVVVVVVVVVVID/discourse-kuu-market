# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::ListingsController do
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:buyer) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:market, :category)
  fab!(:topic) { Fabricate(:topic, user: author, category: market) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }
  fab!(:listing) { Fabricate(:kuu_market_listing, topic:) }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def raise_hand
    post "/kuu-market/listings/#{topic.id}/hand.json"
  end

  def cancel_hand
    delete "/kuu-market/listings/#{topic.id}/hand.json"
  end

  def topic_listing
    get "/t/#{topic.id}.json"
    response.parsed_body["kuu_market_listing"]
  end

  describe "#raise_hand" do
    it "requires login" do
      raise_hand

      expect(response.status).to eq(403)
    end

    context "when signed in as someone else" do
      before { sign_in(buyer) }

      it "raises the hand and says the author was messaged" do
        expect { raise_hand }.to change { listing.raised_hands.active.count }.by(1)

        expect(response.status).to eq(200)
        expect(response.parsed_body["delivery"]).to eq("sent")
        expect(response.parsed_body["chat_channel_id"]).to eq(
          Chat::DirectMessage.for_user_ids([author.id, buyer.id]).direct_message_channel.id,
        )
        expect(response.parsed_body["listing"]).to include(
          "hand_raised" => true,
          "raised_hands" => [include("username" => buyer.username)],
        )
      end

      it "says when the author could not be messaged" do
        author.user_option.update!(allow_private_messages: false)

        raise_hand

        expect(response.parsed_body["delivery"]).to eq("poster_unavailable")
        expect(response.parsed_body["chat_channel_id"]).to be_nil
      end

      it "refuses a second raise" do
        raise_hand
        raise_hand

        expect(response.status).to eq(422)
      end

      it "stops people raising and lowering their hand over and over" do
        raise_hand
        cancel_hand
        raise_hand
        cancel_hand

        expect(response.status).to eq(429)
        expect(response.parsed_body["errors"]).to eq(
          [I18n.t("kuu_market.errors.too_many_hand_actions")],
        )
        expect(listing.raised_hands.active.count).to eq(1)
      end
    end

    it "is not available to the author" do
      sign_in(author)

      raise_hand

      expect(response.status).to eq(403)
    end
  end

  describe "#cancel_hand" do
    before { sign_in(buyer) }

    it "lowers the hand" do
      raise_hand

      cancel_hand

      expect(response.status).to eq(200)
      expect(response.parsed_body["delivery"]).to eq("sent")
      expect(response.parsed_body["listing"]).to include(
        "hand_raised" => false,
        "raised_hands" => [],
      )
      expect(listing.raised_hands.active).to be_empty
    end

    it "is not found when the hand was not raised" do
      cancel_hand

      expect(response.status).to eq(404)
    end
  end

  describe "the topic page" do
    fab!(:early, :user)

    before { listing.raised_hands.create!(user: early, created_at: 1.hour.ago) }

    it "shows everyone the queue in order" do
      listing.raised_hands.create!(user: buyer)

      expect(topic_listing["raised_hands"].map { it["username"] }).to eq(
        [early.username, buyer.username],
      )
      expect(topic_listing).not_to include("hand_raised")
      expect(topic_listing["can_raise_hand"]).to eq(false)
    end

    it "leaves out lowered hands" do
      listing.raised_hands.create!(user: buyer, cancelled_at: Time.zone.now)

      expect(topic_listing["raised_hands"].map { it["username"] }).to eq([early.username])
    end

    it "tells signed in people whether they raised their hand" do
      sign_in(buyer)

      expect(topic_listing).to include("hand_raised" => false, "can_raise_hand" => true)

      raise_hand

      expect(topic_listing["hand_raised"]).to eq(true)
    end

    it "does not offer the author to raise their hand" do
      sign_in(author)

      expect(topic_listing).to include("hand_raised" => false, "can_raise_hand" => false)
    end

    it "shows everyone who it was sold to" do
      sign_in(author)
      put "/kuu-market/listings/#{topic.id}/status.json",
          params: {
            status: "sold",
            deal_user_id: early.id,
          }
      expect(response.status).to eq(200)

      sign_out
      expect(topic_listing["deal_user"]).to include("username" => early.username)
    end

    it "refuses a buyer who did not raise their hand" do
      sign_in(author)
      put "/kuu-market/listings/#{topic.id}/status.json",
          params: {
            status: "sold",
            deal_user_id: buyer.id,
          }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq(
        [I18n.t("kuu_market.errors.deal_user_not_in_queue")],
      )
    end

    it "shows no buyer when it was sold elsewhere" do
      listing.update!(status: "sold")

      expect(topic_listing).not_to include("deal_user")
    end

    it "does not show the queue once the listing is sold" do
      listing.update!(status: "sold")

      expect(topic_listing).not_to include("raised_hands")
    end
  end
end
