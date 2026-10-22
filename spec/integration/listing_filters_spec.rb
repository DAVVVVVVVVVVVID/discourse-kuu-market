# frozen_string_literal: true

# 二手市场页按校区、商品分类筛选（Issue #11）：网址里的 kuu_area / kuu_category
RSpec.describe "Filtering the market by campus and category" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market, :category)

  fab!(:yoshida_desk) { listed(area: "yoshida", categories: %w[furniture_appliances]) }
  fab!(:yoshida_laptop) { listed(area: "yoshida", categories: %w[electronics study]) }
  fab!(:uji_lamp) { listed(area: "uji", categories: %w[furniture_appliances electronics]) }
  fab!(:old_listing) { listed(area: nil, categories: []) }
  fab!(:other_topic) { Fabricate(:topic, category: market) }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
  end

  def listed(**attributes)
    topic = Fabricate(:topic, user: seller, category: market)
    Fabricate(:post, topic:, user: seller)
    Fabricate(:kuu_market_listing, topic:, **attributes)
    topic
  end

  def topic_ids(**params)
    get "/c/#{market.slug}/#{market.id}/l/latest.json", params: params
    expect(response.status).to eq(200)
    response.parsed_body["topic_list"]["topics"].map { it["id"] }
  end

  it "shows everything without filters" do
    expect(topic_ids).to include(
      yoshida_desk.id,
      yoshida_laptop.id,
      uji_lamp.id,
      old_listing.id,
      other_topic.id,
    )
  end

  it "filters by campus" do
    expect(topic_ids(kuu_area: "yoshida")).to contain_exactly(yoshida_desk.id, yoshida_laptop.id)
  end

  it "filters by category" do
    expect(topic_ids(kuu_category: "electronics")).to contain_exactly(
      yoshida_laptop.id,
      uji_lamp.id,
    )
  end

  it "combines both" do
    expect(topic_ids(kuu_area: "yoshida", kuu_category: "electronics")).to contain_exactly(
      yoshida_laptop.id,
    )
  end

  it "ignores values it does not know" do
    expect(topic_ids(kuu_area: "kyoto", kuu_category: "'; drop table topics; --")).to include(
      yoshida_desk.id,
      old_listing.id,
    )
  end

  it "does nothing when the market is turned off" do
    SiteSetting.kuu_market_enabled = false

    expect(topic_ids(kuu_area: "uji")).to include(yoshida_desk.id, uji_lamp.id)
  end
end
