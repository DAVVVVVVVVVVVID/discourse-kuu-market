# frozen_string_literal: true

class AddDealToKuuMarketListings < ActiveRecord::Migration[8.1]
  def change
    add_column :kuu_market_listings, :deal_user_id, :integer
    add_column :kuu_market_raised_hands, :ended_at, :datetime

    # 成交或过期时排队结束（ended_at），之后可以重新举手
    remove_index :kuu_market_raised_hands,
                 %i[listing_id user_id],
                 unique: true,
                 where: "cancelled_at IS NULL",
                 name: "index_kuu_market_raised_hands_on_active"
    add_index :kuu_market_raised_hands,
              %i[listing_id user_id],
              unique: true,
              where: "cancelled_at IS NULL AND ended_at IS NULL",
              name: "index_kuu_market_raised_hands_on_active"
  end
end
