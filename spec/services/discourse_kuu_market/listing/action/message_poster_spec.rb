# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::Listing::Action::MessagePoster do
  subject(:delivery) { described_class.call(listing:, sender:, event:) }

  fab!(:poster) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:sender) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user: poster, category:) }
  fab!(:first_post) { Fabricate(:post, topic:, user: poster) }
  fab!(:listing) { Fabricate(:kuu_market_listing, topic:) }

  let(:event) { :raised }

  def direct_messages
    channel = Chat::DirectMessage.for_user_ids([poster.id, sender.id])&.direct_message_channel
    channel ? channel.chat_messages.order(:id) : Chat::Message.none
  end

  before do
    SiteSetting.default_locale = "zh_CN"
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = category.id
    SiteSetting.chat_enabled = true
    # 和线上一样：信任等级 0 也能发聊天私聊
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  it "sends the author a direct message as the person raising their hand" do
    expect(delivery).to eq(:sent)

    message = direct_messages.sole
    expect(message.user).to eq(sender)
    expect(message.message).to eq(
      DiscourseKuuMarket::ListingRenderer.new(listing).hand_message(:raised),
    )
  end

  it "keeps messages about several listings in the same conversation" do
    other_listing =
      Fabricate(:kuu_market_buy_listing, topic: Fabricate(:topic, user: poster, category:))

    described_class.call(listing:, sender:, event: :raised)
    described_class.call(listing: other_listing, sender:, event: :raised)

    expect(direct_messages.count).to eq(2)
    expect(direct_messages.last.message).to include(other_listing.topic.url)
  end

  context "when lowering a hand" do
    let(:event) { :cancelled }

    it "says so" do
      expect(delivery).to eq(:sent)
      expect(direct_messages.sole.message).to end_with("我暂时不需要了，取消购买请求")
    end
  end

  context "when the author does not allow direct messages" do
    before { poster.user_option.update!(allow_private_messages: false) }

    it "does not send anything" do
      expect(delivery).to eq(:poster_unavailable)
      expect(direct_messages).to be_empty
    end
  end

  context "when the author turned chat off" do
    before { poster.user_option.update!(chat_enabled: false) }

    it { is_expected.to eq(:poster_unavailable) }
  end

  context "when the author ignores the sender" do
    before { Fabricate(:ignored_user, user: poster, ignored_user: sender) }

    it { is_expected.to eq(:poster_unavailable) }
  end

  context "when the author mutes the sender" do
    before { MutedUser.create!(user: poster, muted_user: sender) }

    it { is_expected.to eq(:poster_unavailable) }
  end

  context "when the author only allows direct messages from certain people" do
    before { poster.user_option.update!(enable_allowed_pm_users: true) }

    it { is_expected.to eq(:poster_unavailable) }
  end

  context "when the sender is not allowed to send direct messages" do
    before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_4] }

    it "does not send anything" do
      expect(delivery).to eq(:failed)
      expect(direct_messages).to be_empty
    end
  end

  context "when the sender turned direct messages off" do
    before { sender.user_option.update!(allow_private_messages: false) }

    it { is_expected.to eq(:failed) }
  end

  context "when chat is disabled" do
    before { SiteSetting.chat_enabled = false }

    it { is_expected.to eq(:failed) }
  end
end
