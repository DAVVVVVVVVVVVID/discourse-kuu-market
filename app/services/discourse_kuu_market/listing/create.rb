# frozen_string_literal: true

module DiscourseKuuMarket
  # 用表单发出售 / 求购帖。标题和第一楼由插件生成；发帖照常经过 NewPostManager，
  # 屏蔽词、新用户审核、发帖频率等 core 规则都生效，需要审核时进审核队列
  class Listing::Create
    include Service::Base

    params do
      attribute :kind, :string
      attribute :item_name, :string
      attribute :price, :integer
      attribute :free, :boolean, default: false
      attribute :budget_min, :integer
      attribute :budget_max, :integer
      attribute :location, :string
      attribute :area, :string
      attribute :categories, :array, compact_blank: true, default: []
      attribute :trade_method, :string
      attribute :description, :string, default: ""
      attribute :upload_ids, :array, compact_blank: true, default: []

      validates :kind, inclusion: { in: Listing.kinds.keys }
      # 修改时也检查：上线前发的帖子没有这两项，作者下次修改时要补填
      validates :area, inclusion: { in: Listing::AREAS }
      validates :categories, length: { minimum: 1, maximum: Listing::MAX_CATEGORIES }
      validate :categories_allowed

      def categories_allowed
        if categories.uniq.size != categories.size || (categories - Listing::CATEGORIES).any?
          errors.add(:categories, :inclusion)
        end
      end

      def listing_attributes
        common = {
          kind:,
          item_name: item_name&.strip,
          location: location&.strip,
          area:,
          categories:,
          description: description.to_s.strip,
          upload_ids:,
        }

        if kind == "sell"
          common.merge(price: free ? nil : price, free:, trade_method:)
        else
          common.merge(budget_min:, budget_max:)
        end
      end
    end

    model :category
    policy :can_create_topic_in_category
    policy :photos_available_to_user
    model :listing, :open_listing

    try(RateLimiter::LimitExceeded) { step :publish_listing }

    private

    def fetch_category
      Category.find_by(id: SiteSetting.kuu_market_category)
    end

    def can_create_topic_in_category(guardian:, category:)
      guardian.can_create_topic_on_category?(category)
    end

    def photos_available_to_user(guardian:, params:)
      Listing.photos_usable_by?(guardian.user, params.upload_ids)
    end

    def open_listing(params:)
      Listing.open(params.listing_attributes)
    end

    def publish_listing(guardian:, category:, listing:, params:)
      renderer = ListingRenderer.new(listing)
      result =
        FormSubmission.submit(renderer.title) do
          NewPostManager.new(
            guardian.user,
            :title => renderer.title,
            :raw => renderer.raw,
            :category => category.id,
            :archetype => Archetype.default,
            :first_post_checks => true,
            NewTopicRules::LISTING_ARG => params.listing_attributes,
          ).perform
        end

      fail!(result.errors.full_messages.join("\n")) if result.failed?
      context[:new_post_result] = result
    end
  end
end
