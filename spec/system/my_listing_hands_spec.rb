# frozen_string_literal: true

RSpec.describe "Raised hands on the my listings page" do
  # 发私聊都用普通用户测：管理员会跳过 chat 的不少权限检查
  fab!(:seller) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:buyers) do
    Fabricate.times(15, :user, trust_level: TrustLevel[0], refresh_auto_groups: true)
  end
  fab!(:market) { Fabricate(:category, name: "Market") }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def listed(item_name)
    topic = Fabricate(:topic, user: seller, category: market)
    Fabricate(:post, topic:, user: seller)
    Fabricate(:kuu_market_listing, topic:, item_name:)
  end

  # 卖家已经在举手提醒里看过这些人，不然打开页面会先弹提醒
  def raise_hands(listing, users)
    users.each_with_index do |user, index|
      listing.raised_hands.create!(
        user:,
        created_at: (users.size - index).minutes.ago,
        alerted_at: Time.zone.now,
      )
    end
  end

  def row(listing)
    ".kuu-market-my-listings__item[data-topic-id='#{listing.topic_id}'] .kuu-market-my-listings__hands-row"
  end

  let!(:fan) { listed("Quiet fan") }
  let!(:desk) { listed("Desk") }
  let!(:lamp) { listed("Lamp") }

  before do
    raise_hands(fan, buyers)
    raise_hands(desk, buyers.first(1))
    sign_in(seller)
  end

  it "shows the queue in one line, with the rest as +N" do
    visit("/u/#{seller.username}/market")

    expect(page).to have_css("#{row(fan)} .kuu-market-my-listings__avatar", count: 12)
    expect(page).to have_css("#{row(fan)} .kuu-market-my-listings__more", text: "+3")
    expect(page).to have_css(
      "#{row(fan)} .kuu-market-my-listings__avatar:first-child[data-user-card='#{buyers.first.username}']",
    )
    expect(page).to have_css("#{row(desk)} .kuu-market-my-listings__avatar", count: 1)
    expect(page).to have_no_css("#{row(desk)} .kuu-market-my-listings__more")
    expect(page).to have_css(row(lamp), text: I18n.t("js.kuu_market.hand_chats.nobody"))
    expect(page).to have_no_css("#{row(lamp)} .kuu-market-my-listings__chats")

    find("#{row(desk)} .kuu-market-my-listings__avatar").click
    expect(page).to have_css(".user-card", text: buyers.first.username)
  end

  it "lists the conversations with the people in the queue and opens one" do
    buyer = buyers.first
    DiscourseKuuMarket::Listing::Action::SendDirectMessage.call(
      sender: buyer,
      recipient: seller,
      message: "Is the desk still here?",
    )
    channel = Chat::DirectMessage.for_user_ids([seller.id, buyer.id]).direct_message_channel

    visit("/u/#{seller.username}/market")
    find("#{row(desk)} .kuu-market-my-listings__chats").click

    expect(page).to have_css(
      ".kuu-market-hand-chats .d-modal__title",
      text: I18n.t("js.kuu_market.hand_chats.title.sell", item: "Desk"),
    )
    expect(page).to have_css(
      ".kuu-market-hand-chats__row.--unread[data-username='#{buyer.username}']",
      text: "Is the desk still here?",
    )
    expect(page).to have_css(".kuu-market-hand-chats__unread", text: "1")

    find(".kuu-market-hand-chats__row[data-username='#{buyer.username}']").click

    expect(page).to have_no_css(".kuu-market-hand-chats")
    expect(page).to have_css(".chat-drawer-container .chat-channel[data-id='#{channel.id}']")
  end

  it "starts a conversation with someone who has none yet" do
    buyer = buyers.second

    visit("/u/#{seller.username}/market")
    find("#{row(fan)} .kuu-market-my-listings__chats").click
    expect(page).to have_css(".kuu-market-hand-chats__row", count: 15)

    find(".kuu-market-hand-chats__row[data-username='#{buyer.username}']").click

    expect(page).to have_css(".chat-drawer-container .chat-channel")
    expect(Chat::DirectMessage.for_user_ids([seller.id, buyer.id])).to be_present
  end

  it "keeps the queue to one line on phones", mobile: true do
    visit("/u/#{seller.username}/market")

    expect(page).to have_css("#{row(fan)} .kuu-market-my-listings__avatar", count: 5)
    expect(page).to have_css("#{row(fan)} .kuu-market-my-listings__more", text: "+10")
    expect(page).to have_css("#{row(fan)} .kuu-market-my-listings__chats")
  end
end
