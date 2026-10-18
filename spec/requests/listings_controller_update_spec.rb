# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::ListingsController do
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:moderator)
  fab!(:stranger, :user)
  fab!(:market, :category)
  fab!(:photo) { Fabricate(:image_upload, user: author) }
  fab!(:new_photo) { Fabricate(:image_upload, user: author) }

  fab!(:listing) do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.default_locale = "zh_CN"

    result =
      DiscourseKuuMarket::Listing::Create.call(
        params: {
          kind: "sell",
          item_name: "宜家书桌",
          price: 3000,
          location: "吉田本校区",
          trade_method: "pickup",
          upload_ids: [photo.id],
        },
        guardian: author.guardian,
      )
    post = result.new_post_result.post
    post.update_columns(created_at: 3.days.ago, last_version_at: 3.days.ago)
    post.topic.kuu_market_listing
  end

  let(:topic) { listing.topic }
  let(:update_params) do
    {
      kind: "sell",
      item_name: "宜家书桌",
      price: 2000,
      location: "吉田本校区",
      trade_method: "delivery",
      description: "降价了",
      upload_ids: [photo.id, new_photo.id],
    }
  end

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.default_locale = "zh_CN"
    SiteSetting.post_edit_time_limit = 60
  end

  def update_listing(params = update_params)
    put "/kuu-market/listings/#{topic.id}.json", params:
  end

  describe "#update" do
    it "requires login" do
      update_listing

      expect(response.status).to eq(403)
    end

    context "when the author edits after the edit time limit" do
      before { sign_in(author) }

      it "regenerates the title and first post and keeps the edit history" do
        update_listing

        expect(response.status).to eq(204)
        expect(topic.reload.title).to eq("【出售】宜家书桌 · ¥2,000")
        expect(topic.first_post.raw).to include("- **交易方式**：可送")
        expect(topic.first_post.raw).to end_with("降价了")
        expect(topic.first_post.version).to eq(2)
        expect(topic.first_post.revisions.last.user).to eq(author)
        expect(listing.reload).to have_attributes(
          price: 2000,
          trade_method: "delivery",
          upload_ids: [photo.id, new_photo.id],
        )
      end

      it "neither bumps the topic nor restarts the expiry clock" do
        expect { update_listing }.not_to change {
          [topic.reload.bumped_at, listing.reload.active_since]
        }
      end

      it "works on a sold listing whose replies are closed" do
        listing.update!(status: "sold")
        topic.update!(closed: true)

        update_listing

        expect(response.status).to eq(204)
        expect(topic.reload.title).to eq("【出售】宜家书桌 · ¥2,000")
      end

      it "cannot switch between selling and buying" do
        update_listing(update_params.merge(kind: "buy", budget_max: 5000))

        expect(response.status).to eq(422)
        expect(listing.reload.kind).to eq("sell")
      end

      it "returns the field errors" do
        update_listing(update_params.merge(upload_ids: []))

        expect(response.status).to eq(422)
        expect(listing.reload.upload_ids).to eq([photo.id])
      end

      it "cannot add someone else's secure photo" do
        update_listing(update_params.merge(upload_ids: [Fabricate(:image_upload, secure: true).id]))

        expect(response.status).to eq(403)
      end

      it "cannot edit a listing moved out of the market" do
        topic.update!(category: Fabricate(:category))

        update_listing

        expect(response.status).to eq(404)
      end

      it "cannot edit while silenced" do
        author.update!(silenced_till: 1.day.from_now)

        update_listing

        expect(response.status).to eq(403)
      end
    end

    it "does not let other users edit" do
      sign_in(stranger)

      update_listing

      expect(response.status).to eq(403)
      expect(listing.reload.price).to eq(3000)
    end

    it "lets staff edit and keep the author's photos" do
      sign_in(moderator)

      update_listing(update_params.merge(upload_ids: [photo.id]))

      expect(response.status).to eq(204)
      expect(topic.reload.first_post.revisions.last.user).to eq(moderator)
    end

    it "returns 404 for a topic without a listing" do
      sign_in(author)

      put "/kuu-market/listings/#{Fabricate(:topic, category: market).id}.json",
          params: update_params

      expect(response.status).to eq(404)
    end
  end
end
