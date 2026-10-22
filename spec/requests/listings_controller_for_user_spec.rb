# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::ListingsController do
  fab!(:seller, :user)
  fab!(:stranger, :user)
  fab!(:moderator)
  fab!(:buyer, :user)
  fab!(:market, :category)

  fab!(:selling) do
    Fabricate(:kuu_market_listing, topic: Fabricate(:topic, user: seller, category: market))
  end
  fab!(:sold) do
    Fabricate(
      :kuu_market_listing,
      topic: Fabricate(:topic, user: seller, category: market),
      status: "sold",
    )
  end
  fab!(:expired) do
    Fabricate(
      :kuu_market_buy_listing,
      topic: Fabricate(:topic, user: seller, category: market),
      status: "expired",
      active_since: 40.days.ago,
    )
  end
  fab!(:someone_elses) do
    Fabricate(:kuu_market_listing, topic: Fabricate(:topic, user: stranger, category: market))
  end

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.kuu_market_expire_days = 30
  end

  def listings_of(user)
    get "/kuu-market/users/#{user.username}/listings.json"
  end

  def topic_ids
    response.parsed_body["listings"].map { it["topic_id"] }
  end

  it "lists all of the seller's own listings, newest first" do
    selling.topic.update!(created_at: 1.hour.ago)
    sold.topic.update!(created_at: 2.hours.ago)
    expired.topic.update!(created_at: 3.hours.ago)
    sign_in(seller)

    listings_of(seller)

    expect(response.status).to eq(200)
    expect(topic_ids).to eq([selling.topic_id, sold.topic_id, expired.topic_id])
  end

  it "includes what the page and its buttons need" do
    selling.raised_hands.create!(user: buyer)
    sign_in(seller)

    listings_of(seller)

    listings = response.parsed_body["listings"].index_by { it["topic_id"] }
    expect(listings[selling.topic_id]).to include(
      "status" => "selling",
      "item_name" => "宜家书桌",
      "url" => selling.topic.relative_url,
      "hands_count" => 1,
      "can_manage" => true,
      "statuses_reachable" => ["sold"],
    )
    expect(listings[selling.topic_id]["photo_url"]).to be_present
    expect(listings[selling.topic_id]["expires_at"]).to be_present
    expect(listings[expired.topic_id]["expired_at"]).to be_present
    expect(listings[sold.topic_id]).not_to have_key("hands_count")
  end

  it "leaves out deleted listings and listings moved out of the market" do
    sold.topic.trash!
    expired.topic.update!(category: Fabricate(:category))
    sign_in(seller)

    listings_of(seller)

    expect(topic_ids).to eq([selling.topic_id])
  end

  it "is not found for other people" do
    sign_in(stranger)

    listings_of(seller)

    expect(response.status).to eq(404)
  end

  it "lets staff look" do
    sign_in(moderator)

    listings_of(seller)

    expect(response.status).to eq(200)
    expect(topic_ids).to contain_exactly(selling.topic_id, sold.topic_id, expired.topic_id)
  end

  it "requires login" do
    listings_of(seller)

    expect(response.status).to eq(403)
  end

  it "is empty for someone without listings" do
    sign_in(buyer)

    listings_of(buyer)

    expect(response.parsed_body["listings"]).to eq([])
  end

  it "serves the page itself when opened directly" do
    sign_in(seller)

    get "/u/#{seller.username}/market"

    expect(response.status).to eq(200)
  end
end
