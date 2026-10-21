# frozen_string_literal: true

module DiscourseKuuMarket
  # 以 sender 的身份给 recipient 发聊天私聊，走 chat 自己的服务和权限检查。返回：
  # - :sent 发出去了
  # - :recipient_unavailable 对方收不到：关了聊天或私聊、拉黑 / 屏蔽了 sender、只允许特定的人私信
  # - :failed 其他原因发不出去，比如 sender 自己没有私聊权限、关了私聊，或者站点关了聊天
  class Listing::Action::SendDirectMessage < Service::ActionBase
    option :sender
    option :recipient
    option :message

    def call
      return :failed if !SiteSetting.chat_enabled
      return :recipient_unavailable if !recipient_reachable?

      channel =
        Chat::CreateDirectMessageChannel.call(
          guardian:,
          params: {
            target_usernames: [recipient.username],
          },
        )
      return :failed if channel.failure?

      result =
        Chat::CreateMessage.call(
          guardian:,
          params: {
            chat_channel_id: channel.channel.id,
            message:,
          },
        )
      result.success? ? :sent : :failed
    end

    private

    def guardian
      sender.guardian
    end

    def recipient_reachable?
      recipient.present? && guardian.recipient_can_chat?(recipient) &&
        UserCommScreener
          .new(acting_user: sender, target_user_ids: [recipient.id])
          .preventing_actor_communication
          .exclude?(recipient.id)
    end
  end
end
