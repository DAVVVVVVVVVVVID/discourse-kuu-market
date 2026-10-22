# frozen_string_literal: true

RSpec.describe "Filtering the market by campus and category" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "Market") }
  fab!(:other_category) { Fabricate(:category, name: "Chat") }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
  end

  def listed(item_name, area:, categories:)
    topic = Fabricate(:topic, user: seller, category: market, title: "Listing #{item_name} here")
    Fabricate(:post, topic:, user: seller)
    Fabricate(:kuu_market_listing, topic:, item_name:, area:, categories:)
  end

  let!(:desk) { listed("Desk", area: "yoshida", categories: %w[furniture_appliances]) }
  let!(:laptop) { listed("Laptop", area: "yoshida", categories: %w[electronics]) }
  let!(:lamp) { listed("Lamp", area: "uji", categories: %w[furniture_appliances]) }

  def card(listing)
    ".kuu-market-card[data-topic-id='#{listing.topic_id}']"
  end

  def option(param, value)
    find(
      ".kuu-market-filters__row[data-param='#{param}'] .kuu-market-filters__option[data-value='#{value}']",
    )
  end

  it "filters by campus and category together, keeping the filters in the URL" do
    visit("/c/#{market.slug}/#{market.id}")
    expect(page).to have_css(card(desk))
    expect(page).to have_css(card(lamp))
    expect(page).to have_css(".kuu-market-card__area", text: "Yoshida")

    option("kuu_area", "yoshida").click
    expect(page).to have_current_path(/kuu_area=yoshida/)
    expect(page).to have_no_css(card(lamp))
    expect(page).to have_css(card(laptop))

    option("kuu_category", "furniture_appliances").click
    expect(page).to have_current_path(/kuu_category=furniture_appliances/)
    expect(page).to have_css(card(desk))
    expect(page).to have_no_css(card(laptop))
    expect(option("kuu_area", "yoshida")[:class]).to include("--selected")

    page.refresh
    expect(page).to have_css(card(desk))
    expect(page).to have_no_css(card(laptop))
    expect(page).to have_no_css(card(lamp))

    option("kuu_area", "all").click
    expect(page).to have_no_current_path(/kuu_area/)
    expect(page).to have_css(card(lamp))
  end

  it "only shows the filters on the market page" do
    Fabricate(:topic_with_op, category: other_category)
    visit("/c/#{other_category.slug}/#{other_category.id}")

    expect(page).to have_css("#main-outlet .topic-list")
    expect(page).to have_no_css(".kuu-market-filters")
  end
end
