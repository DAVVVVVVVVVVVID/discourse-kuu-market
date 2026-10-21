# frozen_string_literal: true

RSpec.describe "Alerting the seller about raised hands" do
  fab!(:seller) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:buyer) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:late_buyer) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "Market") }
  fab!(:desk) do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    Fabricate(:kuu_market_listing, topic: Fabricate(:topic, user: seller, category: market))
  end
  fab!(:bike) do
    Fabricate(:kuu_market_buy_listing, topic: Fabricate(:topic, user: seller, category: market))
  end

  let(:alert) { ".kuu-market-hand-alert" }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def line(kind, count, item)
    I18n.t("js.kuu_market.hand_alert.line.#{kind}", count:, item:)
  end

  it "shows new hands on all listings in one alert, once" do
    desk.raised_hands.create!(user: buyer)
    desk.raised_hands.create!(user: late_buyer)
    bike.raised_hands.create!(user: buyer)
    sign_in(seller)

    visit("/")

    expect(page).to have_css(alert)
    expect(page).to have_css("#{alert} li", count: 2)
    expect(page).to have_css("#{alert} li", text: line("sell", 2, "宜家书桌"))
    expect(page).to have_css("#{alert} li", text: line("buy", 1, "自行车"))

    find(".kuu-market-hand-alert__close").click
    expect(page).to have_no_css(alert)

    try_until_success { expect(desk.raised_hands.where(alerted_at: nil)).to be_empty }
    visit("/latest")
    expect(page).to have_css("#main-outlet .topic-list")
    expect(page).to have_no_css(alert)
  end

  it "alerts again about people who raised their hand later" do
    desk.raised_hands.create!(user: buyer, alerted_at: 1.day.ago)
    desk.raised_hands.create!(user: late_buyer)
    sign_in(seller)

    visit("/")

    expect(page).to have_css("#{alert} li", text: line("sell", 1, "宜家书桌"))
  end

  it "opens direct messages" do
    desk.raised_hands.create!(user: buyer)
    sign_in(seller)

    visit("/")
    find(".kuu-market-hand-alert__open-chat").click

    # 电脑上聊天默认在侧边抽屉里打开，网址不变
    expect(page).to have_css(".chat-drawer-container")
    expect(page).to have_no_css(alert)
  end

  it "does not alert people who raised their hand" do
    desk.raised_hands.create!(user: buyer)
    sign_in(buyer)

    visit("/latest")

    expect(page).to have_css("#main-outlet .topic-list")
    expect(page).to have_no_css(alert)
  end
end
