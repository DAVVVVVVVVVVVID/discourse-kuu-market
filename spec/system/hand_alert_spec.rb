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

  let(:alert) { ".dialog-container.kuu-market-hand-alert" }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def line(kind, count, item)
    I18n.t("js.kuu_market.hand_alert.line.#{kind}", count:, item:)
  end

  it "shows new hands on all listings in one dialog, once" do
    desk.raised_hands.create!(user: buyer)
    desk.raised_hands.create!(user: late_buyer)
    bike.raised_hands.create!(user: buyer)
    sign_in(seller)

    visit("/")

    expect(page).to have_css("#{alert} .dialog-body", text: line("sell", 2, "宜家书桌"))
    expect(page).to have_css("#{alert} .dialog-body", text: line("buy", 1, "自行车"))
    expect(page).to have_css(
      "#{alert} .dialog-footer .btn-primary",
      text: I18n.t("js.kuu_market.hands.open_chat"),
    )
    expect(page).to have_css(
      "#{alert} .dialog-footer .btn-default",
      text: I18n.t("js.kuu_market.hands.keep_browsing"),
    )

    dialog.click_no
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

    expect(page).to have_css("#{alert} .dialog-body", text: line("sell", 1, "宜家书桌"))
  end

  it "shows item names as typed, not as HTML" do
    desk.update!(item_name: "<b>书桌</b>")
    desk.raised_hands.create!(user: buyer)
    sign_in(seller)

    visit("/")

    expect(page).to have_css("#{alert} .dialog-body", text: "<b>书桌</b>")
    expect(page).to have_no_css("#{alert} .dialog-body b")
  end

  it "opens the conversation when only one person raised their hand" do
    channel = Fabricate(:direct_message_channel, users: [seller, buyer])
    desk.raised_hands.create!(user: buyer)
    bike.raised_hands.create!(user: buyer)
    sign_in(seller)

    visit("/")
    dialog.click_yes

    # 电脑上聊天在右下角的抽屉里打开
    expect(page).to have_css(".chat-drawer-container .chat-channel[data-id='#{channel.id}']")
    expect(page).to have_no_css(alert)
  end

  it "opens direct messages when several people raised their hand" do
    desk.raised_hands.create!(user: buyer)
    desk.raised_hands.create!(user: late_buyer)
    sign_in(seller)

    visit("/")
    dialog.click_yes

    expect(page).to have_css(".chat-drawer-container")
    expect(page).to have_no_css(".chat-drawer-container .chat-channel")
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
