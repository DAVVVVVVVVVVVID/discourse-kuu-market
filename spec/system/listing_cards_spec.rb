# frozen_string_literal: true

RSpec.describe "Listings shown as product cards in topic lists" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:viewer) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "Market") }
  fab!(:ratings) { Fabricate(:category, name: "Ratings") }
  fab!(:regular_topic) do
    Fabricate(:topic_with_op, title: "A regular topic about bikes", category: ratings)
  end
  fab!(:placeholder, :image_upload)
  fab!(:buy_image, :image_upload)

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.default_locale = "zh_CN"
    SiteSetting.kuu_market_placeholder_image = placeholder
    SiteSetting.kuu_market_buy_image = buy_image
  end

  def post_listing(**params)
    photo = Fabricate(:image_upload, user: seller)
    DiscourseKuuMarket::Listing::Create
      .call(
        params: {
          kind: "sell",
          location: "吉田本校区",
          trade_method: "pickup",
          upload_ids: [photo.id],
          **params,
        },
        guardian: seller.guardian,
      )
      .new_post_result
      .post
      .topic
  end

  def card(topic)
    find(".topic-list-item[data-topic-id='#{topic.id}'] .kuu-market-card")
  end

  it "shows sell, free and buy listings as cards with their price" do
    sell = post_listing(item_name: "MacBook Air M2", price: 52_000)
    free = post_listing(item_name: "Rice cooker", free: true)
    buy =
      post_listing(
        kind: "buy",
        item_name: "Bicycle",
        budget_min: 0,
        budget_max: 2000,
        trade_method: nil,
        upload_ids: [],
      )
    sign_in(viewer)

    visit("/latest")

    expect(card(sell)).to have_css(".kuu-market-card__name", exact_text: "MacBook Air M2")
    expect(card(sell)).to have_css(".kuu-market-card__price", exact_text: "¥52,000")
    expect(card(sell)).to have_css(".kuu-market-card__status", exact_text: "在售")
    expect(card(sell)).to have_no_text("【出售】")

    expect(card(free)).to have_css(".kuu-market-card__price.--free", exact_text: "赠送")

    expect(card(buy)).to have_css(".kuu-market-card__price", exact_text: "¥0–2,000")
    expect(card(buy)).to have_css(".kuu-market-card__status", exact_text: "求购中")
    expect(card(buy).find(".kuu-market-card__image img")[:src]).to include(buy_image.url)

    price = card(sell).find(".kuu-market-card__price")
    expect(price.evaluate_script("getComputedStyle(this).color")).to eq("rgb(229, 72, 77)")
  end

  it "uses the placeholder for a sell listing without a photo" do
    topic = post_listing(item_name: "Desk", price: 3000)
    topic.kuu_market_listing.update_columns(upload_ids: [])
    topic.update_columns(image_upload_id: nil)
    sign_in(viewer)

    visit("/latest")

    expect(card(topic).find(".kuu-market-card__image img")[:src]).to include(placeholder.url)
  end

  it "shows the cards in the market category too" do
    topic = post_listing(item_name: "Desk", price: 3000)
    sign_in(viewer)

    visit("/c/#{market.slug}/#{market.id}")

    expect(card(topic)).to have_css(".kuu-market-card__name", exact_text: "Desk")
  end

  it "leaves other topics as they are" do
    post_listing(item_name: "Desk", price: 3000)
    sign_in(viewer)

    visit("/latest")

    item = find(".topic-list-item[data-topic-id='#{regular_topic.id}']")
    expect(item).to have_css("a.title.raw-topic-link", text: "A regular topic about bikes")
    expect(item).to have_no_css(".kuu-market-card")
  end

  it "keeps the topic page as it was" do
    topic = post_listing(item_name: "Desk", price: 3000, description: "Pick up this weekend")
    sign_in(viewer)

    topic_page.visit_topic(topic)

    expect(page).to have_css("#topic-title .fancy-title", text: "【出售】Desk · ¥3,000")
    expect(page).to have_css("#post_1 .cooked", text: "吉田本校区")
    expect(page).to have_css("#post_1 .cooked", text: "Pick up this weekend")
    expect(page).to have_no_css(".kuu-market-card")
  end
end
