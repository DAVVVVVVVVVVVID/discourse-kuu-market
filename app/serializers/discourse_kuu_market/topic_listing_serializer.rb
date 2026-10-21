# frozen_string_literal: true

module DiscourseKuuMarket
  # 帖子页用：状态显示、切换按钮，修改表单回填的字段和照片，以及举手排队
  class TopicListingSerializer < ListingSerializer
    attributes :photos,
               :can_manage,
               :statuses_reachable,
               :expires_at,
               :title_prefix,
               :raised_hands,
               :can_raise_hand,
               :hand_raised,
               :deal_user

    def title_prefix
      ListingRenderer.new(object).title_prefix
    end

    def expires_at
      object.active_since + SiteSetting.kuu_market_expire_days.days
    end

    def include_expires_at?
      can_manage && object.active?
    end

    def photos
      uploads = Upload.where(id: object.upload_ids).index_by(&:id)
      object.upload_ids.filter_map do |id|
        upload = uploads[id]
        { id: upload.id, url: upload.url } if upload
      end
    end

    def can_manage
      scope.can_manage_kuu_market_listing?(object)
    end

    def statuses_reachable
      [Listing.active_status_for(object.kind), Listing.ended_status_for(object.kind)].select do
        object.can_change_to?(it)
      end
    end

    # 头像所有人都能看到，按举手顺序
    def raised_hands
      @raised_hands ||=
        object
          .raised_hands
          .queue
          .includes(:user)
          .map { |hand| BasicUserSerializer.new(hand.user, scope:, root: false).as_json }
    end

    def include_raised_hands?
      object.active?
    end

    # 已出 / 已购买帖子上的「成交对象」，所有人都能看到；选了「无」时没有
    def deal_user
      BasicUserSerializer.new(object.deal_user, scope:, root: false).as_json
    end

    def include_deal_user?
      object.closes_replies? && object.deal_user.present?
    end

    def can_raise_hand
      scope.can_raise_kuu_market_hand?(object)
    end

    def hand_raised
      raised_hands.any? { it[:id] == scope.user&.id }
    end

    def include_hand_raised?
      include_raised_hands? && scope.authenticated?
    end

    def include_photos?
      can_manage
    end

    def include_statuses_reachable?
      can_manage
    end
  end
end
