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
      attribute :trade_method, :string
      attribute :description, :string, default: ""
      attribute :upload_ids, :array, compact_blank: true, default: []

      validates :kind, inclusion: { in: Listing.kinds.keys }

      def listing_attributes
        common = {
          kind:,
          item_name: item_name&.strip,
          location: location&.strip,
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
    policy :photos_uploaded_by_user
    model :listing, :open_listing

    try(RateLimiter::LimitExceeded) { step :publish_listing }

    private

    def fetch_category
      Category.find_by(id: SiteSetting.kuu_market_category)
    end

    def can_create_topic_in_category(guardian:, category:)
      guardian.can_create_topic_on_category?(category)
    end

    # 不能把别人上传的图片（比如私密分类里的）引用进自己的帖子
    def photos_uploaded_by_user(guardian:, params:)
      Upload.where(id: params.upload_ids, user: guardian.user).count == params.upload_ids.uniq.size
    end

    def open_listing(params:)
      Listing.open(params.listing_attributes)
    end

    def publish_listing(guardian:, category:, listing:, params:)
      renderer = ListingRenderer.new(listing)
      result =
        GeneratedTitle.allow(renderer.title) do
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
