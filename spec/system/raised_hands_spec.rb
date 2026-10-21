# frozen_string_literal: true

RSpec.describe "Raising a hand on a listing" do
  # 发私聊的功能都用普通用户测：管理员会跳过 chat 的不少权限检查
  fab!(:seller) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:buyer) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "Market") }
  fab!(:listing) do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    topic = Fabricate(:topic, user: seller, category: market)
    Fabricate(:post, topic:, user: seller)
    Fabricate(:kuu_market_listing, topic:)
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def direct_messages
    Chat::DirectMessage
      .for_user_ids([seller.id, buyer.id])
      &.direct_message_channel
      &.chat_messages
      .to_a
  end

  def queue_avatar(user)
    ".kuu-market-hands__avatar[data-user-card='#{user.username}']"
  end

  it "lets a buyer raise their hand, messaging the seller, and lower it again" do
    sign_in(buyer)
    topic_page.visit_topic(listing.topic)

    find(".kuu-market-hands__raise").click

    expect(dialog).to have_content(I18n.t("js.kuu_market.hands.sent.raised.sell"))
    expect(page).to have_css(
      ".kuu-market-hand-dialog .dialog-footer .btn-primary",
      text: I18n.t("js.kuu_market.hands.open_chat"),
    )
    dialog.click_no
    expect(dialog).to be_closed
    expect(page).to have_css(".kuu-market-hands__raised")
    expect(page).to have_css(queue_avatar(buyer))
    expect(direct_messages.map(&:user)).to eq([buyer])

    find(".kuu-market-hands__cancel").click
    dialog.click_yes

    expect(toasts).to have_success(I18n.t("js.kuu_market.hands.sent.cancelled.sell"))
    expect(page).to have_css(".kuu-market-hands__raise")
    expect(page).to have_no_css(queue_avatar(buyer))
    expect(direct_messages.size).to eq(2)
  end

  it "opens the conversation with the seller from the dialog" do
    sign_in(buyer)
    topic_page.visit_topic(listing.topic)

    find(".kuu-market-hands__raise").click
    dialog.click_yes

    channel = Chat::DirectMessage.for_user_ids([seller.id, buyer.id]).direct_message_channel
    # 电脑上聊天在右下角的抽屉里打开
    expect(page).to have_css(".chat-drawer-container .chat-channel[data-id='#{channel.id}']")
  end

  it "opens the conversation full screen on phones", mobile: true do
    sign_in(buyer)
    topic_page.visit_topic(listing.topic)

    find(".kuu-market-hands__raise").click
    dialog.click_yes

    channel = Chat::DirectMessage.for_user_ids([seller.id, buyer.id]).direct_message_channel
    expect(page).to have_current_path(%r{\A/chat/c/[^/]+/#{channel.id}})
    expect(page).to have_css(".chat-channel[data-id='#{channel.id}']")
  end

  it "says so when the seller does not accept direct messages, without offering to open them" do
    seller.user_option.update!(allow_private_messages: false)
    sign_in(buyer)
    topic_page.visit_topic(listing.topic)

    find(".kuu-market-hands__raise").click

    expect(dialog).to have_content(I18n.t("js.kuu_market.hands.poster_unavailable.raised.sell"))
    expect(page).to have_css(".kuu-market-hand-dialog .dialog-footer .btn", count: 1)
    expect(page).to have_css(
      ".kuu-market-hand-dialog .dialog-footer .btn",
      text: I18n.t("js.kuu_market.hands.keep_browsing"),
    )
    dialog.click_ok
    expect(dialog).to be_closed
    expect(page).to have_css(queue_avatar(buyer))
  end

  it "stops a buyer who keeps raising and lowering their hand" do
    listing.raised_hands.create!(user: buyer, created_at: 2.hours.ago, cancelled_at: 1.hour.ago)
    listing.raised_hands.create!(user: buyer, created_at: 30.minutes.ago)
    sign_in(buyer)
    topic_page.visit_topic(listing.topic)

    find(".kuu-market-hands__cancel").click
    dialog.click_yes

    expect(dialog).to have_content(I18n.t("kuu_market.errors.too_many_hand_actions"))
    expect(listing.raised_hands.active.count).to eq(1)
  end

  it "uses the buy wording on buy listings" do
    listing.update!(
      kind: "buy",
      status: "buying",
      price: nil,
      budget_max: 10_000,
      trade_method: nil,
      upload_ids: [],
    )
    sign_in(buyer)
    topic_page.visit_topic(listing.topic)

    expect(page).to have_css(
      ".kuu-market-hands__raise",
      text: I18n.t("js.kuu_market.hands.raise.buy"),
    )
  end

  it "shows the seller the queue without a button" do
    listing.raised_hands.create!(user: buyer)
    sign_in(seller)
    topic_page.visit_topic(listing.topic)

    expect(page).to have_css(queue_avatar(buyer))
    expect(page).to have_no_css(".kuu-market-hands__raise")
  end

  it "shows the first avatars and the rest in a menu" do
    users = Fabricate.times(10, :user)
    users.each_with_index do |user, index|
      listing.raised_hands.create!(user:, created_at: (10 - index).minutes.ago)
    end
    sign_in(buyer)
    topic_page.visit_topic(listing.topic)

    expect(page).to have_css(".kuu-market-hands__avatar", count: 8)
    expect(page).to have_css(queue_avatar(users.first))

    find(".kuu-market-hands__more").click

    expect(page).to have_css(".kuu-market-hands__list li", count: 10)
  end

  it "sends anonymous visitors to log in" do
    listing.raised_hands.create!(user: buyer)
    topic_page.visit_topic(listing.topic)

    expect(page).to have_css(queue_avatar(buyer))

    find(".kuu-market-hands__raise").click

    expect(page).to have_css("#login-account-name")
  end

  it "does not offer raising a hand on a sold listing" do
    listing.update!(status: "sold")
    sign_in(buyer)
    topic_page.visit_topic(listing.topic)

    expect(page).to have_css(".kuu-market-panel__status.kuu-market-status-sold")
    expect(page).to have_no_css(".kuu-market-hands")
  end
end
