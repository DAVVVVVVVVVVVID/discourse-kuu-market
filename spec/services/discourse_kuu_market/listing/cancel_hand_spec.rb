# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::Listing::CancelHand do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
    fab!(:actor) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, user: author, category:) }
    fab!(:first_post) { Fabricate(:post, topic:, user: author) }
    fab!(:listing) { Fabricate(:kuu_market_buy_listing, topic:) }
    fab!(:hand) { listing.raised_hands.create!(user: actor, created_at: 2.hours.ago) }

    let(:params) { { topic_id: } }
    let(:dependencies) { { guardian: actor.guardian } }
    let(:topic_id) { topic.id }

    before do
      SiteSetting.default_locale = "zh_CN"
      SiteSetting.kuu_market_enabled = true
      SiteSetting.kuu_market_category = category.id
      SiteSetting.chat_enabled = true
      SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
    end

    context "when the listing is not found" do
      let(:topic_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:listing) }
    end

    context "when the listing is closed" do
      before { listing.update!(status: "closed") }

      it { is_expected.to fail_a_policy(:listing_open) }
    end

    context "when the topic is deleted" do
      before { topic.trash! }

      it { is_expected.to fail_a_policy(:listing_open) }
    end

    context "when the actor has not raised their hand" do
      before { hand.update!(cancelled_at: 1.hour.ago) }

      it { is_expected.to fail_to_find_a_model(:hand) }
    end

    context "when the actor raised or lowered their hand three times today" do
      let(:tokyo) { ActiveSupport::TimeZone["Asia/Tokyo"] }

      # 时间固定在日本时间下午三点，免得测试跑在半夜时跨天（次数按日本时间 0 点清零，Issue #17）
      before do
        freeze_time(tokyo.parse("2026-10-24 15:00"))
        hand.update!(created_at: tokyo.parse("2026-10-24 13:00"))
        listing.raised_hands.create!(
          user: actor,
          created_at: tokyo.parse("2026-10-24 10:00"),
          cancelled_at: tokyo.parse("2026-10-24 11:00"),
        )
      end

      it { is_expected.to fail_a_policy(:within_daily_limit) }
    end

    context "when everything is fine" do
      it { is_expected.to run_successfully }

      it "takes the actor out of the queue and keeps the record" do
        freeze_time

        result

        expect(listing.raised_hands.active).to be_empty
        expect(hand.reload.cancelled_at).to eq_time(Time.zone.now)
      end

      it "messages the author" do
        expect(result[:delivery]).to eq(:sent)
        message =
          Chat::DirectMessage
            .for_user_ids([author.id, actor.id])
            .direct_message_channel
            .chat_messages
            .sole
        expect(message.message).to end_with("我这边暂时出不了了，取消")
      end
    end
  end
end
