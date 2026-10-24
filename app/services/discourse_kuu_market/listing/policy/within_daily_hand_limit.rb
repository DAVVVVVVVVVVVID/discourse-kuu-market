# frozen_string_literal: true

module DiscourseKuuMarket
  # 每次举手、取消都会给作者发私聊，所以同一个帖子每人每天合计只能做几次。
  # 「每天」按日本时间 0 点清零（2026-10-22 David 定，和鲸币插件的每日任务一致，Issue #17）
  class Listing::Policy::WithinDailyHandLimit < Service::PolicyBase
    TIME_ZONE = "Asia/Tokyo"

    delegate :listing, to: :context, private: true

    def self.day_start(at = Time.zone.now)
      at.in_time_zone(TIME_ZONE).beginning_of_day
    end

    def call
      RaisedHand.actions_since(listing:, user: guardian.user, since: self.class.day_start) <
        SiteSetting.kuu_market_hand_actions_per_day
    end

    def reason
      I18n.t("kuu_market.errors.too_many_hand_actions")
    end
  end
end
