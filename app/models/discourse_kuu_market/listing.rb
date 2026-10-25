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

    # 位置范围和商品分类（Issue #11，2026-10-22 David 定）。固定列表，以后加选项改这里和文案
    AREAS = %w[yoshida uji katsura other].freeze
    CATEGORIES = %w[
      furniture_appliances
      electronics
      clothing
      transport_sports
      entertainment
      study
      other
    ].freeze
    MAX_CATEGORIES = 3

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

    # 表单内容在话题建出来之前就要校验，所以这里不要求 topic；数据库里 topic_id 不能为空
    belongs_to :topic, -> { with_deleted }, optional: true
    has_many :raised_hands, dependent: :delete_all
    # 成交对象：成交时从举手的人里选，可以不选（在其他渠道成交）
    belongs_to :deal_user, class_name: "User", optional: true

    validates :topic_id, uniqueness: { allow_nil: true }
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
    validate :photos_are_images
    # 必填由表单（Create / Update 的参数）检查：上线前发的帖子没有这两项，切换状态、过期时不能因此失败
    validates :area, inclusion: { in: AREAS }, allow_nil: true
    validate :categories_allowed
    validate :deal_only_when_ended

    # 新发的帖子从现在开始在售或求购，30 天过期和 7 天顶帖都从现在算
    def self.open(attributes)
      now = Time.zone.now
      new(attributes).tap do |listing|
        listing.assign_attributes(
          status: listing.kind && active_status_for(listing.kind),
          active_since: now,
          last_bumped_at: now,
        )
      end
    end

    # 进入在售 / 求购满 kuu_market_expire_days 天的帖子（刚好满的也算）。已删除的帖子不算（见 #topic_deleted?）
    def self.due_to_expire(at: Time.zone.now)
      joins(:topic)
        .where(topics: { category_id: SiteSetting.kuu_market_category.to_i, deleted_at: nil })
        .where.not(topic_id: Post.where(post_number: 1, user_deleted: true).select(:topic_id))
        .where(status: ACTIVE_STATUS.values)
        .where("kuu_market_listings.active_since <= ?", expiry_cutoff(at))
    end
    # 插件隐藏的、还在二手市场里的已出 / 已购买帖子（管理员手动隐藏的不算）：发帖人主页「话题」里放出来
    def self.deals_unlisted_by_plugin
      where(status: ENDED_STATUS.values, unlisted_by_plugin: true).joins(:topic).where(
        topics: {
          category_id: SiteSetting.kuu_market_category.to_i,
        },
      )
    end

    def self.expiry_cutoff(at)
      at - SiteSetting.kuu_market_expire_days.days
    end

    # Discourse 按文件内容去重，同一张图别人传过时拿到的是别人的上传记录，所以公开的上传谁都能用。
    # 私密分类里的图（secure）只能用自己传的，不能借二手帖把它公开出去
    def self.photos_usable_by?(user, upload_ids)
      upload_ids = upload_ids.uniq
      Upload
        .where(id: upload_ids)
        .where("uploads.user_id = :user_id OR NOT uploads.secure", user_id: user.id)
        .count == upload_ids.size
    end

    def self.active_status_for(kind)
      ACTIVE_STATUS.fetch(kind.to_s)
    end

    def self.ended_status_for(kind)
      ENDED_STATUS.fetch(kind.to_s)
    end

    def active?
      status == self.class.active_status_for(kind)
    end

    # 已出、结束：关闭回复。过期不关，东西可能还在，点链接进来的人还能问
    def closes_replies?
      status == self.class.ended_status_for(kind)
    end

    # 删帖时记录保留，恢复帖子时原样回来；删掉期间插件不碰它。作者自己删帖时 core 先标记第一楼、
    # 过一段时间才真正删除话题，这段时间也算已删除。永久删除话题时记录随话题删除（Topic has_one）
    def topic_deleted?
      topic.nil? || topic.trashed? || !!topic.first_post&.user_deleted
    end

    # 移出二手市场的帖子不再受插件管理
    def in_market?
      DiscourseKuuMarket.market_category?(topic&.category_id)
    end

    # 手动只能在进行中和结束之间切换（过期的也能改回这两种）；过期只由系统设置
    def can_change_to?(new_status)
      new_status != status &&
        [self.class.active_status_for(kind), self.class.ended_status_for(kind)].include?(new_status)
    end

    # 改回进行中时 30 天过期重新计时，成交对象清掉
    def change_status(new_status, deal_user: nil, at: Time.zone.now)
      self.status = new_status
      self.deal_user = deal_user

      self.active_since = at if active?
    end

    # 成交、过期时排队结束，返回还在排队的人（不含成交对象），由调用方通知
    def end_queue(at: Time.zone.now)
      users = raised_hands.queue.includes(:user).map(&:user)
      raised_hands.active.update_all(ended_at: at, updated_at: at)
      users - [deal_user]
    end

    def expiry_due?(at: Time.zone.now)
      active? && active_since <= self.class.expiry_cutoff(at)
    end

    def relisting?
      will_save_change_to_status? && active?
    end

    def next_bump_at
      last_bumped_at + SiteSetting.kuu_market_bump_interval_days.days
    end

    def bump_due?(at: Time.zone.now)
      next_bump_at <= at
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

    def categories_allowed
      if categories.size > MAX_CATEGORIES || categories.uniq.size != categories.size ||
           (categories - CATEGORIES).any?
        errors.add(:categories, :invalid)
      end
    end

    def deal_only_when_ended
      errors.add(:deal_user, :present) if deal_user_id && !closes_replies?
    end

    def photos_are_images
      return if upload_ids.empty?

      images =
        Upload
          .where(id: upload_ids)
          .pluck(:original_filename)
          .count { |filename| FileHelper.is_supported_image?(filename) }
      errors.add(:upload_ids, :invalid) if images != upload_ids.size
    end
  end
end

# == Schema Information
#
# Table name: kuu_market_listings
#
#  id                 :bigint           not null, primary key
#  active_since       :datetime         not null
#  area               :string
#  budget_max         :integer
#  budget_min         :integer
#  categories         :string           default([]), not null, is an Array
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
#  deal_user_id       :integer
#  topic_id           :integer          not null
#
# Indexes
#
#  index_kuu_market_listings_on_area                     (area)
#  index_kuu_market_listings_on_categories               (categories) USING gin
#  index_kuu_market_listings_on_status_and_active_since  (status,active_since)
#  index_kuu_market_listings_on_topic_id                 (topic_id) UNIQUE
#
