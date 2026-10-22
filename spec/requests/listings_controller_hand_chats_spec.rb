# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::ListingsController do
  # 发私聊都用普通用户测：管理员会跳过 chat 的不少权限检查
  fab!(:seller) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:first_buyer) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:second_buyer) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:moderator)
  fab!(:market, :category)
  fab!(:listing) do
    Fabricate(:kuu_market_listing, topic: Fabricate(:topic, user: seller, category: market))
  end

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def message(from, to, text)
    DiscourseKuuMarket::Listing::Action::SendDirectMessage.call(
      sender: from,
      recipient: to,
      message: text,
    )
  end

  def hand_chats
    get "/kuu-market/listings/#{listing.topic_id}/hand-chats.json"
    response.parsed_body["hands"]
  end

  def channel_between(user, other)
    Chat::DirectMessage.for_user_ids([user.id, other.id]).direct_message_channel
  end

  before do
    listing.raised_hands.create!(user: first_buyer, created_at: 2.hours.ago)
    listing.raised_hands.create!(user: second_buyer, created_at: 1.hour.ago)
    message(first_buyer, seller, "Is the fan still available?")
  end

  context "when the seller looks" do
    before { sign_in(seller) }

    it "lists the people in the queue with their last message and unread count" do
      hands = hand_chats

      expect(hands.map { it["user"]["username"] }).to eq(
        [first_buyer.username, second_buyer.username],
      )
      expect(hands.first).to include(
        "chat_channel_id" => channel_between(seller, first_buyer).id,
        "unread_count" => 1,
        "last_message" => include("excerpt" => "Is the fan still available?", "mine" => false),
      )
      expect(hands.first["raised_at"]).to be_present
      expect(hands.second).to include("chat_channel_id" => nil, "last_message" => nil)
    end

    it "shows the seller's own reply as the last message" do
      message(seller, first_buyer, "Yes, come by tomorrow")

      expect(hand_chats.first).to include(
        "unread_count" => 0,
        "last_message" => include("excerpt" => "Yes, come by tomorrow", "mine" => true),
      )
    end

    it "leaves out people who lowered their hand or whose place ended" do
      listing.raised_hands.find_by(user: second_buyer).update!(cancelled_at: Time.zone.now)

      expect(hand_chats.map { it["user"]["username"] }).to eq([first_buyer.username])
    end
  end

  it "shows staff who is in the queue, but not the seller's messages" do
    sign_in(moderator)

    hands = hand_chats

    expect(hands.size).to eq(2)
    expect(hands.first).to include(
      "chat_channel_id" => nil,
      "last_message" => nil,
      "unread_count" => nil,
    )
  end

  it "is not found for other people" do
    sign_in(first_buyer)

    get "/kuu-market/listings/#{listing.topic_id}/hand-chats.json"

    expect(response.status).to eq(404)
  end
end
