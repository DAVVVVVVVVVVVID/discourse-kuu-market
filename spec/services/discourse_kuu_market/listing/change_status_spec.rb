# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::Listing::ChangeStatus do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[selling sold buying closed]) }
    it { is_expected.not_to allow_value("expired").for(:status) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:actor) { author }
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, user: author, category:) }
    fab!(:first_post) { Fabricate(:post, topic:, user: author) }
    fab!(:listing) do
      Fabricate(:kuu_market_listing, topic:, active_since: 10.days.ago, last_bumped_at: 10.days.ago)
    end

    let(:params) { { topic_id:, status: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { actor.guardian }
    let(:topic_id) { topic.id }
    let(:status) { "sold" }

    before do
      SiteSetting.kuu_market_enabled = true
      SiteSetting.kuu_market_category = category.id
    end

    context "when the contract is invalid" do
      let(:status) { "expired" }

      it { is_expected.to fail_a_contract }
    end

    context "when the listing is not found" do
      let(:topic_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:listing) }
    end

    context "when the topic was moved out of the market" do
      before { topic.update!(category: Fabricate(:category)) }

      it { is_expected.to fail_a_policy(:listing_in_market) }
    end

    context "when the actor is another user" do
      fab!(:actor) { Fabricate(:user, refresh_auto_groups: true) }

      it { is_expected.to fail_a_policy(:can_change_status) }
    end

    context "when the author is silenced" do
      before { author.update!(silenced_till: 1.day.from_now) }

      it { is_expected.to fail_a_policy(:can_change_status) }
    end

    context "when the actor is anonymous" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:can_change_status) }
    end

    context "when staff changes someone else's listing" do
      fab!(:actor, :moderator)

      it { is_expected.to run_successfully }

      it "changes the status" do
        expect { result }.to change { listing.reload.status }.to("sold")
      end
    end

    context "when the status is the current one" do
      let(:status) { "selling" }

      it { is_expected.to fail_a_policy(:status_reachable) }
    end

    context "when the status belongs to the other kind" do
      let(:status) { "buying" }

      it { is_expected.to fail_a_policy(:status_reachable) }
    end

    context "when marking the listing as sold" do
      before { freeze_time }

      it { is_expected.to run_successfully }

      it "saves the status" do
        expect { result }.to change { listing.reload.status }.from("selling").to("sold")
      end

      it "syncs the topic" do
        expect { result }.to change { topic.reload.slice(:closed, :visible) }.to(
          "closed" => true,
          "visible" => false,
        )
      end

      it "neither bumps the topic nor restarts the expiry clock" do
        expect { result }.not_to change {
          [topic.reload.bumped_at, listing.reload.last_bumped_at, listing.active_since]
        }
      end

      it "tells browsers to reload the topic" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
        expect(messages).to contain_exactly(have_attributes(data: { reload_topic: true }))
      end

      it "does not publish to latest" do
        expect(MessageBus.track_publish("/latest") { result }).to be_empty
      end
    end

    context "when relisting after the bump interval" do
      let(:status) { "selling" }

      before do
        listing.update!(status: "sold")
        freeze_time
      end

      it { is_expected.to run_successfully }

      it "puts the listing back on sale and restarts the expiry clock" do
        result
        expect(listing.reload).to have_attributes(
          status: "selling",
          active_since: eq_time(Time.zone.now),
        )
      end

      it "bumps the topic" do
        result
        expect(topic.reload.bumped_at).to eq_time(Time.zone.now)
        expect(listing.reload.last_bumped_at).to eq_time(Time.zone.now)
      end

      it "publishes the topic to latest" do
        messages = MessageBus.track_publish("/latest") { result }
        expect(messages).to contain_exactly(have_attributes(data: include("topic_id" => topic.id)))
      end
    end

    context "when relisting within the bump interval" do
      let(:status) { "selling" }

      before do
        listing.update!(status: "sold", last_bumped_at: 2.days.ago)
        freeze_time
      end

      it { is_expected.to run_successfully }

      it "puts the listing back on sale and restarts the expiry clock" do
        result
        expect(listing.reload).to have_attributes(
          status: "selling",
          active_since: eq_time(Time.zone.now),
        )
      end

      it "does not bump the topic" do
        expect { result }.not_to change { [topic.reload.bumped_at, listing.reload.last_bumped_at] }
      end

      it "does not publish to latest" do
        expect(MessageBus.track_publish("/latest") { result }).to be_empty
      end
    end

    context "with an expired listing" do
      before do
        listing.update!(status: "expired")
        freeze_time
      end

      context "when relisting it" do
        let(:status) { "selling" }

        it { is_expected.to run_successfully }

        it "puts the listing back on sale and restarts the expiry clock" do
          result
          expect(listing.reload).to have_attributes(
            status: "selling",
            active_since: eq_time(Time.zone.now),
          )
        end
      end

      context "when marking it as sold" do
        it { is_expected.to run_successfully }

        it "saves the status" do
          expect { result }.to change { listing.reload.status }.from("expired").to("sold")
        end
      end
    end

    context "with a buy listing" do
      let(:status) { "closed" }

      before do
        listing.update!(
          kind: "buy",
          status: "buying",
          price: nil,
          budget_max: 10_000,
          trade_method: nil,
          upload_ids: [],
        )
      end

      it { is_expected.to run_successfully }

      it "closes the listing" do
        expect { result }.to change { listing.reload.status }.from("buying").to("closed")
      end
    end

    context "when the listing was posted before campuses and categories existed" do
      before { listing.update_columns(area: nil, categories: []) }

      it { is_expected.to run_successfully }
    end

    context "with people in the queue" do
      fab!(:first_in_line, :user)
      fab!(:second_in_line, :user)
      fab!(:third_in_line, :user)

      let(:params) { { topic_id:, status:, deal_user_id: } }
      let(:deal_user_id) { second_in_line.id }

      before do
        [first_in_line, second_in_line, third_in_line].each_with_index do |user, index|
          listing.raised_hands.create!(user:, created_at: (3 - index).hours.ago)
        end
      end

      context "when marking it as sold to one of them" do
        it { is_expected.to run_successfully }

        it "remembers who bought it" do
          expect { result }.to change { listing.reload.deal_user }.from(nil).to(second_in_line)
        end

        it "ends the queue" do
          result
          expect(listing.raised_hands.active).to be_empty
          expect(listing.raised_hands.pluck(:ended_at)).to all(be_present)
        end

        it "lets the author tell everyone else it was sold" do
          expect_enqueued_with(
            job: Jobs::KuuMarketMessageDismissedHands,
            args: {
              topic_id: topic.id,
              user_ids: [first_in_line.id, third_in_line.id],
            },
          ) { result }
        end
      end

      context "when marking it as sold elsewhere" do
        let(:deal_user_id) { nil }

        it "has no buyer and tells everyone in the queue" do
          expect_enqueued_with(
            job: Jobs::KuuMarketMessageDismissedHands,
            args: {
              topic_id: topic.id,
              user_ids: [first_in_line.id, second_in_line.id, third_in_line.id],
            },
          ) { result }
          expect(listing.reload.deal_user).to be_nil
        end
      end

      context "when the buyer is not in the queue" do
        let(:deal_user_id) { Fabricate(:user).id }

        it { is_expected.to fail_a_policy(:deal_user_in_queue) }
      end

      context "when the buyer lowered their hand" do
        before do
          listing.raised_hands.find_by(user: second_in_line).update!(cancelled_at: 1.minute.ago)
        end

        it { is_expected.to fail_a_policy(:deal_user_in_queue) }
      end

      context "when the buyer does not exist" do
        let(:deal_user_id) { 0 }

        it { is_expected.to fail_a_policy(:deal_user_in_queue) }
      end

      context "when choosing a buyer without ending the listing" do
        let(:status) { "selling" }

        before { listing.update!(status: "sold") }

        it { is_expected.to fail_a_policy(:deal_user_in_queue) }
      end
    end

    context "when relisting a listing that was sold to someone" do
      fab!(:buyer, :user)

      let(:status) { "selling" }

      before { listing.update!(status: "sold", deal_user: buyer) }

      it "forgets the buyer" do
        expect { result }.to change { listing.reload.deal_user }.from(buyer).to(nil)
      end

      it "does not message anyone" do
        expect_not_enqueued_with(job: Jobs::KuuMarketMessageDismissedHands) { result }
      end
    end
  end
end
