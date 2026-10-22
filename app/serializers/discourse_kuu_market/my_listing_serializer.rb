# frozen_string_literal: true

module DiscourseKuuMarket
  # 「我的商品」页的一条：在帖子页用的字段（管理按钮、修改表单要用）之外，再带上卡片要显示的内容
  class MyListingSerializer < TopicListingSerializer
    attributes :title, :url, :created_at, :photo_url, :card_price, :hands_count, :expired_at

    def title
      object.topic.title
    end

    def url
      object.topic.relative_url
    end

    def created_at
      object.topic.created_at
    end

    def photo_url
      Upload.find_by(id: object.upload_ids.first)&.url
    end

    def card_price
      ListingRenderer.new(object).card_price
    end

    def hands_count
      object.raised_hands.active.count
    end

    def include_hands_count?
      object.active?
    end

    # 过期的时间：进入在售 / 求购之后满期限的那一刻
    def expired_at
      object.active_since + SiteSetting.kuu_market_expire_days.days
    end

    def include_expired_at?
      object.expired?
    end
  end
end
