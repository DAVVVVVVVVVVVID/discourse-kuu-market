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

    # 发帖人还没在弹窗里看过的举手（Issue #5 第二期）：只算进行中的、还在二手市场的帖子
    def self.unalerted_for(user)
      active
        .where(alerted_at: nil)
        .joins(listing: :topic)
        .where(
          topics: {
            user_id: user.id,
            deleted_at: nil,
            category_id: SiteSetting.kuu_market_category.to_i,
          },
        )
        .where(kuu_market_listings: { status: Listing::ACTIVE_STATUS.values })
    end

    # 弹窗内容：每个帖子一项（话题 id、类型、商品名、新举手人数），up_to_id 是这批里最大的记录 id，
    # 关掉弹窗时只标记到这里，弹窗打开以后才举手的人下次再弹。这批只有一个人举手时带上和他的
    # 私聊频道，「去私信」直接打开那个对话（Issue #9）
    def self.alerts_for(user)
      hands = unalerted_for(user)
      rows =
        hands
          .group(
            "kuu_market_listings.topic_id",
            "kuu_market_listings.kind",
            "kuu_market_listings.item_name",
          )
          .order("MIN(kuu_market_raised_hands.id)")
          .pluck(
            "kuu_market_listings.topic_id",
            "kuu_market_listings.kind",
            "kuu_market_listings.item_name",
            Arel.sql("COUNT(*)"),
            Arel.sql("MAX(kuu_market_raised_hands.id)"),
          )
      return if rows.empty?

      raiser_ids = hands.distinct.pluck(:user_id)
      chat_channel_id =
        if raiser_ids.size == 1
          DiscourseKuuMarket.direct_message_channel_id(user, User.find(raiser_ids.first))
        end

      {
        listings:
          rows.map do |topic_id, kind, item_name, count, _|
            { topic_id:, kind:, item_name:, count: }
          end,
        up_to_id: rows.map(&:last).max,
        chat_channel_id:,
      }
    end

    # 防刷用：since（日本时间今天 0 点）之后的举手和取消合计几次
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
#  alerted_at   :datetime
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
