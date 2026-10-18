# frozen_string_literal: true

module DiscourseKuuMarket
  # 二手帖被移出二手市场时撤销插件做过的关闭和隐藏，移回来时按状态重新关闭 / 隐藏。
  # 在 core 改分类的事务里运行；改分类本身会通知浏览器刷新
  class Listing::FollowCategoryChange
    include Service::Base

    params do
      attribute :topic_id, :integer

      validates :topic_id, presence: true
    end

    model :listing

    transaction do
      step :sync_topic
      step :save_listing
    end

    private

    def fetch_listing(params:)
      Listing.includes(topic: :first_post).find_by(topic_id: params.topic_id)
    end

    def sync_topic(listing:)
      Listing::Action::SyncTopic.call(listing:)
    end

    def save_listing(listing:)
      listing.save!
    end
  end
end
