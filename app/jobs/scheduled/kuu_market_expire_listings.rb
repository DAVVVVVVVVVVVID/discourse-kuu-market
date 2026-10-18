# frozen_string_literal: true

module Jobs
  class KuuMarketExpireListings < ::Jobs::Scheduled
    every 1.hour

    def execute(_args)
      return if !SiteSetting.kuu_market_enabled

      DiscourseKuuMarket::Listing
        .due_to_expire
        .pluck(:topic_id)
        .each { |topic_id| DiscourseKuuMarket::Listing::Expire.call(params: { topic_id: }) }
    end
  end
end
