# frozen_string_literal: true

RSpec.describe "Coloured prefix at the start of the topic page title" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:viewer) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "Market") }

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
          area: "yoshida",
          categories: ["furniture_appliances"],
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

  it "keeps the topic page prefix right after the seller edits the listing" do
    topic = post_listing(item_name: "Desk", price: 3000)
    sign_in(seller)
    topic_page.visit_topic(topic)
    expect(page).to have_css("#topic-title .fancy-title .kuu-market-title-prefix--sell")

    find(".kuu-market-panel__edit").click
    PageObjects::Modals::KuuMarketListingForm.new.fill_in("price", "2000").submit

    expect(page).to have_css("#topic-title .fancy-title", text: "【出售】Desk · ¥2,000")
    expect(page).to have_css("#topic-title .fancy-title .kuu-market-title-prefix", count: 1)
    expect(find("#topic-title .fancy-title").text).not_to include("【出售】【出售】")
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
