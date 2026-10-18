# frozen_string_literal: true

module DiscourseKuuMarket
  # 作者或管理员用表单修改二手帖，不受编辑时限限制。标题和第一楼按表单重新生成，
  # 照常留下编辑记录；不顶帖，也不重新计算过期时间。类型（出售 / 求购）不能改
  class Listing::Update
    include Service::Base

    model :listing
    params default_values_from: :listing, base_class: Listing::Create::Contract
    policy :listing_in_market
    policy :can_edit_listing, class_name: Listing::Policy::CanManage
    policy :kind_unchanged
    policy :photos_available_to_editor
    model :revised_listing, :revise_listing
    # 不包事务：PostRevisor 自己会发 MessageBus、排后台任务，包进来会在提交前发出去。
    # 先改帖：改帖失败（比如屏蔽词）时记录不动；记录已校验过，save! 只会因数据库故障失败
    step :revise_first_post
    step :save_listing

    private

    def fetch_listing(params:)
      Listing.includes(topic: :first_post).find_by(topic_id: params.topic_id)
    end

    def listing_in_market(listing:)
      listing.in_market?
    end

    def kind_unchanged(listing:, params:)
      params.kind == listing.kind
    end

    # 原来的照片可以留着（管理员修改别人的帖子时也一样），新加的必须是编辑者自己上传的
    def photos_available_to_editor(guardian:, listing:, params:)
      added_ids = params.upload_ids.uniq - listing.upload_ids
      Upload.where(id: added_ids, user: guardian.user).count == added_ids.size
    end

    def revise_listing(listing:, params:)
      listing.tap { it.assign_attributes(params.listing_attributes) }
    end

    def revise_first_post(guardian:, revised_listing:)
      renderer = ListingRenderer.new(revised_listing)
      post = revised_listing.topic.first_post

      FormSubmission.submit(renderer.title) do
        PostRevisor.new(post, revised_listing.topic).revise!(
          guardian.user,
          { title: renderer.title, raw: renderer.raw },
          bypass_bump: true,
        )
      end

      fail!(post.errors.full_messages.join("\n")) if post.errors.present?
    end

    def save_listing(revised_listing:)
      revised_listing.save!
    end
  end
end
