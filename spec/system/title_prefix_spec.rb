# frozen_string_literal: true

RSpec.describe "Coloured prefix at the start of listing titles" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:viewer) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "Market") }
  fab!(:regular_topic) { Fabricate(:topic_with_op, title: "【出售】looks like a listing but is not") }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.default_locale = "zh_CN"
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

  def list_title(topic)
    find(".topic-list-item[data-topic-id='#{topic.id}'] a.title")
  end

  it "colours 【出售】【赠送】 green and 【求购】 blue in the topic list" do
    sell = post_listing(item_name: "Desk", price: 3000)
    free = post_listing(item_name: "Rice cooker", free: true)
    buy =
      post_listing(
        kind: "buy",
        item_name: "Bicycle",
        budget_max: 10_000,
        trade_method: nil,
        upload_ids: [],
      )
    sign_in(viewer)

    visit("/latest")

    expect(list_title(sell)).to have_css(".kuu-market-title-prefix--sell", exact_text: "【出售】")
    expect(list_title(free)).to have_css(".kuu-market-title-prefix--sell", exact_text: "【赠送】")
    expect(list_title(buy)).to have_css(".kuu-market-title-prefix--buy", exact_text: "【求购】")
    expect(list_title(sell)).to have_text("【出售】Desk · ¥3,000")
    expect(list_title(sell)).to match_css(".raw-topic-link")

    prefix = list_title(sell).find(".kuu-market-title-prefix")
    expect(prefix.evaluate_script("getComputedStyle(this).color")).to eq("rgb(30, 123, 60)")
  end

  it "leaves other topics alone, even with a similar title" do
    post_listing(item_name: "Desk", price: 3000)
    sign_in(viewer)

    visit("/latest")

    expect(list_title(regular_topic)).to have_text("【出售】looks like a listing but is not")
    expect(list_title(regular_topic)).to have_no_css(".kuu-market-title-prefix")
  end

  it "shows a listing renamed by staff as it is" do
    topic = post_listing(item_name: "Desk", price: 3000)
    topic.update_columns(title: "Desk (renamed)", fancy_title: "Desk (renamed)")
    sign_in(viewer)

    visit("/latest")

    expect(list_title(topic)).to have_text("Desk (renamed)")
    expect(list_title(topic)).to have_no_css(".kuu-market-title-prefix")
  end

  it "colours the prefix of the title on the topic page" do
    topic =
      post_listing(
        kind: "buy",
        item_name: "Bicycle",
        budget_max: 10_000,
        trade_method: nil,
        upload_ids: [],
      )
    sign_in(viewer)

    topic_page.visit_topic(topic)

    expect(page).to have_css(
      "#topic-title .fancy-title .kuu-market-title-prefix--buy",
      exact_text: "【求购】",
    )
    expect(page).to have_css("#topic-title .fancy-title", text: "【求购】Bicycle · ¥10,000 以内")
  end
end
