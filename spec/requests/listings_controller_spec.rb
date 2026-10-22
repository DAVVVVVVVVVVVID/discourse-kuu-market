# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::ListingsController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "二手市场") }
  fab!(:photo) { Fabricate(:image_upload, user:) }

  let(:sell_params) do
    {
      kind: "sell",
      item_name: "宜家书桌",
      price: 3000,
      location: "吉田本校区",
      area: "yoshida",
      categories: ["furniture_appliances"],
      trade_method: "pickup",
      description: "九成新",
      upload_ids: [photo.id],
    }
  end

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.default_locale = "zh_CN"
  end

  describe "#create" do
    it "requires login" do
      post "/kuu-market/listings.json", params: sell_params

      expect(response.status).to eq(403)
    end

    it "is unavailable while the plugin is disabled" do
      SiteSetting.kuu_market_enabled = false
      sign_in(user)

      post "/kuu-market/listings.json", params: sell_params

      expect(response.status).to eq(404)
    end

    context "when signed in" do
      before { sign_in(user) }

      it "posts a sell listing with a generated title and first post" do
        expect { post "/kuu-market/listings.json", params: sell_params }.to change {
          DiscourseKuuMarket::Listing.count
        }.by(1)

        expect(response.status).to eq(200)
        expect(response.parsed_body["action"]).to eq("create_post")

        topic = Topic.find(response.parsed_body["post"]["topic_id"])
        expect(topic.title).to eq("【出售】宜家书桌 · ¥3,000")
        expect(topic.category).to eq(market)
        expect(topic.first_post.raw).to include("- **价格**：¥3,000")
        expect(topic.kuu_market_listing).to have_attributes(
          kind: "sell",
          status: "selling",
          item_name: "宜家书桌",
          price: 3000,
          upload_ids: [photo.id],
        )
      end

      it "posts a buy listing" do
        post "/kuu-market/listings.json",
             params: {
               kind: "buy",
               item_name: "自行车",
               budget_max: 10_000,
               location: "桂校区",
               area: "yoshida",
               categories: ["furniture_appliances"],
             }

        expect(response.status).to eq(200)
        listing = DiscourseKuuMarket::Listing.last
        expect(listing).to have_attributes(kind: "buy", status: "buying", budget_max: 10_000)
        expect(listing.topic.title).to eq("【求购】自行车 · ¥10,000 以内")
      end

      it "allows short and duplicate generated titles" do
        params = {
          kind: "sell",
          item_name: "伞",
          free: true,
          location: "吉田本校区",
          area: "yoshida",
          categories: ["furniture_appliances"],
          trade_method: "pickup",
          upload_ids: [photo.id],
        }

        post "/kuu-market/listings.json", params: params
        expect(response.status).to eq(200)

        post "/kuu-market/listings.json", params: params
        expect(response.status).to eq(200)

        expect(Topic.where(title: "【赠送】伞").count).to eq(2)
      end

      it "returns the field errors" do
        post "/kuu-market/listings.json", params: sell_params.merge(price: nil, upload_ids: [])

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].size).to eq(2)
      end

      it "rejects someone else's secure photos" do
        stranger_photo = Fabricate(:image_upload, secure: true)

        post "/kuu-market/listings.json", params: sell_params.merge(upload_ids: [stranger_photo.id])

        expect(response.status).to eq(403)
        expect(DiscourseKuuMarket::Listing.count).to eq(0)
      end

      it "rejects an unknown kind" do
        post "/kuu-market/listings.json", params: sell_params.merge(kind: "rent")

        expect(response.status).to eq(400)
      end

      it "still applies watched words" do
        Fabricate(:watched_word, word: "代写", action: WatchedWord.actions[:block])

        post "/kuu-market/listings.json", params: sell_params.merge(description: "可以代写作业")

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to include("代写")
        expect(DiscourseKuuMarket::Listing.count).to eq(0)
      end

      it "returns 404 when the market category is not set" do
        SiteSetting.kuu_market_category = ""

        post "/kuu-market/listings.json", params: sell_params

        expect(response.status).to eq(404)
      end

      it "returns 403 when the user cannot post in the market" do
        market.set_permissions(everyone: :readonly)
        market.save!

        post "/kuu-market/listings.json", params: sell_params

        expect(response.status).to eq(403)
      end

      context "when new posts need approval" do
        before { SiteSetting.approve_post_count = 1 }

        it "queues the listing and creates it once approved" do
          post "/kuu-market/listings.json", params: sell_params

          expect(response.status).to eq(200)
          expect(response.parsed_body["action"]).to eq("enqueued")
          expect(DiscourseKuuMarket::Listing.count).to eq(0)

          reviewable = ReviewableQueuedPost.last
          reviewable.perform(Fabricate(:moderator), :approve_post)

          topic = reviewable.reload.target.topic
          expect(topic.title).to eq("【出售】宜家书桌 · ¥3,000")
          expect(topic.kuu_market_listing).to have_attributes(
            kind: "sell",
            status: "selling",
            price: 3000,
          )
        end
      end
    end
  end
end
