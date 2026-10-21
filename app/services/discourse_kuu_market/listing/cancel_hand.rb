# frozen_string_literal: true

module DiscourseKuuMarket
  # 取消举手：离开排队，并私聊告诉作者。和举手一样，私聊发不出去时照样取消
  class Listing::CancelHand
    include Service::Base

    params do
      attribute :topic_id, :integer

      validates :topic_id, presence: true
    end

    model :listing
    policy :listing_open
    model :hand
    policy :within_daily_limit, class_name: Listing::Policy::WithinDailyHandLimit
    step :cancel_hand
    step :message_poster
    step :publish_changes

    private

    def fetch_listing(params:)
      Listing.includes(topic: :user).find_by(topic_id: params.topic_id)
    end

    def listing_open(guardian:, listing:)
      !listing.topic_deleted? && listing.in_market? && listing.active? &&
        guardian.can_see?(listing.topic)
    end

    def fetch_hand(guardian:, listing:)
      listing.raised_hands.active.find_by(user: guardian.user)
    end

    def cancel_hand(hand:)
      hand.update!(cancelled_at: Time.zone.now)
    end

    def message_poster(guardian:, listing:)
      context[:delivery] = Listing::Action::MessagePoster.call(
        listing:,
        sender: guardian.user,
        event: :cancelled,
      )
    end

    def publish_changes(listing:)
      Listing::Action::PublishHands.call(listing:)
    end
  end
end
