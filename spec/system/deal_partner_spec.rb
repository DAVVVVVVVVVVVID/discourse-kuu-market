# frozen_string_literal: true

RSpec.describe "Choosing who a listing was sold to" do
  # 发私聊都用普通用户测：管理员会跳过 chat 的不少权限检查
  fab!(:seller) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:buyer) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:other) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
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

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
    Jobs.run_immediately!
  end

  def raise_hands
    listing.raised_hands.create!(user: other, created_at: 2.hours.ago)
    listing.raised_hands.create!(user: buyer, created_at: 1.hour.ago)
  end

  def mark_as_sold
    find(".kuu-market-panel__change[data-status='sold']").click
  end

  def messages_from_seller_to(user)
    Chat::DirectMessage
      .for_user_ids([seller.id, user.id])
      &.direct_message_channel
      &.chat_messages
      &.where(user: seller)
      .to_a
  end

  it "lets the seller pick the buyer, telling everyone else it was sold" do
    raise_hands
    sign_in(seller)
    topic_page.visit_topic(listing.topic)

    mark_as_sold
    expect(page).to have_css(".kuu-market-deal-modal .kuu-market-deal-form__user", count: 2)
    find(".kuu-market-deal-form input[type='radio'][value='#{buyer.id}']").click
    find(".kuu-market-deal-form__confirm").click

    expect(page).to have_css(".kuu-market-panel__status.kuu-market-status-sold")
    expect(page).to have_css(".kuu-market-panel__deal-user[data-user-card='#{buyer.username}']")
    expect(listing.reload).to have_attributes(status: "sold", deal_user: buyer)
    expect(messages_from_seller_to(other).map(&:message)).to contain_exactly(
      end_with(I18n.t("kuu_market.listing.hand_messages.dealt.sell")),
    )
    expect(messages_from_seller_to(buyer)).to be_blank
  end

  it "makes the seller choose explicitly" do
    raise_hands
    sign_in(seller)
    topic_page.visit_topic(listing.topic)

    mark_as_sold
    find(".kuu-market-deal-form__confirm").click

    expect(page).to have_css(".kuu-market-deal-modal .form-kit__errors")
    expect(listing.reload.status).to eq("selling")
  end

  it "lets the seller say it was sold elsewhere" do
    raise_hands
    sign_in(seller)
    topic_page.visit_topic(listing.topic)

    mark_as_sold
    find(".kuu-market-deal-form input[type='radio'][value='none']").click
    find(".kuu-market-deal-form__confirm").click

    expect(page).to have_css(".kuu-market-panel__status.kuu-market-status-sold")
    expect(page).to have_no_css(".kuu-market-panel__deal")
    expect(listing.reload).to have_attributes(status: "sold", deal_user: nil)
    expect(messages_from_seller_to(buyer).size).to eq(1)
  end

  it "only asks for confirmation when nobody raised their hand" do
    sign_in(seller)
    topic_page.visit_topic(listing.topic)

    mark_as_sold
    dialog.click_yes

    expect(page).to have_css(".kuu-market-panel__status.kuu-market-status-sold")
    expect(page).to have_no_css(".kuu-market-deal-modal")
  end

  it "shows everyone the buyer, and the listing on the seller's profile" do
    SiteSetting.hide_new_user_profiles = false
    listing.raised_hands.create!(user: buyer)
    DiscourseKuuMarket::Listing::ChangeStatus.call(
      params: {
        topic_id: listing.topic_id,
        status: "sold",
        deal_user_id: buyer.id,
      },
      guardian: seller.guardian,
    )
    sign_in(other)

    topic_page.visit_topic(listing.topic)
    expect(page).to have_css(".kuu-market-panel__deal-user[data-user-card='#{buyer.username}']")
    expect(page).to have_no_css(".kuu-market-hands")

    visit("/u/#{seller.username}/activity/topics")
    expect(page).to have_css(".kuu-market-card .kuu-market-card__status.kuu-market-status-sold")
    expect(page).to have_no_css(".kuu-market-card.--expired")
  end
end
