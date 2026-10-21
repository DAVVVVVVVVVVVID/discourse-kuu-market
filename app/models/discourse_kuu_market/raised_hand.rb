# frozen_string_literal: true

module DiscourseKuuMarket
  # 在售帖上的「举手购买」、求购帖上的「举手售出」。取消后记录保留（cancelled_at），
  # 再举手是新的一条、排到队尾；防刷按这些记录数。成交或过期时排队结束（ended_at），不算进防刷次数
  class RaisedHand < ActiveRecord::Base
    self.table_name = "kuu_market_raised_hands"

    belongs_to :listing
    belongs_to :user

    scope :active, -> { where(cancelled_at: nil, ended_at: nil) }
    scope :queue, -> { active.joins(:user).order(:created_at, :id) }

    # 防刷用：since 之后的举手和取消合计几次
    def self.actions_since(listing:, user:, since:)
      hands = where(listing:, user:)
      hands.where("created_at > ?", since).count + hands.where("cancelled_at > ?", since).count
    end
  end
end

# == Schema Information
#
# Table name: kuu_market_raised_hands
#
#  id           :bigint           not null, primary key
#  cancelled_at :datetime
#  ended_at     :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  listing_id   :bigint           not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_kuu_market_raised_hands_on_active                  (listing_id,user_id) UNIQUE WHERE ((cancelled_at IS NULL) AND (ended_at IS NULL))
#  index_kuu_market_raised_hands_on_listing_id_and_user_id  (listing_id,user_id)
#
