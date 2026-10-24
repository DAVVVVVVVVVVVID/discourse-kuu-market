# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::Listing::RaiseHand do
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
    fab!(:listing) { Fabricate(:kuu_market_listing, topic:) }

    let(:params) { { topic_id: } }
    let(:dependencies) { { guardian: actor.guardian } }
    let(:topic_id) { topic.id }

    before do
      SiteSetting.kuu_market_enabled = true
      SiteSetting.kuu_market_category = category.id
      SiteSetting.chat_enabled = true
      SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
    end

    context "when the listing is not found" do
      let(:topic_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:listing) }
    end

    context "when the actor is the author" do
      fab!(:actor) { author }

      it { is_expected.to fail_a_policy(:can_raise_hand) }
    end

    context "when the actor is silenced" do
      before { actor.update!(silenced_till: 1.day.from_now) }

      it { is_expected.to fail_a_policy(:can_raise_hand) }
    end

    context "when the listing is sold" do
      before { listing.update!(status: "sold") }

      it { is_expected.to fail_a_policy(:can_raise_hand) }
    end

    context "when the listing expired" do
      before { listing.update!(status: "expired") }

      it { is_expected.to fail_a_policy(:can_raise_hand) }
    end

    context "when the buy listing is closed" do
      before { listing.update_columns(kind: "buy", status: "closed") }

      it { is_expected.to fail_a_policy(:can_raise_hand) }
    end

    context "when the topic was moved out of the market" do
      before { topic.update!(category: Fabricate(:category)) }

      it { is_expected.to fail_a_policy(:can_raise_hand) }
    end

    context "when the topic is deleted" do
      before { topic.trash! }

      it { is_expected.to fail_a_policy(:can_raise_hand) }
    end

    context "when the actor cannot see the topic" do
      before { category.set_permissions(staff: :full).tap { category.save! } }

      it { is_expected.to fail_a_policy(:can_raise_hand) }
    end

    context "when the hand is already raised" do
      before { listing.raised_hands.create!(user: actor) }

      it { is_expected.to fail_a_policy(:hand_not_raised) }
    end

    # 次数按日本时间每天 0 点清零（Issue #17）。时间固定在日本时间下午三点，免得测试跑在半夜时跨天
    context "with earlier raises and cancellations" do
      let(:tokyo) { ActiveSupport::TimeZone["Asia/Tokyo"] }

      before { freeze_time(tokyo.parse("2026-10-24 15:00")) }

      context "when the actor raised or lowered their hand three times today" do
        before do
          # 举手在昨天、取消在今天：只算取消这一次
          listing.raised_hands.create!(
            user: actor,
            created_at: tokyo.parse("2026-10-23 20:00"),
            cancelled_at: tokyo.parse("2026-10-24 09:00"),
          )
          listing.raised_hands.create!(
            user: actor,
            created_at: tokyo.parse("2026-10-24 10:00"),
            cancelled_at: tokyo.parse("2026-10-24 11:00"),
          )
        end

        it { is_expected.to fail_a_policy(:within_daily_limit) }

        it "still stops them just before midnight Japan time" do
          freeze_time(tokyo.parse("2026-10-24 23:59"))
          expect(result).to fail_a_policy(:within_daily_limit)
        end

        it "lets them again from midnight Japan time" do
          freeze_time(tokyo.parse("2026-10-25 00:00"))
          expect(result).to run_successfully
        end

        it "does not count them on another listing" do
          other = Fabricate(:kuu_market_listing, topic: Fabricate(:topic, user: author, category:))
          result = described_class.call(params: { topic_id: other.topic_id }, **dependencies)

          expect(result).to run_successfully
        end
      end

      context "when the earlier actions were yesterday, even if less than a day ago" do
        before do
          2.times do
            listing.raised_hands.create!(
              user: actor,
              created_at: tokyo.parse("2026-10-23 22:00"),
              cancelled_at: tokyo.parse("2026-10-23 23:30"),
            )
          end
        end

        it { is_expected.to run_successfully }
      end
    end

    context "when everything is fine" do
      fab!(:first_in_line, :user)

      before { listing.raised_hands.create!(user: first_in_line, created_at: 1.hour.ago) }

      it { is_expected.to run_successfully }

      it "puts the actor at the end of the queue" do
        result
        expect(listing.raised_hands.queue.map(&:user)).to eq([first_in_line, actor])
      end

      it "messages the author" do
        expect(result[:delivery]).to eq(:sent)
      end

      it "tells people looking at the topic to reload it" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
        expect(messages.map(&:data)).to contain_exactly({ reload_topic: true })
      end
    end

    context "when staff raises their hand on someone else's listing" do
      fab!(:actor, :moderator)

      it { is_expected.to run_successfully }
    end

    context "when the author cannot receive the message" do
      before { author.user_option.update!(allow_private_messages: false) }

      it "still raises the hand" do
        expect { result }.to change { listing.raised_hands.active.count }.by(1)
        expect(result[:delivery]).to eq(:poster_unavailable)
      end
    end

    context "when their earlier place ended because the listing was sold and relisted" do
      before do
        listing.raised_hands.create!(user: actor, created_at: 2.hours.ago, ended_at: 1.hour.ago)
      end

      it { is_expected.to run_successfully }
    end

    context "when the actor raised and lowered their hand before" do
      before do
        listing.raised_hands.create!(user: actor, created_at: 2.days.ago, cancelled_at: 2.days.ago)
      end

      it "raises it again as a new place in the queue" do
        expect { result }.to change { listing.raised_hands.count }.by(1)
      end
    end
  end
end
