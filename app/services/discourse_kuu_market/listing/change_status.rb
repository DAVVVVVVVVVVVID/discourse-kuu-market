# frozen_string_literal: true

module DiscourseKuuMarket
  # 作者或管理员切换二手帖的状态。改回进行中时 30 天过期重新计时，并顶回「最新」
  # （每个帖子在 kuu_market_bump_interval_days 内最多顶一次，超过频率时状态照改、不顶帖）
  class Listing::ChangeStatus
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :status, :string

      validates :topic_id, presence: true
      validates :status, inclusion: { in: Listing.statuses.keys - %w[expired] }
    end

    model :listing
    policy :listing_in_market
    policy :can_change_status, class_name: Listing::Policy::CanManage
    policy :status_reachable

    transaction do
      step :change_status
      step :sync_topic
      only_if(:bump_due) { step :bump_topic }
      step :save_listing
    end

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

    def change_status(listing:, params:)
      listing.change_status(params.status)
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
