# frozen_string_literal: true

module DiscourseKuuMarket
  # 按二手帖的状态关闭 / 打开回复、隐藏 / 公开话题，不留「此话题已关闭」之类的系统小帖。
  # core 的 TopicStatusUpdater 一定会发小帖，所以这里照着它补做连带的数据更新。
  # 插件只打开自己关的、只公开自己隐藏的：管理员手动处理过的话题保持原样。
  # 移出二手市场的帖子状态不再生效，插件做过的关闭和隐藏都撤销；移回来时按状态重新生效。
  # 只改数据库；改了 listing 上的标记，由调用方保存。通知浏览器刷新也由调用方在事务外做
  class Listing::Action::SyncTopic < Service::ActionBase
    option :listing

    delegate :topic, to: :listing, private: true

    def call
      sync_replies
      sync_visibility
    end

    private

    def sync_replies
      if listing.in_market? && listing.closes_replies?
        return if topic.closed

        close_replies(true)
        listing.closed_by_plugin = true
      elsif listing.closed_by_plugin
        close_replies(false) if topic.closed
        listing.closed_by_plugin = false
      end
    end

    def sync_visibility
      if !listing.in_market? || listing.active?
        return if !listing.unlisted_by_plugin

        make_visible(true) if !topic.visible
        listing.unlisted_by_plugin = false
      elsif topic.visible
        make_visible(false)
        listing.unlisted_by_plugin = true
      end
    end

    def close_replies(closed)
      topic.update_columns(closed:)
      CategoryFeaturedTopic.where(topic_id: topic.id).delete_all if closed
    end

    def make_visible(visible)
      topic.update_columns(visible:, visibility_reason_id: Topic.visibility_reasons[:unknown])
      topic.update_category_topic_count_by(visible ? 1 : -1)
      UserStatCountUpdater.public_send(visible ? :increment! : :decrement!, topic.first_post)
      return if visible

      UserProfile.remove_featured_topic_from_all_profiles(topic)
      CategoryFeaturedTopic.where(topic_id: topic.id).delete_all
      TopicHotScore.where(topic_id: topic.id).delete_all
    end
  end
end
