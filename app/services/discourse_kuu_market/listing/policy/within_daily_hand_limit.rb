# frozen_string_literal: true

module DiscourseKuuMarket
  # 每次举手、取消都会给作者发私聊，所以同一个帖子每人 24 小时内合计只能做几次
  class Listing::Policy::WithinDailyHandLimit < Service::PolicyBase
    delegate :listing, to: :context, private: true

    def call
      RaisedHand.actions_since(listing:, user: guardian.user, since: 1.day.ago) <
        SiteSetting.kuu_market_hand_actions_per_day
    end

    def reason
      I18n.t("kuu_market.errors.too_many_hand_actions")
    end
  end
end
