# frozen_string_literal: true

class CreateKuuMarketListings < ActiveRecord::Migration[8.1]
  def change
    create_table :kuu_market_listings do |t|
      t.integer :topic_id, null: false
      t.string :kind, null: false
      t.string :status, null: false
      t.datetime :active_since, null: false
      t.datetime :last_bumped_at, null: false
      t.boolean :closed_by_plugin, null: false, default: false
      t.boolean :unlisted_by_plugin, null: false, default: false
      t.string :item_name, null: false
      t.integer :price
      t.boolean :free, null: false, default: false
      t.integer :budget_min
      t.integer :budget_max
      t.string :location, null: false
      t.string :trade_method
      t.text :description, null: false, default: ""
      t.integer :upload_ids, array: true, null: false, default: []
      t.timestamps
    end

    add_index :kuu_market_listings, :topic_id, unique: true
    add_index :kuu_market_listings, %i[status active_since]
    add_check_constraint :kuu_market_listings,
                         "(kind = 'sell' AND status IN ('selling', 'sold', 'expired')) OR " \
                           "(kind = 'buy' AND status IN ('buying', 'closed', 'expired'))",
                         name: "kuu_market_listings_kind_status"
  end
end
