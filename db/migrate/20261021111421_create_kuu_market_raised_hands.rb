# frozen_string_literal: true

class CreateKuuMarketRaisedHands < ActiveRecord::Migration[8.1]
  def change
    create_table :kuu_market_raised_hands do |t|
      t.bigint :listing_id, null: false
      t.integer :user_id, null: false
      t.datetime :cancelled_at
      t.timestamps
    end

    add_index :kuu_market_raised_hands, %i[listing_id user_id]
    add_index :kuu_market_raised_hands,
              %i[listing_id user_id],
              unique: true,
              where: "cancelled_at IS NULL",
              name: "index_kuu_market_raised_hands_on_active"
  end
end
