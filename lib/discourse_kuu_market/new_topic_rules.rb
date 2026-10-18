# frozen_string_literal: true

module DiscourseKuuMarket
  # 二手市场的新话题只能用插件的表单发（表单接口会带上 LISTING_ARG）。
  # 网页编辑器、API、邮件发帖都经过 NewPostManager，在这里拦下；管理员照常能用普通编辑器
  module NewTopicRules
    LISTING_ARG = :kuu_market_listing

    def self.check(manager)
      return if !SiteSetting.kuu_market_enabled

      args = manager.args
      return if args[:topic_id].present? || args[LISTING_ARG].present?
      return if manager.user.staff?
      return if !DiscourseKuuMarket.market_category?(args[:category])

      result = NewPostResult.new(:created_post, false)
      result.errors.add(:base, I18n.t("kuu_market.errors.use_market_form"))
      result
    end
  end
end
