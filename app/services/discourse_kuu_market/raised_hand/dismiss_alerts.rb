# frozen_string_literal: true

module DiscourseKuuMarket
  # 发帖人看过举手弹窗：这批举手（id 不超过 up_to_id）以后不再弹
  class RaisedHand::DismissAlerts
    include Service::Base

    params do
      attribute :up_to_id, :integer

      validates :up_to_id, presence: true
    end

    step :mark_alerted

    private

    def mark_alerted(guardian:, params:)
      RaisedHand
        .unalerted_for(guardian.user)
        .where("kuu_market_raised_hands.id <= ?", params.up_to_id)
        .update_all(alerted_at: Time.zone.now)
    end
  end
end
