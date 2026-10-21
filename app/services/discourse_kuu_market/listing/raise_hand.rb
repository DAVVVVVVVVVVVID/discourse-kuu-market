# frozen_string_literal: true

module DiscourseKuuMarket
  # 举手购买（在售帖）/ 举手售出（求购帖）：排进队尾，并以举手人的身份给作者发聊天私聊。
  # 私聊发不出去（作者关了私聊、拉黑了举手人等）时照样记录举手，由 delivery 告诉前端
  class Listing::RaiseHand
    include Service::Base

    params do
      attribute :topic_id, :integer

      validates :topic_id, presence: true
    end

    model :listing
    policy :can_raise_hand
    policy :hand_not_raised
    policy :within_daily_limit, class_name: Listing::Policy::WithinDailyHandLimit
    step :raise_hand
    step :message_poster
    only_if(:message_sent) { step :find_chat_channel }
    step :publish_changes

    private

    def fetch_listing(params:)
      Listing.includes(topic: :user).find_by(topic_id: params.topic_id)
    end

    def can_raise_hand(guardian:, listing:)
      guardian.can_raise_kuu_market_hand?(listing)
    end

    def hand_not_raised(guardian:, listing:)
      !listing.raised_hands.active.exists?(user: guardian.user)
    end

    def raise_hand(guardian:, listing:)
      listing.raised_hands.create!(user: guardian.user)
    end

    def message_poster(guardian:, listing:)
      context[:delivery] = Listing::Action::MessagePoster.call(
        listing:,
        sender: guardian.user,
        event: :raised,
      )
    end

    def message_sent(delivery:)
      delivery == :sent
    end

    # 举手成功后的弹窗里，「去私信」直接打开和发帖人的对话（Issue #9）
    def find_chat_channel(guardian:, listing:)
      context[:chat_channel_id] = DiscourseKuuMarket.direct_message_channel_id(
        guardian.user,
        listing.topic.user,
      )
    end

    def publish_changes(listing:)
      Listing::Action::PublishHands.call(listing:)
    end
  end
end
