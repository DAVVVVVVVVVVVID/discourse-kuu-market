# frozen_string_literal: true

class AddAreaAndCategoriesToKuuMarketListings < ActiveRecord::Migration[8.1]
  def change
    # 位置范围（校区）和商品分类（Issue #11）。已有的帖子不回填：作者下次修改时表单要求补填
    add_column :kuu_market_listings, :area, :string
    add_column :kuu_market_listings, :categories, :string, array: true, null: false, default: []

    add_index :kuu_market_listings, :area
    add_index :kuu_market_listings, :categories, using: :gin
  end
end
