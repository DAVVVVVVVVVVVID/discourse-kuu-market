# frozen_string_literal: true

module DiscourseKuuMarket
  # 作者本人和管理员可以随时修改二手帖、切换状态，不受编辑时限限制；作者被禁言时不行
  class Listing::Policy::CanManage < Service::PolicyBase
    delegate :listing, to: :context, private: true

    def call
      topic = listing.topic
      return false if guardian.anonymous? || topic.trashed? || !guardian.can_see?(topic)
      return true if guardian.is_staff?

      topic.user_id == guardian.user.id && !guardian.user.silenced?
    end

    def reason
      I18n.t("kuu_market.errors.cannot_manage")
    end
  end
end
