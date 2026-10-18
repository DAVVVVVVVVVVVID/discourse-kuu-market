# frozen_string_literal: true

RSpec.describe Jobs::KuuMarketExpireListings do
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market, :category)

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.kuu_market_expire_days = 30
    # 数据库把时间存到微秒，冻结在整秒上，「刚好 30 天」才不会差几纳秒
    freeze_time(Time.zone.now.change(usec: 0))
  end

  def job
    described_class.new.execute({})
  end

  def listing_active_since(time, status: "selling", category: market)
    topic = Fabricate(:topic, user: author, category:)
    Fabricate(:post, topic:, user: author)
    Fabricate(:kuu_market_listing, topic:, status:, active_since: time, last_bumped_at: time)
  end

  it "expires a listing exactly 30 days after it went on sale" do
    listing = listing_active_since(30.days.ago)

    job

    expect(listing.reload.status).to eq("expired")
  end

  it "does not expire a listing one second before 30 days" do
    listing = listing_active_since(30.days.ago + 1.second)

    job

    expect(listing.reload.status).to eq("selling")
  end

  it "counts from the latest relisting, not from the first post" do
    listing = listing_active_since(40.days.ago, status: "sold")
    DiscourseKuuMarket::Listing::ChangeStatus.call(
      params: {
        topic_id: listing.topic_id,
        status: "selling",
      },
      guardian: author.guardian,
    )

    freeze_time(29.days.from_now)
    job
    expect(listing.reload.status).to eq("selling")

    freeze_time(1.day.from_now)
    job
    expect(listing.reload.status).to eq("expired")
  end

  it "is not postponed by other people's replies" do
    listing = listing_active_since(30.days.ago)
    PostCreator.create!(
      Fabricate(:user, refresh_auto_groups: true),
      topic_id: listing.topic_id,
      raw: "Is this still available? I can pick it up today.",
    )

    job

    expect(listing.reload.status).to eq("expired")
  end

  it "hides the topic but keeps replies open" do
    listing = listing_active_since(31.days.ago)

    job

    expect(listing.topic.reload).to have_attributes(visible: false, closed: false)
  end

  it "notifies the author in the site only" do
    listing = listing_active_since(31.days.ago)

    expect { job }.to change { author.notifications.count }.by(1)

    notification = author.notifications.last
    expect(notification).to have_attributes(
      notification_type: Notification.types[:custom],
      topic_id: listing.topic_id,
      post_number: 1,
    )
    expect(notification.data_hash).to include(
      message: "kuu_market.notifications.expired",
      kind: "sell",
    )
  end

  it "expires buy listings too" do
    listing = listing_active_since(31.days.ago)
    listing.update!(
      kind: "buy",
      status: "buying",
      price: nil,
      trade_method: nil,
      budget_max: 5000,
      upload_ids: [],
    )

    job

    expect(listing.reload.status).to eq("expired")
  end

  it "leaves sold, closed and already expired listings alone" do
    sold = listing_active_since(40.days.ago, status: "sold")
    expired = listing_active_since(40.days.ago, status: "expired")

    expect { job }.not_to change { Notification.count }

    expect(sold.reload.status).to eq("sold")
    expect(expired.reload.status).to eq("expired")
  end

  it "leaves listings moved out of the market and deleted topics alone" do
    moved = listing_active_since(40.days.ago, category: Fabricate(:category))
    deleted = listing_active_since(40.days.ago)
    deleted.topic.trash!

    job

    expect(moved.reload.status).to eq("selling")
    expect(deleted.reload.status).to eq("selling")
  end

  it "does nothing while the plugin is disabled" do
    listing = listing_active_since(40.days.ago)
    SiteSetting.kuu_market_enabled = false

    job

    expect(listing.reload.status).to eq("selling")
  end

  it "follows the configured number of days" do
    SiteSetting.kuu_market_expire_days = 7
    listing = listing_active_since(7.days.ago)

    job

    expect(listing.reload.status).to eq("expired")
  end
end
