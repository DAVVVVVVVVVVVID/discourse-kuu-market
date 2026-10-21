# frozen_string_literal: true

module DiscourseKuuMarket
  # 作者或管理员切换二手帖的状态。改回进行中时 30 天过期重新计时，并顶回「最新」
  # （每个帖子在 kuu_market_bump_interval_days 内最多顶一次，超过频率时状态照改、不顶帖）。
  # 标记已出 / 已购买时可以从举手的人里选成交对象（不选 = 在其他渠道成交），排队结束，
  # 其他举手人由作者私聊告知（Issue #5 第三期）
  class Listing::ChangeStatus
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :status, :string
      attribute :deal_user_id, :integer

      validates :topic_id, presence: true
      validates :status, inclusion: { in: Listing.statuses.keys - %w[expired] }
    end

    model :listing
    policy :listing_in_market
    policy :can_change_status, class_name: Listing::Policy::CanManage
    policy :status_reachable
    model :deal_user, optional: true
    policy :deal_user_in_queue

    transaction do
      step :change_status
      only_if(:ending) { step :end_queue }
      step :sync_topic
      only_if(:bump_due) { step :bump_topic }
      step :save_listing
    end

    only_if(:dismissed_users_present) { step :message_dismissed_users }
    step :publish_changes

    private

    def fetch_listing(params:)
      Listing.includes(topic: :first_post).find_by(topic_id: params.topic_id)
    end

    def listing_in_market(listing:)
      listing.in_market?
    end

    def status_reachable(listing:, params:)
      listing.can_change_to?(params.status)
    end

    def fetch_deal_user(params:)
      User.find_by(id: params.deal_user_id) if params.deal_user_id
    end

    # 成交对象只能是正在排队的人，而且只在标记已出 / 已购买时选
    def deal_user_in_queue(listing:, params:, deal_user:)
      return params.deal_user_id.nil? if deal_user.nil?

      params.status == Listing.ended_status_for(listing.kind) &&
        listing.raised_hands.active.exists?(user: deal_user)
    end

    def change_status(listing:, params:, deal_user:)
      listing.change_status(params.status, deal_user:)
    end

    def ending(listing:)
      listing.closes_replies?
    end

    def end_queue(listing:)
      context[:dismissed_users] = listing.end_queue
    end

    def dismissed_users_present
      context[:dismissed_users].present?
    end

    def message_dismissed_users(listing:, dismissed_users:)
      Jobs.enqueue(
        Jobs::KuuMarketMessageDismissedHands,
        topic_id: listing.topic_id,
        user_ids: dismissed_users.map(&:id),
      )
    end

    def sync_topic(listing:)
      Listing::Action::SyncTopic.call(listing:)
    end

    def bump_due(listing:)
      listing.relisting? && listing.bump_due?
    end

    def bump_topic(listing:)
      now = Time.zone.now
      listing.topic.update_columns(bumped_at: now)
      listing.last_bumped_at = now
    end

    def save_listing(listing:)
      listing.save!
    end

    def publish_changes(listing:)
      topic = listing.topic
      MessageBus.publish(
        "/topic/#{topic.id}",
        { reload_topic: true },
        topic.secure_audience_publish_messages,
      )
      TopicTrackingState.publish_latest(topic) if listing.saved_change_to_last_bumped_at?
    end
  end
end
