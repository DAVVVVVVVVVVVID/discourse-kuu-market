# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::Listing::Expire do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, user: author, category:) }
    fab!(:first_post) { Fabricate(:post, topic:, user: author) }
    fab!(:listing) do
      Fabricate(:kuu_market_listing, topic:, active_since: 31.days.ago, last_bumped_at: 31.days.ago)
    end

    let(:params) { { topic_id: } }
    let(:dependencies) { {} }
    let(:topic_id) { topic.id }
    let(:author_notifications) do
      Notification.where(user: author, notification_type: Notification.types[:custom])
    end

    before do
      SiteSetting.kuu_market_enabled = true
      SiteSetting.kuu_market_category = category.id
      SiteSetting.kuu_market_expire_days = 30
    end

    context "when the contract is invalid" do
      let(:topic_id) { nil }

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

    context "when the topic is trashed" do
      before { topic.trash! }

      it { is_expected.to fail_a_policy(:listing_in_market) }
    end

    context "when the listing is not due yet" do
      before { listing.update!(active_since: 29.days.ago) }

      it { is_expected.to fail_a_policy(:expiry_due) }

      it "does not notify the author" do
        expect { result }.not_to change { author_notifications.count }
      end
    end

    context "when the listing is sold" do
      before { listing.update!(status: "sold") }

      it { is_expected.to fail_a_policy(:expiry_due) }
    end

    context "when the listing has already expired" do
      before { listing.update!(status: "expired") }

      it { is_expected.to fail_a_policy(:expiry_due) }
    end

    context "when the author's account no longer exists" do
      before { topic.update_columns(user_id: nil) }

      it { is_expected.to run_successfully }

      it "expires the listing without notifying anyone" do
        expect { result }.not_to change { Notification.count }
        expect(listing.reload.status).to eq("expired")
      end
    end

    context "when a sell listing is due" do
      before { freeze_time }

      it { is_expected.to run_successfully }

      it "expires the listing" do
        expect { result }.to change { listing.reload.status }.from("selling").to("expired")
      end

      it "hides the topic but keeps replies open" do
        expect { result }.to change { topic.reload.slice(:closed, :visible) }.to(
          "closed" => false,
          "visible" => false,
        )
      end

      it "does not restart the expiry clock" do
        expect { result }.not_to change { listing.reload.active_since }
      end

      it "notifies the author once" do
        expect { result }.to change { author_notifications.count }.by(1)
        expect(author_notifications.last).to have_attributes(
          topic_id: topic.id,
          post_number: 1,
          data_hash:
            include(
              message: "kuu_market.notifications.expired",
              topic_title: topic.title,
              kind: "sell",
            ),
        )
      end

      it "tells browsers to reload the topic" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
        expect(messages).to contain_exactly(have_attributes(data: { reload_topic: true }))
      end
    end

    context "with a buy listing" do
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

      it "expires the listing" do
        expect { result }.to change { listing.reload.status }.from("buying").to("expired")
      end

      it "tells the author it was a buy listing" do
        result
        expect(author_notifications.last.data_hash).to include(kind: "buy")
      end
    end

    context "with people in the queue" do
      fab!(:waiting, :user)
      fab!(:lowered, :user)

      before do
        listing.raised_hands.create!(user: waiting)
        listing.raised_hands.create!(user: lowered, cancelled_at: 1.day.ago)
      end

      it "empties the queue" do
        result
        expect(listing.raised_hands.active).to be_empty
      end

      it "tells the people still waiting, with a site notification" do
        result

        notification = Notification.find_by(user: waiting)
        expect(notification).to have_attributes(
          notification_type: Notification.types[:custom],
          topic_id: topic.id,
          post_number: 1,
        )
        expect(notification.data_hash).to include(
          message: "kuu_market.notifications.hand_expired",
          kind: "sell",
        )
        expect(Notification.where(user: lowered)).to be_empty
      end

      it "does not send chat messages" do
        expect { result }.not_to change { Chat::Message.count }
      end
    end
  end
end
