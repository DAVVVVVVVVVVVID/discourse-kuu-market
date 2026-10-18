# frozen_string_literal: true

module DiscourseKuuMarket
  # 二手帖：一个插件发的话题对应一条记录。不是插件发的帖子（比如分类的规则帖）没有记录，插件不管
  class Listing < ActiveRecord::Base
    self.table_name = "kuu_market_listings"

    ITEM_NAME_MAX_LENGTH = 40
    LOCATION_MAX_LENGTH = 40
    DESCRIPTION_MAX_LENGTH = 2000
    MAX_YEN = 100_000_000
    BUY_MAX_PHOTOS = 1

    ACTIVE_STATUS = { "sell" => "selling", "buy" => "buying" }.freeze
    ENDED_STATUS = { "sell" => "sold", "buy" => "closed" }.freeze

    enum :kind, { sell: "sell", buy: "buy" }, validate: true
    enum :status,
         {
           selling: "selling",
           sold: "sold",
           buying: "buying",
           closed: "closed",
           expired: "expired",
         },
         validate: true
    enum :trade_method,
         { pickup: "pickup", delivery: "delivery", negotiable: "negotiable" },
         validate: {
           allow_nil: true,
         }

    belongs_to :topic

    validates :topic_id, uniqueness: true
    validates :item_name, presence: true, length: { maximum: ITEM_NAME_MAX_LENGTH }
    validates :location, presence: true, length: { maximum: LOCATION_MAX_LENGTH }
    validates :description, length: { maximum: DESCRIPTION_MAX_LENGTH }
    validates :price,
              :budget_min,
              :budget_max,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: MAX_YEN,
                allow_nil: true,
              }
    validates :active_since, :last_bumped_at, presence: true
    validate :status_matches_kind
    validate :sell_fields, if: :sell?
    validate :buy_fields, if: :buy?

    def self.active_status_for(kind)
      ACTIVE_STATUS.fetch(kind.to_s)
    end

    def self.ended_status_for(kind)
      ENDED_STATUS.fetch(kind.to_s)
    end

    def active?
      status == self.class.active_status_for(kind)
    end

    private

    def status_matches_kind
      return if kind.blank? || status.blank? || expired?
      return if [ACTIVE_STATUS[kind], ENDED_STATUS[kind]].include?(status)

      errors.add(:status, :inclusion)
    end

    def sell_fields
      errors.add(:price, :blank) if price.nil? && !free
      errors.add(:trade_method, :blank) if trade_method.nil?
      errors.add(:budget_min, :present) if budget_min
      errors.add(:budget_max, :present) if budget_max
      if upload_ids.empty? || upload_ids.size > SiteSetting.kuu_market_max_photos
        errors.add(:upload_ids, :invalid)
      end
    end

    def buy_fields
      errors.add(:price, :present) if price
      errors.add(:free, :present) if free
      errors.add(:trade_method, :present) if trade_method
      errors.add(:upload_ids, :invalid) if upload_ids.size > BUY_MAX_PHOTOS

      if budget_min.nil? && budget_max.nil?
        errors.add(:budget_max, :blank)
      elsif budget_min && budget_max && budget_min > budget_max
        errors.add(:budget_max, :greater_than_or_equal_to, count: budget_min)
      end
    end
  end
end

# == Schema Information
#
# Table name: kuu_market_listings
#
#  id                 :bigint           not null, primary key
#  active_since       :datetime         not null
#  budget_max         :integer
#  budget_min         :integer
#  closed_by_plugin   :boolean          default(FALSE), not null
#  description        :text             default(""), not null
#  free               :boolean          default(FALSE), not null
#  item_name          :string           not null
#  kind               :string           not null
#  last_bumped_at     :datetime         not null
#  location           :string           not null
#  price              :integer
#  status             :string           not null
#  trade_method       :string
#  unlisted_by_plugin :boolean          default(FALSE), not null
#  upload_ids         :integer          default([]), not null, is an Array
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  topic_id           :integer          not null
#
# Indexes
#
#  index_kuu_market_listings_on_status_and_active_since  (status,active_since)
#  index_kuu_market_listings_on_topic_id                 (topic_id) UNIQUE
#
