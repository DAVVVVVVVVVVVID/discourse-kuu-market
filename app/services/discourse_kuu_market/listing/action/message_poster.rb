# frozen_string_literal: true

module DiscourseKuuMarket
  # 举手 / 取消时以举手人的身份给作者发聊天私聊。返回 :sent、:poster_unavailable（作者收不到）
  # 或 :failed（其他原因），见 SendDirectMessage
  class Listing::Action::MessagePoster < Service::ActionBase
    option :listing
    option :sender
    option :event

    def call
      delivery =
        Listing::Action::SendDirectMessage.call(
          sender:,
          recipient: listing.topic.user,
          message: ListingRenderer.new(listing).hand_message(event),
        )
      delivery == :recipient_unavailable ? :poster_unavailable : delivery
    end
  end
end
