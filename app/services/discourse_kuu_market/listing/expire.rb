# frozen_string_literal: true

module DiscourseKuuMarket
  # 系统把进入在售 / 求购满期限的帖子改成过期：隐藏话题但不关闭回复，并给作者发站内通知
  # （不发邮件，2026-10-18 David 定）。期限从最近一次进入进行中算，别人的回复不重新计时。
  # 举手排队清空，举手人也收到站内通知（2026-10-21 David 定，不用聊天私聊：过期不是作者的操作）
  class Listing::Expire
    include Service::Base

    NOTIFICATION_MESSAGE = "kuu_market.notifications.expired"
    HAND_NOTIFICATION_MESSAGE = "kuu_market.notifications.hand_expired"

    params do
      attribute :topic_id, :integer

      validates :topic_id, presence: true
    end

    model :listing
    policy :listing_in_market
    policy :expiry_due

    transaction do
      step :expire
      step :end_queue
      step :sync_topic
      step :save_listing
    end

    only_if(:author_present) { step :notify_author }
    step :notify_dismissed_users
    step :publish_changes

    private

    def fetch_listing(params:)
      Listing.includes(topic: :first_post).find_by(topic_id: params.topic_id)
    end

    def listing_in_market(listing:)
      listing.in_market? && !listing.topic_deleted?
    end

    def expiry_due(listing:)
      listing.expiry_due?
    end

    def expire(listing:)
      listing.status = "expired"
    end

    def end_queue(listing:)
      context[:dismissed_users] = listing.end_queue
    end

    def sync_topic(listing:)
      Listing::Action::SyncTopic.call(listing:)
    end

    def save_listing(listing:)
      listing.save!
    end

    def author_present(listing:)
      listing.topic.user.present?
    end

    def notify_author(listing:)
      notify(listing, listing.topic.user_id, NOTIFICATION_MESSAGE)
    end

    def notify_dismissed_users(listing:, dismissed_users:)
      dismissed_users.each { |user| notify(listing, user.id, HAND_NOTIFICATION_MESSAGE) }
    end

    def notify(listing, user_id, message)
      topic = listing.topic
      Notification.create!(
        notification_type: Notification.types[:custom],
        user_id:,
        topic_id: topic.id,
        post_number: 1,
        data: { message:, topic_title: topic.title, kind: listing.kind }.to_json,
      )
    end

    def publish_changes(listing:)
      topic = listing.topic
      MessageBus.publish(
        "/topic/#{topic.id}",
        { reload_topic: true },
        topic.secure_audience_publish_messages,
      )
    end
  end
end
