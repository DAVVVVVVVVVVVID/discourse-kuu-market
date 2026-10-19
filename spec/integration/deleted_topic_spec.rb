# frozen_string_literal: true

# 删帖时保留二手帖记录（恢复帖子时原样回来），删掉期间插件不碰它；永久删除话题时记录随之删除
RSpec.describe "Listings of deleted topics" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:market, :category)
  fab!(:topic) { Fabricate(:topic, user: seller, category: market) }
  fab!(:first_post) { Fabricate(:post, topic:, user: seller) }
  fab!(:listing) do
    Fabricate(:kuu_market_listing, topic:, active_since: 40.days.ago, last_bumped_at: 40.days.ago)
  end

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
  end

  def expire_listings
    Jobs::KuuMarketExpireListings.new.execute({})
  end

  context "when staff deletes the topic" do
    before { PostDestroyer.new(admin, first_post).destroy }

    it "keeps the listing" do
      expect(topic.reload).to be_trashed
      expect(listing.reload.status).to eq("selling")
    end

    it "does not expire it or notify anyone" do
      expect { expire_listings }.not_to change { Notification.count }
      expect(listing.reload.status).to eq("selling")
    end

    it "does not let anyone change its status" do
      sign_in(admin)

      put "/kuu-market/listings/#{topic.id}/status.json", params: { status: "sold" }

      expect(response.status).to eq(403)
      expect(listing.reload.status).to eq("selling")
    end

    it "picks the listing up again once the topic is recovered" do
      PostDestroyer.new(admin, first_post.reload).recover

      expect { expire_listings }.to change { seller.notifications.count }.by(1)
      expect(listing.reload.status).to eq("expired")
    end
  end

  # core 先标记第一楼、关闭话题，过一段时间才真正删除
  context "when the seller deletes the topic" do
    before { PostDestroyer.new(seller, first_post).destroy }

    it "treats it as deleted while core waits to remove it" do
      expect(first_post.reload.user_deleted).to eq(true)
      expect(listing.reload).to be_topic_deleted
      expect { expire_listings }.not_to change { Notification.count }
      expect(listing.reload.status).to eq("selling")
    end
  end

  it "removes the listing when the topic is destroyed for good" do
    listing_id = listing.id

    topic.destroy!

    expect(DiscourseKuuMarket::Listing.exists?(listing_id)).to eq(false)
  end
end
