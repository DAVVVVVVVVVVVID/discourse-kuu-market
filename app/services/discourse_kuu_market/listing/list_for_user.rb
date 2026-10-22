# frozen_string_literal: true

module DiscourseKuuMarket
  # 「我的商品」页（Issue #12）：某人在二手市场发的所有二手帖，新发的在前。
  # 只有本人和管理员能看；删掉的、移出二手市场的不算
  class Listing::ListForUser
    include Service::Base

    params do
      attribute :username, :string

      validates :username, presence: true
    end

    model :user
    policy :can_see_listings
    model :listings, optional: true

    private

    def fetch_user(params:)
      User.find_by_username(params.username)
    end

    def can_see_listings(guardian:, user:)
      guardian.authenticated? && (guardian.user.id == user.id || guardian.is_staff?)
    end

    def fetch_listings(user:)
      Listing
        .joins(:topic)
        .where(
          topics: {
            user_id: user.id,
            deleted_at: nil,
            category_id: SiteSetting.kuu_market_category.to_i,
          },
        )
        .where.not(topic_id: Post.where(post_number: 1, user_deleted: true).select(:topic_id))
        .includes(topic: :user)
        .order("topics.created_at DESC")
    end
  end
end
