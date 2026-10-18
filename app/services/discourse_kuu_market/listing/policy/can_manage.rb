# frozen_string_literal: true

module DiscourseKuuMarket
  class Listing::Policy::CanManage < Service::PolicyBase
    delegate :listing, to: :context, private: true

    def call
      guardian.can_manage_kuu_market_listing?(listing)
    end

    def reason
      I18n.t("kuu_market.errors.cannot_manage")
    end
  end
end
