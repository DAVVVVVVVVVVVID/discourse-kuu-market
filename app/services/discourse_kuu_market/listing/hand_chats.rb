# frozen_string_literal: true

module DiscourseKuuMarket
  # 「我的商品」页「去私信」弹窗（Issue #15）：这件商品正在排队的举手人，按举手顺序，带上和发帖人的
  # 私聊频道、最后一条消息、发帖人的未读数。私聊内容只给发帖人本人：管理员能看到名单，看不到私聊
  class Listing::HandChats
    include Service::Base

    params do
      attribute :topic_id, :integer

      validates :topic_id, presence: true
    end

    model :listing
    policy :can_manage, class_name: Listing::Policy::CanManage
    model :hands, optional: true
    step :build_rows

    private

    def fetch_listing(params:)
      Listing.includes(topic: :user).find_by(topic_id: params.topic_id)
    end

    def fetch_hands(listing:)
      listing.raised_hands.queue.includes(:user)
    end

    def build_rows(guardian:, listing:, hands:)
      author = listing.topic.user
      channels = guardian.user.id == author&.id ? channels_with(author, hands.map(&:user)) : {}
      unreads =
        if channels.any?
          Chat::ChannelUnreadsQuery
            .call(channel_ids: channels.values.map(&:id), user_id: author.id)
            .to_h { [it.channel_id, it.unread_count] }
        else
          {}
        end

      context[:rows] = hands.map do |hand|
        channel = channels[hand.user_id]
        {
          user: hand.user,
          raised_at: hand.created_at,
          chat_channel_id: channel&.id,
          last_message: channel&.last_message && last_message_of(channel.last_message, author),
          unread_count: channel ? unreads[channel.id].to_i : nil,
        }
      end
    end

    def channels_with(author, users)
      users.each_with_object({}) do |user, channels|
        channel = Chat::DirectMessage.for_user_ids([author.id, user.id])&.direct_message_channel
        channels[user.id] = channel if channel
      end
    end

    def last_message_of(message, author)
      {
        excerpt: message.excerpt_for_display,
        created_at: message.created_at,
        mine: message.user_id == author.id,
      }
    end
  end
end
