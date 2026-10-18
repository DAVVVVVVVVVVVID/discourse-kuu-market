# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::Listing::Action::SyncTopic do
  subject(:sync) { described_class.call(listing:) }

  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market, :category)
  fab!(:topic) { Fabricate(:topic, user: author, category: market) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }
  fab!(:listing) { Fabricate(:kuu_market_listing, topic:) }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
  end

  def change_status_to(status)
    listing.change_status(status)
  end

  context "when a sell listing is sold" do
    before { change_status_to("sold") }

    it "closes replies and hides the topic, remembering it did so" do
      sync

      expect(topic.reload).to have_attributes(closed: true, visible: false)
      expect(listing).to have_attributes(closed_by_plugin: true, unlisted_by_plugin: true)
    end

    it "does not leave a small action post" do
      expect { sync }.not_to change { topic.posts.count }
    end

    it "updates what core updates when it hides a topic" do
      author.user_profile.update!(featured_topic: topic)
      CategoryFeaturedTopic.create!(category: market, topic:, rank: 0)
      TopicHotScore.create!(topic:, score: 1)

      expect { sync }.to change { market.reload.topic_count }.by(-1).and change {
              author.user_stat.reload.topic_count
            }.by(-1)

      expect(author.user_profile.reload.featured_topic).to be_nil
      expect(CategoryFeaturedTopic.where(topic:)).to be_empty
      expect(TopicHotScore.where(topic:)).to be_empty
    end
  end

  context "when a buy listing is closed" do
    before do
      listing.update!(
        kind: "buy",
        status: "buying",
        price: nil,
        trade_method: nil,
        budget_max: 5000,
        upload_ids: [],
      )
      change_status_to("closed")
    end

    it "closes replies and hides the topic" do
      sync

      expect(topic.reload).to have_attributes(closed: true, visible: false)
    end
  end

  context "when a listing expires" do
    before { listing.status = "expired" }

    it "hides the topic but keeps replies open" do
      sync

      expect(topic.reload).to have_attributes(closed: false, visible: false)
      expect(listing).to have_attributes(closed_by_plugin: false, unlisted_by_plugin: true)
    end
  end

  context "when a sold listing goes back on sale" do
    before do
      change_status_to("sold")
      described_class.call(listing:)
      listing.save!
      change_status_to("selling")
    end

    it "reopens replies and shows the topic again" do
      expect { sync }.to change { market.reload.topic_count }.by(1).and change {
              author.user_stat.reload.topic_count
            }.by(1)

      expect(topic.reload).to have_attributes(closed: false, visible: true)
      expect(listing).to have_attributes(closed_by_plugin: false, unlisted_by_plugin: false)
    end
  end

  context "when an expired listing is marked as sold" do
    before do
      listing.status = "expired"
      described_class.call(listing:)
      listing.save!
      change_status_to("sold")
    end

    it "closes replies and keeps the topic hidden" do
      expect { sync }.not_to change { market.reload.topic_count }

      expect(topic.reload).to have_attributes(closed: true, visible: false)
      expect(listing).to have_attributes(closed_by_plugin: true, unlisted_by_plugin: true)
    end
  end

  context "when staff closed the topic" do
    before { topic.update!(closed: true) }

    it "does not take over the closing when the listing is sold" do
      change_status_to("sold")
      sync

      expect(listing.closed_by_plugin).to eq(false)
    end

    it "leaves the topic closed when the listing goes back on sale" do
      change_status_to("sold")
      sync
      listing.save!
      change_status_to("selling")
      described_class.call(listing:)

      expect(topic.reload.closed).to eq(true)
    end
  end

  context "when staff unlisted the topic" do
    before { topic.update_status("visible", false, Fabricate(:admin)) }

    it "leaves the topic hidden when the listing is sold and back on sale" do
      change_status_to("sold")
      sync
      listing.save!

      expect(listing.unlisted_by_plugin).to eq(false)

      change_status_to("selling")
      described_class.call(listing:)

      expect(topic.reload.visible).to eq(false)
    end
  end

  context "when staff relisted a topic the plugin had hidden" do
    before do
      change_status_to("sold")
      described_class.call(listing:)
      listing.save!
      topic.reload.update_status("visible", true, Fabricate(:admin))
      listing.reload
      change_status_to("selling")
    end

    it "forgets its own hiding without counting the topic twice" do
      expect { sync }.not_to change { market.reload.topic_count }

      expect(listing.unlisted_by_plugin).to eq(false)
    end
  end
end
