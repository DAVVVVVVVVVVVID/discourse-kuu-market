# frozen_string_literal: true

module DiscourseKuuMarket
  # 以举手人的身份给作者发聊天私聊，走 chat 自己的服务和权限检查。返回：
  # - :sent 发出去了
  # - :poster_unavailable 作者收不到：关了聊天或私聊、拉黑 / 屏蔽了举手人
  # - :failed 其他原因发不出去，比如举手人自己没有私聊权限、关了私聊，或者站点关了聊天
  class Listing::Action::MessagePoster < Service::ActionBase
    option :listing
    option :sender
    option :event

    def call
      return :failed if !SiteSetting.chat_enabled
      return :poster_unavailable if !poster_reachable?

      channel =
        Chat::CreateDirectMessageChannel.call(
          guardian:,
          params: {
            target_usernames: [poster.username],
          },
        )
      return :failed if channel.failure?

      message =
        Chat::CreateMessage.call(
          guardian:,
          params: {
            chat_channel_id: channel.channel.id,
            message: ListingRenderer.new(listing).hand_message(event),
          },
        )
      message.success? ? :sent : :failed
    end

    private

    def poster
      listing.topic.user
    end

    def guardian
      sender.guardian
    end

    def poster_reachable?
      poster.present? && guardian.recipient_can_chat?(poster) &&
        UserCommScreener
          .new(acting_user: sender, target_user_ids: [poster.id])
          .preventing_actor_communication
          .exclude?(poster.id)
    end
  end
end
