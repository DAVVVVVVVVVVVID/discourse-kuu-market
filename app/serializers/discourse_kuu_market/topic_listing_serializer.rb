# frozen_string_literal: true

module DiscourseKuuMarket
  # 帖子页用：状态显示、切换按钮，以及修改表单回填的字段和照片
  class TopicListingSerializer < ListingSerializer
    attributes :photos, :can_manage, :statuses_reachable, :expires_at, :title_prefix

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

    def include_photos?
      can_manage
    end

    def include_statuses_reachable?
      can_manage
    end
  end
end
