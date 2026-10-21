# frozen_string_literal: true

RSpec.describe Jobs::KuuMarketMessageDismissedHands do
  # 发私聊都用普通用户测：管理员会跳过 chat 的不少权限检查
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:waiting) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:also_waiting) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:market, :category)
  fab!(:topic) { Fabricate(:topic, user: author, category: market) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }
  fab!(:listing) { Fabricate(:kuu_market_buy_listing, topic:, status: "closed") }

  before do
    SiteSetting.default_locale = "zh_CN"
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def run_job
    described_class.new.execute(topic_id: topic.id, user_ids: [waiting.id, also_waiting.id])
  end

  def messages_with(user)
    channel = Chat::DirectMessage.for_user_ids([author.id, user.id])&.direct_message_channel
    channel ? channel.chat_messages.to_a : []
  end

  it "messages each of them as the author" do
    run_job

    [waiting, also_waiting].each do |user|
      message = messages_with(user).sole
      expect(message.user).to eq(author)
      expect(message.message).to eq(<<~MD.strip)
        [【求购】自行车 · ¥5,000–10,000](#{topic.url})
        抱歉，已经收到东西啦
      MD
    end
  end

  it "still messages the others when one of them does not accept direct messages" do
    waiting.user_option.update!(allow_private_messages: false)

    run_job

    expect(messages_with(waiting)).to be_empty
    expect(messages_with(also_waiting).size).to eq(1)
  end

  it "does nothing once the topic is gone" do
    topic.destroy!

    expect { run_job }.not_to change { Chat::Message.count }
  end
end
